#' Build a corpus from multiple sources
#'
#' @description
#' Combine multiple file reads and/or API fetches into a single
#' deduplicated `sm_corpus`.
#'
#' @details
#' The inputs are bound in turn with [sm_bind_corpora()], so its rules for
#' embeddings apply: embeddings that record different models in
#' `metadata$embedding`, or of which only one input records its model,
#' stop the function (class `scimapR_embedding_model_mismatch`) unless
#' `mix_models = TRUE`.
#'
#' @param ... One or more `sm_corpus` objects or file paths.
#' @param dedupe Logical; deduplicate by DOI after combining?
#' @param mix_models Logical; bind embeddings that come from different
#'   models (or of which only one input records its model)? Passed to
#'   [sm_bind_corpora()]. Defaults to `FALSE`.
#' @param verbose Logical; show progress messages?
#'
#' @return An `sm_corpus` object.
#'
#' @family corpus
#' @export
#' @examples
#' c1 <- sm_example_corpus(n_works = 50, seed = 1)
#' c2 <- sm_example_corpus(n_works = 50, seed = 2)
#' combined <- sm_build_corpus(c1, c2, dedupe = TRUE)
sm_build_corpus <- function(..., dedupe = TRUE, mix_models = FALSE,
                            verbose = TRUE) {
  .check_flag(mix_models)
  inputs <- list(...)
  corpora <- lapply(inputs, function(x) {
    if (is.character(x) && length(x) == 1 && file.exists(x)) {
      sm_read_auto(x, verbose = verbose)
    } else if (is_sm_corpus(x)) {
      x
    } else {
      cli::cli_abort("Each input must be an {.cls sm_corpus} or a file path.")
    }
  })

  result <- corpora[[1]]
  if (length(corpora) > 1) {
    for (i in seq.int(2L, length(corpora))) {
      result <- sm_bind_corpora(result, corpora[[i]],
                                mix_models = mix_models)
    }
  }

  if (dedupe) {
    result <- sm_dedupe(result, verbose = verbose)
  }

  result
}

#' Bind two corpora together
#'
#' @description
#' Row-bind all tables of two `sm_corpus` objects, the yearly citation
#' counts (`citations_by_year`) too when either corpus has them. The bound
#' corpus keeps the metadata of `corpus1`, with the local input files
#' ([sm_register_input()]) of both corpora, each file and content once.
#'
#' @details
#' Embeddings are bound when both corpora have them, with the same number
#' of dimensions, and when they come from the same model as
#' `metadata$embedding` records it (see [sm_corpus()]); the bound corpus
#' keeps that record. Embeddings that record different models, or of
#' which only one corpus records its model, are not comparable: the
#' function stops (class `scimapR_embedding_model_mismatch`) unless
#' `mix_models = TRUE`, which binds them and records the model as
#' `"mixed"`. Embeddings of two corpora that record no model, such as
#' corpora embedded by earlier versions of scimapR, are bound as before,
#' and the model of the bound rows stays unrecorded. When only one corpus
#' has embeddings, or their widths differ, the bound corpus has none.
#'
#' @param corpus1 An `sm_corpus`.
#' @param corpus2 An `sm_corpus`.
#' @param mix_models Logical; bind embeddings that come from different
#'   models (or of which only one corpus records its model)? Defaults to
#'   `FALSE`. See Details.
#'
#' @return An `sm_corpus` object.
#'
#' @family corpus
#' @export
sm_bind_corpora <- function(corpus1, corpus2, mix_models = FALSE) {
  .check_sm_corpus(corpus1)
  .check_sm_corpus(corpus2)
  .check_flag(mix_models)

  # yearly citation counts: one row per work and year, the first corpus's
  # for a work in both
  yearly <- list(corpus1$citations_by_year, corpus2$citations_by_year)
  yearly <- if (all(vapply(yearly, is.null, logical(1)))) {
    NULL
  } else {
    dplyr::distinct(
      dplyr::bind_rows(.empty_citations_by_year(), yearly),
      .data$work_id, .data$year, .keep_all = TRUE
    )
  }

  emb <- .bind_embeddings(corpus1, corpus2, mix_models = mix_models)
  metadata <- corpus1$metadata
  metadata$embedding <- emb$record
  metadata$local_inputs <- .bind_local_inputs(corpus1$metadata$local_inputs,
                                              corpus2$metadata$local_inputs)

  new_sm_corpus(
    works = dplyr::bind_rows(corpus1$works, corpus2$works),
    authors = dplyr::bind_rows(corpus1$authors, corpus2$authors) %>%
      dplyr::distinct(.data$author_id, .keep_all = TRUE),
    authorships = dplyr::bind_rows(corpus1$authorships, corpus2$authorships),
    institutions = dplyr::bind_rows(corpus1$institutions, corpus2$institutions) %>%
      dplyr::distinct(.data$institution_id, .keep_all = TRUE),
    sources = dplyr::bind_rows(corpus1$sources, corpus2$sources) %>%
      dplyr::distinct(.data$source_id, .keep_all = TRUE),
    references = dplyr::bind_rows(corpus1$references, corpus2$references),
    concepts = dplyr::bind_rows(corpus1$concepts, corpus2$concepts),
    embeddings = emb$embeddings,
    provenance = dplyr::bind_rows(corpus1$provenance, corpus2$provenance),
    screening = dplyr::bind_rows(corpus1$screening, corpus2$screening),
    metadata = metadata,
    citations_by_year = yearly
  )
}

#' The embeddings of two corpora bound, with their record
#'
#' Both matrices of one width: bound when both records name the same model
#' (the record is kept) or neither corpus records one (no record); any
#' other pair stops unless `mix_models`, which records a mix. Otherwise
#' (only one matrix, or two widths) no embeddings and no record.
#' @return A list: `embeddings` (a matrix or `NULL`) and `record`.
#' @noRd
.bind_embeddings <- function(corpus1, corpus2, mix_models = FALSE,
                             call = rlang::caller_env()) {
  emb1 <- corpus1$embeddings
  emb2 <- corpus2$embeddings
  if (is.null(emb1) || is.null(emb2) || ncol(emb1) != ncol(emb2)) {
    return(list(embeddings = NULL, record = NULL))
  }
  emb <- rbind(emb1, emb2)
  rec1 <- .embedding_record(corpus1)
  rec2 <- .embedding_record(corpus2)
  if (is.null(rec1) && is.null(rec2)) {
    return(list(embeddings = emb, record = NULL))
  }
  if (.embedding_same_model(rec1, rec2)) {
    rec1$n_works <- nrow(emb)
    return(list(embeddings = emb, record = rec1))
  }
  if (!mix_models) {
    .embedding_abort_mismatch(
      "The corpora have {first} and {second}.",
      rec1 = rec1, rec2 = rec2,
      hint = c(
        "i" = "Use {.code mix_models = TRUE} to bind them all the same,
               or embed the bound corpus with {.fun sm_embed_works}."
      ),
      call = call
    )
  }
  list(embeddings = emb,
       record = .embedding_mixed_record(list(rec1, rec2), nrow(emb),
                                        ncol(emb)))
}

#' Deduplicate corpus works by DOI
#'
#' @description
#' Remove duplicate works, preferring the record with more complete data.
#'
#' @param corpus An `sm_corpus`.
#' @param by Column(s) to deduplicate by. Default `"doi"`.
#' @param verbose Logical; show progress?
#'
#' @return An `sm_corpus` object.
#'
#' @family corpus
#' @export
sm_dedupe <- function(corpus, by = "doi", verbose = TRUE) {
  .check_sm_corpus(corpus)

  works <- corpus$works
  n_before <- nrow(works)

  has_doi <- !is.na(works$doi) & nzchar(works$doi)
  duped <- works[has_doi, ]
  not_duped <- works[!has_doi, ]

  if (nrow(duped) > 0) {
    duped <- duped %>%
      dplyr::mutate(.completeness = rowSums(!is.na(duped))) %>%
      dplyr::arrange(dplyr::desc(.data$.completeness)) %>%
      dplyr::distinct(.data$doi, .keep_all = TRUE) %>%
      dplyr::select(-".completeness")
  }

  works_clean <- dplyr::bind_rows(duped, not_duped)
  n_removed <- n_before - nrow(works_clean)

  if (verbose && n_removed > 0) {
    cli::cli_inform(c("v" = "Removed {n_removed} duplicate work{?s} by DOI."))
  }

  keep_ids <- works_clean$work_id

  new_sm_corpus(
    works = works_clean,
    authors = corpus$authors,
    authorships = dplyr::filter(corpus$authorships,
                                 .data$work_id %in% keep_ids),
    institutions = corpus$institutions,
    sources = corpus$sources,
    references = dplyr::filter(corpus$references,
                                .data$work_id %in% keep_ids),
    concepts = dplyr::filter(corpus$concepts,
                              .data$work_id %in% keep_ids),
    embeddings = if (!is.null(corpus$embeddings)) {
      idx <- which(rownames(corpus$embeddings) %in% keep_ids)
      if (length(idx) > 0) corpus$embeddings[idx, , drop = FALSE] else NULL
    },
    provenance = dplyr::filter(corpus$provenance,
                                .data$work_id %in% keep_ids),
    screening = dplyr::filter(corpus$screening,
                               .data$work_id %in% keep_ids),
    metadata = corpus$metadata,
    citations_by_year = .filter_citations_by_year(corpus$citations_by_year,
                                                  keep_ids)
  )
}

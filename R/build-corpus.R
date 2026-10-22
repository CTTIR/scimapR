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
#' Pass every file of a split export; the IDs stay unique.
#'
#' @param ... One or more `sm_corpus` objects or file paths.
#' @param dedupe Logical; deduplicate by normalised DOI after combining,
#'   keeping the most complete record and its child rows?
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
                                mix_models = mix_models, verbose = verbose)
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
#' Combine two corpora, assigning new IDs to colliding records in the
#' second input and rewriting their links in every table and embedding.
#' This includes yearly citation counts (`citations_by_year`). The bound
#' corpus keeps the metadata of `corpus1`, with the local input files
#' ([sm_register_input()]) of both corpora, each file and content once.
#'
#' @details
#' Work IDs shared by the inputs always get new values in `corpus2`.
#' Author, source and institution IDs are shared only when their lookup
#' rows agree on every common column, including missing and list values.
#' Other collisions get new IDs above the numbers used by either input;
#' external cited work IDs are reserved too. Shared DOIs remain separate
#' records until [sm_dedupe()] is called. The merged corpus is unlocked.
#'
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
#' has embeddings, or their widths differ, the bound corpus has none and
#' warns with class `scimapR_bind_embeddings_dropped`.
#'
#' @param corpus1 An `sm_corpus`.
#' @param corpus2 An `sm_corpus`.
#' @param mix_models Logical; bind embeddings that come from different
#'   models (or of which only one corpus records its model)? Defaults to
#'   `FALSE`. See Details.
#' @param verbose Logical; report the number of re-keyed IDs and works
#'   whose normalised DOI also occurs in the first input?
#'
#' @return An `sm_corpus` object.
#'
#' @family corpus
#' @export
sm_bind_corpora <- function(corpus1, corpus2, mix_models = FALSE,
                            verbose = TRUE) {
  .check_sm_corpus(corpus1)
  .check_corpus_unlocked(corpus1)
  .check_sm_corpus(corpus2)
  .check_corpus_unlocked(corpus2)
  .check_flag(mix_models)
  .check_flag(verbose)
  corpus2 <- .rekey_corpus(corpus1, corpus2, verbose = verbose)

  # Input records now have separate work IDs.
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
  metadata$is_locked <- FALSE
  metadata[c("locked_at", "lock_reason", "lock_hash")] <- NULL

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

.corpus_id_columns <- function(kind) {
  switch(kind,
    work = c(works = "work_id", authorships = "work_id",
             references = "work_id", concepts = "work_id",
             provenance = "work_id", screening = "work_id",
             citations_by_year = "work_id"),
    author = c(authors = "author_id", authorships = "author_id"),
    source = c(sources = "source_id", works = "source_id"),
    institution = c(institutions = "institution_id",
                    authorships = "institution_id")
  )
}

.corpus_ids <- function(corpus, columns) {
  unique(unlist(lapply(names(columns), function(table) {
    corpus[[table]][[columns[[table]]]]
  }), use.names = FALSE))
}

.shared_lookup_ids <- function(x, y, key) {
  shared <- intersect(x[[key]], y[[key]])
  cols <- intersect(names(x), names(y))
  shared[vapply(shared, function(id) {
    i <- which(x[[key]] == id)
    j <- which(y[[key]] == id)
    length(i) == 1L && length(j) == 1L &&
      all(vapply(cols, function(col) {
        identical(x[[col]][i], y[[col]][j])
      }, logical(1)))
  }, logical(1))]
}

.rekey_corpus <- function(corpus1, corpus2, verbose) {
  prefixes <- c(work = "W", author = "A", source = "S", institution = "I")
  tables <- c(author = "authors", source = "sources",
              institution = "institutions")
  maps <- lapply(names(prefixes), function(kind) {
    columns <- .corpus_id_columns(kind)
    ids1 <- .corpus_ids(corpus1, columns)
    ids2 <- .corpus_ids(corpus2, columns)
    keep <- character()
    reserved <- character()
    if (kind == "work") {
      reserved <- c(corpus1$references$cited_work_id,
                    corpus2$references$cited_work_id,
                    rownames(corpus1$embeddings), rownames(corpus2$embeddings))
    } else {
      table <- tables[[kind]]
      keep <- .shared_lookup_ids(corpus1[[table]], corpus2[[table]],
                                 paste0(kind, "_id"))
    }
    .rekey_map(ids2, ids1, prefixes[[kind]], keep, taken = reserved)
  })
  names(maps) <- names(prefixes)
  local_refs <- corpus2$references$cited_work_id %in% corpus2$works$work_id
  corpus2$references$cited_work_id[local_refs] <- .apply_id_map(
    corpus2$references$cited_work_id[local_refs], maps$work
  )
  for (kind in names(maps)) {
    columns <- .corpus_id_columns(kind)
    for (table in names(columns)) {
      col <- columns[[table]]
      if (!is.null(corpus2[[table]][[col]])) {
        corpus2[[table]][[col]] <- .apply_id_map(corpus2[[table]][[col]],
                                                 maps[[kind]])
      }
    }
  }
  if (!is.null(corpus2$embeddings)) {
    rownames(corpus2$embeddings) <- .apply_id_map(rownames(corpus2$embeddings),
                                                  maps$work)
  }
  counts <- vapply(maps, length, integer(1))
  if (verbose && any(counts > 0L)) {
    doi1 <- .normalize_doi(corpus1$works$doi)
    doi2 <- .normalize_doi(corpus2$works$doi)
    n_doi <- sum(!is.na(doi2) & doi2 %in% doi1)
    msg <- c("i" = "Re-keyed {counts[['work']]} works,
                    {counts[['author']]} authors,
                    {counts[['source']]} sources and
                    {counts[['institution']]} institutions
                    in the second corpus.")
    if (n_doi > 0L) {
      msg <- c(msg, "i" = "{n_doi} work{?s} share a DOI with the first corpus;
                            use {.fun sm_dedupe} to remove duplicates.")
    }
    cli::cli_inform(msg, class = "scimapR_bind_rekeyed")
  }
  corpus2
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
    if (!is.null(emb1) || !is.null(emb2)) {
      reason <- if (is.null(emb1) || is.null(emb2)) {
        "only one input has embeddings"
      } else {
        "the embedding widths differ"
      }
      cli::cli_warn(c("Embeddings were dropped.", "i" = reason),
                    class = "scimapR_bind_embeddings_dropped", call = call)
    }
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

#' Deduplicate corpus works by selected columns
#'
#' @description
#' Remove duplicate works, preferring the record with more complete data.
#' Ties keep the first record. Kept records stay in their input order,
#' with only their child rows and referenced lookup records.
#'
#' @param corpus An `sm_corpus`.
#' @param by Non-empty character vector of works columns that together
#'   identify duplicates. Default `"doi"`. DOIs and titles are normalised,
#'   other character values are trimmed, and other types compare as stored.
#'   A missing or empty value in any key column never counts as a duplicate.
#' @param verbose Logical; show progress?
#'
#' @return An `sm_corpus` object.
#'
#' @family corpus
#' @export
sm_dedupe <- function(corpus, by = "doi", verbose = TRUE) {
  .check_sm_corpus(corpus)
  .check_corpus_unlocked(corpus)

  works_clean <- .dedupe_works(corpus$works, by)$works
  n_removed <- nrow(corpus$works) - nrow(works_clean)

  if (verbose && n_removed > 0) {
    cli::cli_inform(c(
      "v" = "Removed {n_removed} duplicate work{?s}
             with the same {.field {by}}."
    ))
  }

  keep_ids <- works_clean$work_id

  out <- new_sm_corpus(
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
      emb_ids <- rownames(corpus$embeddings)
      n_duplicate <- sum(duplicated(emb_ids) & emb_ids %in% keep_ids)
      if (n_duplicate > 0L) {
        cli::cli_warn(
          "Dropped {n_duplicate} duplicate embedding row{?s};
           keeping the first per work.",
          class = "scimapR_duplicate_embedding_rows"
        )
      }
      idx <- match(keep_ids, emb_ids)
      idx <- idx[!is.na(idx)]
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
  .prune_lookups(out)
}

.dedupe_works <- function(works, by) {
  if (!is.character(by) || length(by) == 0L || anyNA(by) || any(!nzchar(by))) {
    cli::cli_abort(
      "{.arg by} must be a non-empty character vector of column names."
    )
  }
  unknown <- setdiff(by, names(works))
  if (length(unknown) > 0L) {
    cli::cli_abort(c(
      "Unknown deduplication column{?s}: {.field {unknown}}.",
      "i" = "Available columns: {.field {names(works)}}."
    ), class = "scimapR_dedupe_unknown_column")
  }
  key <- works[unique(by)]
  for (col in names(key)) {
    key[[col]] <- if (col == "doi") {
      .normalize_doi(key[[col]])
    } else if (col == "title") {
      .norm_title(key[[col]])
    } else if (is.character(key[[col]])) {
      trimws(key[[col]])
    } else {
      key[[col]]
    }
  }
  complete <- .complete_key_rows(key)
  groups <- dplyr::group_rows(dplyr::group_by(
    key, dplyr::across(dplyr::everything())
  ))
  score <- rowSums(!is.na(works))
  keep <- rep(TRUE, nrow(works))
  map <- stats::setNames(character(), character())
  for (idx in groups) {
    if (length(idx) < 2L || !all(complete[idx])) next
    best <- idx[which.max(score[idx])]
    removed <- setdiff(idx, best)
    keep[removed] <- FALSE
    map <- c(map, stats::setNames(rep(works$work_id[best], length(removed)),
                                  works$work_id[removed]))
  }
  list(works = works[keep, , drop = FALSE], map = map)
}

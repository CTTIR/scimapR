#' Build a corpus from multiple sources
#'
#' @description
#' Combine multiple file reads and/or API fetches into a single
#' deduplicated `sm_corpus`.
#'
#' @param ... One or more `sm_corpus` objects or file paths.
#' @param dedupe Logical; deduplicate by DOI after combining?
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
sm_build_corpus <- function(..., dedupe = TRUE, verbose = TRUE) {
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
      result <- sm_bind_corpora(result, corpora[[i]])
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
#' Row-bind all tables of two `sm_corpus` objects.
#'
#' @param corpus1 An `sm_corpus`.
#' @param corpus2 An `sm_corpus`.
#'
#' @return An `sm_corpus` object.
#'
#' @family corpus
#' @export
sm_bind_corpora <- function(corpus1, corpus2) {
  .check_sm_corpus(corpus1)
  .check_sm_corpus(corpus2)

  emb <- NULL
  if (!is.null(corpus1$embeddings) && !is.null(corpus2$embeddings) &&
      ncol(corpus1$embeddings) == ncol(corpus2$embeddings)) {
    emb <- rbind(corpus1$embeddings, corpus2$embeddings)
  }

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
    embeddings = emb,
    provenance = dplyr::bind_rows(corpus1$provenance, corpus2$provenance),
    screening = dplyr::bind_rows(corpus1$screening, corpus2$screening),
    metadata = corpus1$metadata
  )
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
    metadata = corpus$metadata
  )
}

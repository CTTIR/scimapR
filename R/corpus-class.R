#' Create an sm_corpus object
#'
#' @description
#' Build a typed, tibble-of-tibbles corpus container for bibliometric analysis.
#' The corpus is the central data structure in scimapR, holding works, authors,
#' authorships, institutions, sources, references, concepts, embeddings,
#' provenance, screening decisions, and metadata.
#'
#' @param works A tibble of works (publications). See Details for schema.
#' @param authors A tibble of authors. If `NULL`, constructed from `works`.
#' @param authorships A tibble linking works to authors. If `NULL`, empty.
#' @param institutions A tibble of institutions. If `NULL`, empty.
#' @param sources A tibble of publication sources/journals. If `NULL`, empty.
#' @param references A tibble of cited references. If `NULL`, empty.
#' @param concepts A tibble of concepts/keywords. If `NULL`, empty.
#' @param embeddings A numeric matrix of work embeddings, or `NULL`.
#' @param provenance A tibble tracking data lineage. If `NULL`, empty.
#' @param screening A tibble of screening decisions. If `NULL`, empty.
#' @param metadata A list of corpus-level metadata.
#'
#' @return An `sm_corpus` S3 object.
#'
#' @family corpus
#' @export
#' @examples
#' corpus <- sm_corpus(
#'   works = tibble::tibble(
#'     work_id = "W000000001",
#'     doi = "10.1234/example",
#'     title = "Example Work",
#'     abstract = "An example abstract.",
#'     year = 2024L,
#'     type = "journal-article",
#'     source_id = NA_character_,
#'     cited_by_count = 0L,
#'     oa_status = "closed",
#'     language = "en",
#'     pmid = NA_character_,
#'     arxiv_id = NA_character_,
#'     openalex_id = NA_character_,
#'     is_retracted = FALSE,
#'     retraction_date = NA_real_,
#'     last_refreshed = Sys.time()
#'   )
#' )
#' print(corpus)
sm_corpus <- function(works,
                      authors = NULL,
                      authorships = NULL,
                      institutions = NULL,
                      sources = NULL,
                      references = NULL,
                      concepts = NULL,
                      embeddings = NULL,
                      provenance = NULL,
                      screening = NULL,
                      metadata = list()) {
  if (!tibble::is_tibble(works)) {
    works <- tibble::as_tibble(works)
  }

  works <- .ensure_works_schema(works)
  authors <- authors %||% .empty_authors()
  authorships <- authorships %||% .empty_authorships()

  corpus <- new_sm_corpus(
    works = works,
    authors = authors,
    authorships = authorships,
    institutions = institutions,
    sources = sources,
    references = references,
    concepts = concepts,
    embeddings = embeddings,
    provenance = provenance,
    screening = screening,
    metadata = metadata
  )

  validate_sm_corpus(corpus)
  corpus
}

#' Low-level constructor for sm_corpus
#' @noRd
new_sm_corpus <- function(works,
                          authors,
                          authorships,
                          institutions = NULL,
                          sources = NULL,
                          references = NULL,
                          concepts = NULL,
                          embeddings = NULL,
                          provenance = NULL,
                          screening = NULL,
                          metadata = list()) {
  md <- .safe_metadata()
  md[names(metadata)] <- metadata

  structure(
    list(
      works = works,
      authors = authors,
      authorships = authorships,
      institutions = institutions %||% .empty_institutions(),
      sources = sources %||% .empty_sources(),
      references = references %||% .empty_references(),
      concepts = concepts %||% .empty_concepts(),
      embeddings = embeddings,
      provenance = provenance %||% .empty_provenance(),
      screening = screening %||% .empty_screening(),
      metadata = md
    ),
    class = "sm_corpus"
  )
}

#' Validate an sm_corpus object
#'
#' @description
#' Check that an `sm_corpus` has valid structure and consistent IDs.
#'
#' @param x An `sm_corpus` object.
#' @param call Caller environment for error reporting.
#'
#' @return `x` invisibly if valid; throws an error otherwise.
#'
#' @family corpus
#' @export
validate_sm_corpus <- function(x, call = rlang::caller_env()) {
  if (!inherits(x, "sm_corpus")) {
    cli::cli_abort("Object is not an {.cls sm_corpus}.", call = call)
  }

  required <- c("works", "authors", "authorships", "institutions",
                 "sources", "references", "concepts", "provenance",
                 "screening", "metadata")
  missing <- setdiff(required, names(x))
  if (length(missing) > 0) {
    cli::cli_abort(
      "Missing required components: {.field {missing}}.",
      call = call
    )
  }

  if (!tibble::is_tibble(x$works)) {
    cli::cli_abort("{.field works} must be a tibble.", call = call)
  }

  if (!"work_id" %in% names(x$works)) {
    cli::cli_abort("{.field works} must have a {.field work_id} column.",
                   call = call)
  }

  if (!is.list(x$metadata)) {
    cli::cli_abort("{.field metadata} must be a list.", call = call)
  }

  invisible(x)
}

#' Test if an object is an sm_corpus
#'
#' @param x An object to test.
#' @return `TRUE` if `x` is an `sm_corpus`, `FALSE` otherwise.
#'
#' @family corpus
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' is_sm_corpus(corpus)
is_sm_corpus <- function(x) {
  inherits(x, "sm_corpus")
}

#' @rdname sm_corpus
#' @param i Row index for subsetting.
#' @return
#'   - `[`: An `sm_corpus` with the selected works.
#'   - `length()`: Number of works (integer).
#'   - `dim()`: Integer vector of length 2 (rows, columns of works table).
#' @export
`[.sm_corpus` <- function(x, i, ...) {
  works <- x$works[i, , drop = FALSE]
  keep_ids <- works$work_id

  new_sm_corpus(
    works = works,
    authors = x$authors,
    authorships = dplyr::filter(x$authorships, .data$work_id %in% keep_ids),
    institutions = x$institutions,
    sources = x$sources,
    references = dplyr::filter(x$references, .data$work_id %in% keep_ids),
    concepts = dplyr::filter(x$concepts, .data$work_id %in% keep_ids),
    embeddings = if (!is.null(x$embeddings) && nrow(x$embeddings) > 0) {
      idx <- which(rownames(x$embeddings) %in% keep_ids)
      if (length(idx) > 0) x$embeddings[idx, , drop = FALSE] else NULL
    },
    provenance = dplyr::filter(x$provenance, .data$work_id %in% keep_ids),
    screening = dplyr::filter(x$screening, .data$work_id %in% keep_ids),
    metadata = x$metadata
  )
}

#' @rdname sm_corpus
#' @export
length.sm_corpus <- function(x) {
  nrow(x$works)
}

#' @rdname sm_corpus
#' @export
dim.sm_corpus <- function(x) {

  c(nrow(x$works), ncol(x$works))
}

.ensure_works_schema <- function(works) {
  expected <- names(.empty_works())
  for (col in expected) {
    if (!col %in% names(works)) {
      works[[col]] <- switch(col,
        work_id = paste0("W", formatC(seq_len(nrow(works)), width = 9, flag = "0")),
        year = NA_integer_,
        cited_by_count = NA_integer_,
        is_retracted = FALSE,
        retraction_date = as.Date(NA),
        last_refreshed = Sys.time(),
        position = NA_integer_,
        is_corresponding = NA,
        NA_character_
      )
    }
  }
  works
}

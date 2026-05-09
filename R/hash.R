#' Hash a corpus for reproducibility
#'
#' @description
#' Computes a content-addressable SHA-256 hash of the corpus. The hash
#' captures the works, authors, authorships, references, concepts, screening,
#' and provenance tables. Metadata (which contains timestamps) is excluded
#' from the hash to allow comparing corpus content across sessions.
#'
#' Two corpora with identical scientific content will produce the same hash,
#' regardless of when they were built.
#'
#' @param corpus An `sm_corpus` object.
#'
#' @return A single character string containing the hex-encoded SHA-256 hash.
#'
#' @family reproducibility
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_hash_corpus(corpus)
sm_hash_corpus <- function(corpus) {
  .check_sm_corpus(corpus)

  # Build a canonical list of content components (exclude metadata/timestamps)
  content <- list(
    works = .canonicalize_tibble(
      dplyr::select(corpus$works, -dplyr::any_of(c("last_refreshed")))
    ),
    authors = .canonicalize_tibble(corpus$authors),
    authorships = .canonicalize_tibble(corpus$authorships),
    institutions = .canonicalize_tibble(corpus$institutions),
    sources = .canonicalize_tibble(corpus$sources),
    references = .canonicalize_tibble(corpus$references),
    concepts = .canonicalize_tibble(corpus$concepts),
    screening = .canonicalize_tibble(
      dplyr::select(corpus$screening, -dplyr::any_of(c("decided_at")))
    ),
    embeddings = if (!is.null(corpus$embeddings)) {
      round(corpus$embeddings, digits = 8)
    }
  )

  digest::digest(content, algo = "sha256")
}

#' Canonicalize a tibble for hashing
#'
#' Sorts by all columns to ensure deterministic ordering.
#' @noRd
.canonicalize_tibble <- function(tbl) {
  if (nrow(tbl) == 0L) return(tbl)
  tbl <- dplyr::arrange(tbl, dplyr::across(dplyr::everything()))
  tbl
}

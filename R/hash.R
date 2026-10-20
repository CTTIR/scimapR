#' Hash a corpus for reproducibility
#'
#' @description
#' Computes a content-addressable SHA-256 hash of the corpus. The hash
#' covers the works (without `last_refreshed`), authors, authorships,
#' institutions, sources, references, concepts, screening decisions
#' (without `decided_at`) and embeddings, and the yearly citation counts
#' (`citations_by_year`) when the corpus has any, so a corpus without them
#' hashes as it did before the element existed.
#'
#' Two corpora with identical scientific content will produce the same hash,
#' regardless of when they were built and of the order of their rows and
#' columns.
#'
#' The hash leaves out the provenance table, which records when each record
#' was fetched, and the metadata (timestamps, the lock, the embedding model
#' and the local input files of [sm_register_input()]): changing them does
#' not change the hash. [sm_verify_certificate()] checks the local input
#' files on their own.
#'
#' @details
#' `version` selects the algorithm. Version 2, the default from scimapR
#' 0.5.0 on, sorts the columns of every table by name and the rows of the
#' embeddings by work id before hashing, so the order in which the steps
#' that built a corpus added their columns no longer changes the hash.
#' Hashes of version 2 therefore differ from the hashes that earlier
#' versions of scimapR computed for the same content. Version 1 is the
#' algorithm of these earlier versions. Certificates ([sm_certificate()])
#' and snapshots ([sm_snapshot()]) record the version they used as
#' `hash_version`; those written before it existed are checked with
#' version 1, so they stay verifiable.
#'
#' @param corpus An `sm_corpus` object.
#' @param version The hash algorithm: `2` (default) or `1` (scimapR 0.4.0
#'   and earlier). See Details.
#'
#' @return A single character string containing the hex-encoded SHA-256 hash.
#'
#' @family reproducibility
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_hash_corpus(corpus)
#'
#' # the order of the columns does not matter
#' reordered <- corpus
#' reordered$works <- reordered$works[, rev(names(reordered$works))]
#' identical(sm_hash_corpus(reordered), sm_hash_corpus(corpus))
sm_hash_corpus <- function(corpus, version = 2L) {
  .check_sm_corpus(corpus)
  version <- .check_hash_version(version)
  sorted <- version >= 2L
  canon <- function(tbl) .canonicalize_tibble(tbl, sort_columns = sorted)

  # Build a canonical list of content components (exclude metadata/timestamps)
  content <- list(
    works = canon(
      dplyr::select(corpus$works, -dplyr::any_of(c("last_refreshed")))
    ),
    authors = canon(corpus$authors),
    authorships = canon(corpus$authorships),
    institutions = canon(corpus$institutions),
    sources = canon(corpus$sources),
    references = canon(corpus$references),
    concepts = canon(corpus$concepts),
    screening = canon(
      dplyr::select(corpus$screening, -dplyr::any_of(c("decided_at")))
    ),
    embeddings = .canonicalize_embeddings(corpus$embeddings,
                                          sort_rows = sorted)
  )
  # appended only when present, so that other hashes stay unchanged
  yearly <- corpus$citations_by_year
  if (!is.null(yearly) && nrow(yearly) > 0L) {
    content$citations_by_year <- canon(yearly)
  }

  digest::digest(content, algo = "sha256")
}

#' The current version of the corpus hash algorithm
#' @noRd
.hash_version <- 2L

#' Check a hash version: 1 or 2, as an integer
#' @noRd
.check_hash_version <- function(version, what = "{.arg version}",
                                call = rlang::caller_env()) {
  known <- rlang::is_integerish(version, n = 1) && !is.na(version) &&
    version %in% c(1, 2)
  if (!known) {
    cli::cli_abort(
      c(paste(what, "must be 1 or 2, the hash algorithms this version of",
              "scimapR knows."),
        "i" = "A newer version of scimapR may know more."),
      call = call
    )
  }
  as.integer(version)
}

#' Canonicalize a tibble for hashing
#'
#' Sorts by all columns to ensure deterministic ordering, and with
#' `sort_columns` (hash version 2) first orders the columns by name.
#' @noRd
.canonicalize_tibble <- function(tbl, sort_columns = FALSE) {
  if (sort_columns) {
    tbl <- tibble::as_tibble(tbl)
    tbl <- tbl[, order(names(tbl), method = "radix"), drop = FALSE]
  }
  if (nrow(tbl) == 0L) return(tbl)
  tbl <- dplyr::arrange(tbl, dplyr::across(dplyr::everything()))
  tbl
}

#' Canonicalize the embedding matrix for hashing: rounded, and with
#' `sort_rows` (hash version 2) its rows in the order of their work ids
#' @noRd
.canonicalize_embeddings <- function(emb, sort_rows = FALSE) {
  if (is.null(emb)) return(NULL)
  if (sort_rows && !is.null(rownames(emb))) {
    emb <- emb[order(rownames(emb), method = "radix"), , drop = FALSE]
  }
  round(emb, digits = 8)
}

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
#' 0.5.0 on, hashes canonical UTF-8 text, independently of R's binary
#' serialisation. Table columns are sorted by name and rows by their text
#' values, using radix ordering. Missing values are distinct from the
#' string `"NA"`. Numbers use 15 significant digits, signed zero becomes
#' zero, dates use ISO dates and timestamps use UTC with six decimal places
#' for seconds. List cells use JSON. Column classes are included in the
#' text. Embeddings are sorted by work id and rounded to eight decimal
#' places. These rules make version 2 independent of the R version,
#' platform, time zone and collation locale.
#' Hashes of version 2 therefore differ from the hashes that earlier
#' versions of scimapR computed for the same content. Version 1 is the
#' algorithm of these earlier versions. Certificates ([sm_certificate()])
#' and snapshots ([sm_snapshot()]) record the version they used as
#' `hash_version`; those written before it existed are checked with
#' version 1. Version 1 uses R's binary serialisation and depends on the
#' R version: older certificates and snapshots remain verifiable on the
#' R version that wrote them.
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
  if (version == 2L) {
    return(digest::digest(.hash_corpus_text(corpus), algo = "sha256",
                          serialize = FALSE))
  }
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

# Canonical text for the portable hash; the legacy helpers above stay intact.
.hash_column_text <- function(x) {
  if (inherits(x, "Date")) {
    return(format(x, "%Y-%m-%d"))
  }
  if (inherits(x, "POSIXct")) {
    return(format(x, "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC", usetz = FALSE))
  }
  if (is.factor(x) || is.character(x)) return(enc2utf8(as.character(x)))
  if (is.logical(x) || is.integer(x)) return(as.character(x))
  if (is.double(x)) {
    x[which(x == 0)] <- 0
    out <- sprintf("%.15g", x)
    out[is.nan(x)] <- "NaN"
    out[which(x == Inf)] <- "Inf"
    out[which(x == -Inf)] <- "-Inf"
    out[is.na(x) & !is.nan(x)] <- NA_character_
    return(out)
  }
  if (is.list(x)) {
    return(vapply(x, function(cell) {
      as.character(jsonlite::toJSON(cell, auto_unbox = TRUE, digits = NA,
                                    null = "null", na = "null"))
    }, character(1)))
  }
  enc2utf8(format(x))
}

.hash_table_text <- function(tbl, name) {
  tbl <- tbl[, order(names(tbl), method = "radix"), drop = FALSE]
  columns <- lapply(tbl, .hash_column_text)
  rows <- seq_len(nrow(tbl))
  if (length(columns) > 0L && length(rows) > 0L) {
    rows <- do.call(order, c(unname(columns),
                             list(method = "radix", na.last = TRUE)))
  }
  content <- list(
    table = name,
    columns = enc2utf8(names(tbl)),
    types = unname(vapply(tbl, function(x) paste(class(x), collapse = "/"),
                          character(1))),
    rows = lapply(rows, function(i) {
      unname(vapply(columns, function(x) x[i], character(1)))
    })
  )
  as.character(jsonlite::toJSON(content, auto_unbox = FALSE, digits = NA,
                                null = "null", na = "null"))
}

.hash_embeddings_text <- function(emb) {
  if (is.null(emb)) return('{"embeddings":null}')
  emb <- .canonicalize_embeddings(emb, sort_rows = TRUE)
  values <- matrix(sprintf("%.8f", emb), nrow = nrow(emb), ncol = ncol(emb))
  values[values == "-0.00000000"] <- "0.00000000"
  values[is.na(emb) & !is.nan(emb)] <- NA_character_
  content <- list(
    embeddings = list(
      dimensions = dim(emb),
      rownames = if (is.null(rownames(emb))) NULL else enc2utf8(rownames(emb)),
      colnames = if (is.null(colnames(emb))) NULL else enc2utf8(colnames(emb)),
      rows = lapply(seq_len(nrow(emb)), function(i) unname(values[i, ]))
    )
  )
  as.character(jsonlite::toJSON(content, auto_unbox = FALSE, digits = NA,
                                null = "null", na = "null"))
}

.hash_corpus_text <- function(corpus) {
  tables <- unclass(corpus)[c("works", "authors", "authorships", "institutions",
                              "sources", "references", "concepts", "screening")]
  tables$works <- dplyr::select(corpus$works, -dplyr::any_of("last_refreshed"))
  tables$screening <- dplyr::select(corpus$screening,
                                    -dplyr::any_of("decided_at"))
  yearly <- corpus$citations_by_year
  if (!is.null(yearly) && nrow(yearly) > 0L) tables$citations_by_year <- yearly
  text <- vapply(names(tables), function(name) {
    .hash_table_text(tables[[name]], name)
  }, character(1))
  paste(c(text, .hash_embeddings_text(corpus$embeddings)), collapse = "\n")
}

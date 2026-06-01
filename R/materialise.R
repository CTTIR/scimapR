# D1: enrichment -> corpus materializer.

#' Default key column(s) for each corpus sub-table
#' @noRd
.sm_default_keys <- function() {
  list(
    works = "work_id",
    authors = "author_id",
    authorships = c("work_id", "author_id"),
    institutions = "institution_id",
    sources = "source_id",
    references = c("work_id", "cited_work_id"),
    concepts = c("work_id", "concept_id"),
    provenance = "work_id",
    screening = "work_id"
  )
}

#' Read one enrichment source (tibble, RDS path, or parquet path)
#' @noRd
.sm_read_source <- function(x, name, call = rlang::caller_env()) {
  if (is.null(x)) return(NULL)
  if (is.data.frame(x)) return(tibble::as_tibble(x))
  if (is.character(x) && length(x) == 1L) {
    ext <- tolower(tools::file_ext(x))
    if (!file.exists(x)) {
      cli::cli_warn("Enrichment source {.field {name}}: file {.path {x}} not found; skipping.")
      return(NULL)
    }
    if (ext == "rds") return(tibble::as_tibble(readRDS(x)))
    if (ext %in% c("parquet", "pq")) {
      if (!rlang::is_installed("arrow")) {
        cli::cli_warn(c(
          "Enrichment source {.field {name}}: {.pkg arrow} needed to read {.path {x}}; skipping.",
          "i" = "Install {.pkg arrow} or pass a tibble / RDS path."
        ))
        return(NULL)
      }
      return(tibble::as_tibble(arrow::read_parquet(x)))
    }
    cli::cli_warn("Enrichment source {.field {name}}: unsupported file type {.val {ext}}; skipping.")
    return(NULL)
  }
  cli::cli_warn("Enrichment source {.field {name}} must be a data frame or a file path; skipping.")
  NULL
}

#' Merge one enrichment tibble into an existing sub-table by key
#' @noRd
.sm_merge_enrichment <- function(existing, new, key, table, overwrite,
                                 call = rlang::caller_env()) {
  missing_key_existing <- setdiff(key, names(existing))
  missing_key_new <- setdiff(key, names(new))
  if (length(missing_key_existing) > 0L || length(missing_key_new) > 0L) {
    cli::cli_warn(c(
      "!" = "Table {.field {table}}: key column{?s} {.field {key}} missing from {if (length(missing_key_new)) 'the enrichment source' else 'the corpus table'}; skipping this source.",
      "i" = "Supply the key via {.arg .by} or include it in the source."
    ))
    return(existing)
  }

  # de-duplicate the enrichment by key (keep first), warn if needed
  dup <- duplicated(new[key])
  if (any(dup)) {
    cli::cli_warn("Table {.field {table}}: enrichment has {sum(dup)} duplicate key row{?s}; keeping the first per key.")
    new <- new[!dup, , drop = FALSE]
  }

  data_cols <- setdiff(names(new), key)
  if (length(data_cols) == 0L) return(existing)

  common <- intersect(data_cols, names(existing))
  joined <- dplyr::left_join(existing, new, by = key, suffix = c("", ".sm_new"))

  for (col in common) {
    newcol <- joined[[paste0(col, ".sm_new")]]
    if (is.null(newcol)) next
    if (overwrite) {
      # enrichment wins where it is non-NA
      joined[[col]] <- dplyr::coalesce(newcol, joined[[col]])
    } else {
      # existing wins; enrichment only fills NA cells
      joined[[col]] <- dplyr::coalesce(joined[[col]], newcol)
    }
    joined[[paste0(col, ".sm_new")]] <- NULL
  }

  tibble::as_tibble(joined)
}

#' Materialise cached enrichment into a corpus
#'
#' @description
#' Joins cached enrichment data into the matching `sm_corpus` sub-tibbles by
#' their key columns, returning an updated, schema-valid `sm_corpus`. This
#' replaces hand-written cache-to-corpus joins (which are easy to get wrong ---
#' e.g. a `bind_rows()` that coerces a `NULL` element to a logical column).
#'
#' @param corpus An `sm_corpus`.
#' @param sources Either a named list whose names are corpus sub-tables
#'   (`works`, `authors`, `authorships`, `sources`, `institutions`,
#'   `references`, `concepts`, ...) and whose elements are tibbles or paths to
#'   cached `.rds`/`.parquet` files; or a single directory path containing
#'   `<table>.rds` / `<table>.parquet` files.
#' @param .by Optional named list mapping table name to its join key column(s).
#'   Defaults to each table's natural key (e.g. `works` -> `work_id`).
#' @param overwrite Logical (default `FALSE`). When `FALSE`, enrichment only
#'   fills `NA` cells of overlapping columns; populated cells are never
#'   overwritten. When `TRUE`, non-`NA` enrichment values win.
#' @param call Caller environment for error reporting.
#'
#' @return An updated, validated `sm_corpus` with the enrichment columns merged
#'   into the relevant sub-tables. New columns are added; existing rows are
#'   preserved (this is a column-enrichment join, not a row append).
#'
#' @details
#' Missing keys produce a `cli::cli_warn` and skip that source rather than
#' erroring. Internally, row-binds use a type-safe helper so a `NULL`/empty
#' source never corrupts a column's type.
#'
#' @family corpus
#' @seealso [sm_corpus_from_tables()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 10, seed = 1)
#' metrics <- tibble::tibble(work_id = corpus$works$work_id,
#'                           cnci = runif(10, 0.5, 2))
#' corpus2 <- sm_materialise(corpus, sources = list(works = metrics))
#' "cnci" %in% names(corpus2$works)
sm_materialise <- function(corpus, sources, .by = NULL, overwrite = FALSE,
                           call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_flag(overwrite, call = call)

  # resolve a directory path to a named list of files
  if (is.character(sources) && length(sources) == 1L &&
      dir.exists(sources)) {
    files <- list.files(sources, pattern = "\\.(rds|parquet|pq)$",
                        ignore.case = TRUE, full.names = TRUE)
    nm <- tools::file_path_sans_ext(basename(files))
    sources <- stats::setNames(as.list(files), nm)
  }

  if (!is.list(sources) || is.null(names(sources))) {
    cli::cli_abort(c(
      "{.arg sources} must be a named list of tibbles/paths, or a directory path.",
      "i" = "Names must be corpus sub-tables, e.g. {.code list(works = my_metrics)}."
    ), call = call)
  }

  keys <- .sm_default_keys()
  known <- names(keys)
  unknown <- setdiff(names(sources), known)
  if (length(unknown) > 0L) {
    cli::cli_warn("Ignoring unrecognised enrichment target{?s}: {.field {unknown}}.")
  }

  for (tbl in intersect(names(sources), known)) {
    new <- .sm_read_source(sources[[tbl]], tbl, call = call)
    if (is.null(new) || nrow(new) == 0L) next
    key <- if (!is.null(.by) && !is.null(.by[[tbl]])) .by[[tbl]] else keys[[tbl]]
    before <- ncol(corpus[[tbl]])
    corpus[[tbl]] <- .sm_merge_enrichment(corpus[[tbl]], new, key, tbl,
                                          overwrite, call = call)
    added <- ncol(corpus[[tbl]]) - before
    cli::cli_inform(c(
      "v" = "Materialised {nrow(new)} enrichment row{?s} into {.field {tbl}} (+{added} column{?s})."
    ))
  }

  validate_sm_corpus(corpus, call = call)
  corpus
}

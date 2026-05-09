#' Save and load corpus snapshots
#'
#' @description
#' `sm_snapshot()` serializes an `sm_corpus` to disk as a compressed RDS file,
#' embedding the corpus hash as part of the filename for traceability.
#'
#' `sm_snapshot_load()` reads a previously saved snapshot and validates that
#' the loaded object is a well-formed `sm_corpus`.
#'
#' @param corpus An `sm_corpus` object.
#' @param path Character. File path for the snapshot. If `NULL`, a path is
#'   generated in the current working directory using the corpus hash.
#' @param compress Character. Compression method passed to [saveRDS()].
#'   One of `"xz"` (default, best compression), `"gzip"`, `"bzip2"`,
#'   or `"none"`.
#' @param call Caller environment for error reporting.
#'
#' @return For `sm_snapshot()`: the file path (invisibly).
#'   For `sm_snapshot_load()`: an `sm_corpus` object.
#'
#' @family reproducibility
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' path <- tempfile(fileext = ".rds")
#' sm_snapshot(corpus, path = path)
#'
#' loaded <- sm_snapshot_load(path)
#' identical(nrow(corpus$works), nrow(loaded$works))
sm_snapshot <- function(corpus,
                        path = NULL,
                        compress = c("xz", "gzip", "bzip2", "none"),
                        call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  compress <- match.arg(compress)

  if (is.null(path)) {
    hash_short <- substr(sm_hash_corpus(corpus), 1, 8)
    date_stamp <- format(Sys.Date(), "%Y%m%d")
    path <- paste0("scimapR_corpus_", date_stamp, "_", hash_short, ".rds")
  }

  .check_string(path, call = call)

  # Ensure parent directory exists
  dir <- dirname(path)
  if (!fs::dir_exists(dir)) {
    cli::cli_abort(
      "Directory does not exist: {.path {dir}}",
      call = call
    )
  }

  # Store hash in metadata before saving
  corpus$metadata$corpus_hash <- sm_hash_corpus(corpus)
  corpus$metadata$snapshot_date <- Sys.time()

  saveRDS(corpus, file = path, compress = compress)

  file_size <- fs::file_size(path)
  cli::cli_inform(c(
    "v" = "Corpus snapshot saved to {.path {path}}.",
    "i" = "Size: {file_size} | Hash: {substr(corpus$metadata$corpus_hash, 1, 12)}"
  ))

  invisible(path)
}

#' @rdname sm_snapshot
#' @export
sm_snapshot_load <- function(path,
                             call = rlang::caller_env()) {
  .check_string(path, call = call)
  .check_file_exists(path, call = call)

  corpus <- readRDS(path)

  if (!is_sm_corpus(corpus)) {
    cli::cli_abort(
      "File {.path {path}} does not contain a valid {.cls sm_corpus} object.",
      call = call
    )
  }

  validate_sm_corpus(corpus, call = call)

  # Verify hash if stored
  stored_hash <- corpus$metadata$corpus_hash
  if (!is.na(stored_hash %||% NA_character_)) {
    current_hash <- sm_hash_corpus(corpus)
    if (!identical(stored_hash, current_hash)) {
      cli::cli_warn(c(
        "!" = "Corpus hash mismatch after loading snapshot.",
        "i" = "Stored: {substr(stored_hash, 1, 12)}",
        "i" = "Computed: {substr(current_hash, 1, 12)}",
        "i" = "The snapshot file may have been modified."
      ))
    }
  }

  cli::cli_inform(c(
    "v" = "Loaded corpus from {.path {path}}.",
    "i" = "{nrow(corpus$works)} works, {nrow(corpus$authors)} authors."
  ))

  corpus
}

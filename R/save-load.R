#' Save and load an sm_corpus
#'
#' @description
#' Persist a corpus to disk as RDS and reload it.
#'
#' @param corpus An `sm_corpus` object.
#' @param path File path for saving.
#' @param compress Compression type passed to [saveRDS()].
#'
#' @return For `sm_save_corpus`, the path invisibly. For `sm_load_corpus`,
#'   an `sm_corpus` object.
#'
#' @family corpus
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 10)
#' path <- tempfile(fileext = ".rds")
#' sm_save_corpus(corpus, path)
#' loaded <- sm_load_corpus(path)
#' nrow(loaded$works)
sm_save_corpus <- function(corpus, path, compress = "xz") {
  .check_sm_corpus(corpus)
  .check_string(path)
  saveRDS(corpus, file = path, compress = compress)
  .sm_done("Corpus saved to {.path {path}}")
  invisible(path)
}

#' @rdname sm_save_corpus
#' @export
sm_load_corpus <- function(path) {
  .check_file_exists(path)
  corpus <- readRDS(path)
  validate_sm_corpus(corpus)
  corpus
}

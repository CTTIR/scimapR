#' Export corpus as RDS
#'
#' @description
#' Save the full corpus including embeddings as a compressed RDS file.
#'
#' @param corpus An `sm_corpus` object.
#' @param path Output file path.
#' @param compress Compression type. Default `"xz"`.
#'
#' @return `path` invisibly.
#'
#' @family export
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 10)
#' path <- tempfile(fileext = ".rds")
#' sm_export_rds(corpus, path)
sm_export_rds <- function(corpus, path, compress = "xz") {
  .check_sm_corpus(corpus)
  saveRDS(corpus, file = path, compress = compress)
  .sm_done("Corpus saved to {.path {path}}")
  invisible(path)
}

#' Export corpus tables as CSV files
#'
#' @description
#' Write each corpus table as a separate CSV file in a directory.
#'
#' @param corpus An `sm_corpus` object.
#' @param dir Output directory.
#' @param ... Additional arguments passed to [readr::write_csv()].
#'
#' @return `dir` invisibly.
#'
#' @family export
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 10)
#' dir <- tempdir()
#' sm_export_csv(corpus, dir)
sm_export_csv <- function(corpus, dir, ...) {
  .check_sm_corpus(corpus)
  fs::dir_create(dir)

  tables <- c("works", "authors", "authorships", "institutions",
               "sources", "references", "concepts", "provenance", "screening")

  for (tbl_name in tables) {
    tbl <- corpus[[tbl_name]]
    if (!is.null(tbl) && nrow(tbl) > 0) {
      path <- file.path(dir, paste0(tbl_name, ".csv"))
      has_list <- any(vapply(tbl, is.list, logical(1)))
      if (has_list) {
        list_cols <- names(tbl)[vapply(tbl, is.list, logical(1))]
        for (lc in list_cols) {
          tbl[[lc]] <- vapply(tbl[[lc]], function(x) {
            paste(x, collapse = "; ")
          }, character(1))
        }
      }
      readr::write_csv(tbl, path, ...)
    }
  }

  .sm_done("Corpus tables saved to {.path {dir}}")
  invisible(dir)
}

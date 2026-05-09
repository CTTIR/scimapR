#' Export corpus as self-contained ZIP bundle
#'
#' @description
#' Build a ZIP archive containing the corpus RDS, certificate, figures,
#' tables, and an auto-generated README. This is the "send everything to
#' a collaborator" workflow.
#'
#' @param corpus An `sm_corpus` object.
#' @param path Output ZIP file path.
#' @param include Components to include in the bundle.
#' @param figure_formats Figure output formats.
#' @param figure_dpi Figure resolutions.
#' @param report_template Quarto report template.
#'
#' @return `path` invisibly.
#'
#' @family export
#' @export
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus(n_works = 10)
#' path <- tempfile(fileext = ".zip")
#' sm_export_zip(corpus, path, include = c("rds", "certificate"))
#' }
sm_export_zip <- function(corpus,
                          path,
                          include = c("rds", "certificate", "tables"),
                          figure_formats = c("png"),
                          figure_dpi = c(300),
                          report_template = "standard") {
  .check_sm_corpus(corpus)
  if ("tables" %in% include) {
    rlang::check_installed("openxlsx2",
      reason = "to write XLSX tables in the export bundle.")
  }

  tmpdir <- withr::local_tempdir()

  if ("rds" %in% include) {
    sm_export_rds(corpus, file.path(tmpdir, "corpus.rds"))
  }

  if ("certificate" %in% include) {
    cert <- sm_certificate(corpus,
                            path = file.path(tmpdir, "certificate.yaml"))
  }

  if ("tables" %in% include) {
    tbl_dir <- file.path(tmpdir, "tables")
    dir.create(tbl_dir, showWarnings = FALSE)
    sm_export_table(corpus$works, file.path(tbl_dir, "works.xlsx"))
    sm_export_table(corpus$authors, file.path(tbl_dir, "authors.xlsx"))
  }

  readme_content <- paste0(
    "# scimapR Corpus Bundle\n\n",
    "Generated: ", Sys.time(), "\n",
    "scimapR version: ", tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ), "\n",
    "Works: ", nrow(corpus$works), "\n",
    "Authors: ", nrow(corpus$authors), "\n\n",
    "## Contents\n\n",
    paste("- ", list.files(tmpdir, recursive = TRUE), collapse = "\n"),
    "\n"
  )
  writeLines(readme_content, file.path(tmpdir, "README.md"))

  files <- list.files(tmpdir, recursive = TRUE, full.names = TRUE)
  utils::zip(path, files = files, extras = "-j")

  .sm_done("Bundle saved to {.path {path}}")
  invisible(path)
}

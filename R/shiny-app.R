#' Launch the scimapR Shiny application
#'
#' @description
#' Launch a comprehensive 13-tab interactive explorer for bibliometric
#' analysis. The app provides auto/light/dark theming, publication-ready
#' export in multiple formats, and viridis colour palettes throughout.
#'
#' @param corpus An `sm_corpus` to load on startup. If `NULL`, loads
#'   `sm_example_corpus()` so users can explore without their own data.
#' @param launch.browser Passed to [shiny::runApp()].
#' @param ... Additional arguments passed to [shiny::runApp()].
#'
#' @return Invisible `NULL`. Launches a Shiny application.
#'
#' @export
#' @examples
#' \donttest{
#' if (interactive()) {
#'   sm_run_app()
#'   # sm_run_app(my_corpus)
#' }
#' }
sm_run_app <- function(corpus = NULL, launch.browser = TRUE, ...) {
  rlang::check_installed(
    c("shiny", "bslib", "DT", "shinyWidgets", "shinyjs",
      "fontawesome", "htmltools"),
    reason = "to launch the scimapR Shiny app"
  )

  if (is.null(corpus)) {
    corpus <- sm_example_corpus(seed = 42)
  }

  .check_sm_corpus(corpus)

  app_dir <- system.file("shiny", "scimapR", package = "scimapR")
  if (!nzchar(app_dir)) {
    cli::cli_abort("Shiny app not found in installed package.")
  }

  options(scimapR.shiny_corpus = corpus)
  on.exit(options(scimapR.shiny_corpus = NULL), add = TRUE)

  shiny::runApp(app_dir, launch.browser = launch.browser, ...)
}

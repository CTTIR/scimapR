#' Launch the scimapR Shiny application
#'
#' @description
#' Launch a comprehensive 17-tab interactive explorer for bibliometric
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
  rlang::check_installed(.app_packages(),
                         reason = "to launch the scimapR Shiny app")

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

#' Packages the Shiny app needs (the network tab also uses 'ggraph' when it
#' is installed)
#' @noRd
.app_packages <- function() {
  c("shiny", "bslib", "DT", "fontawesome")
}

#' Keep the `top_n` nodes of highest degree (ties by node order) of a network
#' for the app's network tab; the edges between them stay
#' @noRd
.app_top_nodes <- function(graph, top_n) {
  top_n <- suppressWarnings(as.integer(top_n))
  nodes <- tidygraph::activate(tidygraph::as_tbl_graph(graph), "nodes")
  degree <- dplyr::pull(
    dplyr::mutate(nodes, .degree = tidygraph::centrality_degree(mode = "all")),
    ".degree"
  )
  n <- length(degree)
  if (length(top_n) != 1L || is.na(top_n) || top_n < 1L || n <= top_n) {
    return(graph)
  }
  keep <- order(-degree, seq_len(n))[seq_len(top_n)]
  dplyr::filter(nodes, dplyr::row_number() %in% keep)
}

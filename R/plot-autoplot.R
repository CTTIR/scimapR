#' Autoplot for sm_corpus
#'
#' @description
#' Automatically generate a suitable plot for an `sm_corpus` based on the
#' requested type.
#'
#' @param object An `sm_corpus` object.
#' @param type Plot type.
#' @param ... Additional arguments passed to the plot function.
#'
#' @return A `ggplot` object.
#'
#' @importFrom ggplot2 autoplot
#' @family plots
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' ggplot2::autoplot(corpus, type = "production")
autoplot.sm_corpus <- function(object,
                               type = c("production", "landscape",
                                        "thematic", "collab", "equity",
                                        "top", "lotka", "bradford"),
                               ...) {
  type <- match.arg(type)

  switch(type,
    production = sm_plot_production(object, ...),
    landscape = sm_plot_landscape(object, ...),
    thematic = sm_plot_thematic_map(object, ...),
    collab = sm_plot_collab(object, ...),
    equity = sm_plot_equity_dashboard(object, ...),
    top = sm_plot_top(object, ...),
    lotka = sm_plot_lotka(object, ...),
    bradford = sm_plot_bradford(object, ...)
  )
}

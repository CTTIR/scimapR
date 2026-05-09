#' Plot topic evolution over time
#'
#' @description
#' Visualise how research topics/clusters evolve across time periods.
#'
#' @param corpus An `sm_corpus` with clusters and years.
#' @param time_var Column name for time variable. Default `"year"`.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
sm_plot_evolution <- function(corpus, time_var = "year",
                              dark = FALSE, ...) {
  .check_sm_corpus(corpus)

  if (!"cluster_id" %in% names(corpus$works)) {
    cli::cli_abort("Column {.field cluster_id} not found. Run clustering first.")
  }

  evo <- corpus$works %>%
    dplyr::filter(!is.na(.data$cluster_id), !is.na(.data[[time_var]])) %>%
    dplyr::count(.data[[time_var]], .data$cluster_id, name = "n")

  if (nrow(evo) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No cluster evolution data"))
  }

  evo$cluster_id <- as.factor(evo$cluster_id)

  ggplot2::ggplot(evo, ggplot2::aes(
    x = .data[[time_var]], y = .data$n, fill = .data$cluster_id
  )) +
    ggplot2::geom_area(alpha = 0.8, position = "stack") +
    sm_scale_fill(discrete = TRUE) +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Topic Evolution",
      x = tools::toTitleCase(time_var), y = "Number of Works",
      fill = "Cluster"
    )
}

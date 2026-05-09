#' Plot citation network
#'
#' @description
#' Visualise the citation network of top-cited works.
#'
#' @param corpus An `sm_corpus`.
#' @param top_n Number of top works to include.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @examplesIf requireNamespace("ggraph", quietly = TRUE)
#' corpus <- sm_example_corpus()
#' sm_plot_citation_network(corpus)
#'
#' @family plots
#' @export
sm_plot_citation_network <- function(corpus, top_n = 50L,
                                     dark = FALSE, ...) {
  .check_sm_corpus(corpus)
  rlang::check_installed("ggraph",
    reason = "to plot citation networks.")

  if (nrow(corpus$references) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No citation data"))
  }

  top_works <- corpus$works %>%
    dplyr::arrange(dplyr::desc(.data$cited_by_count)) %>%
    utils::head(top_n) %>%
    dplyr::pull(.data$work_id)

  edges <- corpus$references %>%
    dplyr::filter(
      .data$work_id %in% top_works,
      .data$cited_work_id %in% top_works
    )

  if (nrow(edges) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No internal citations among top works"))
  }

  nodes <- unique(c(edges$work_id, edges$cited_work_id))
  node_df <- corpus$works %>%
    dplyr::filter(.data$work_id %in% nodes) %>%
    dplyr::mutate(
      label = ifelse(
        nchar(.data$title) > 30,
        paste0(substr(.data$title, 1, 27), "..."),
        .data$title
      )
    )

  g <- tidygraph::tbl_graph(
    nodes = node_df,
    edges = tibble::tibble(
      from = match(edges$work_id, node_df$work_id),
      to = match(edges$cited_work_id, node_df$work_id)
    ),
    directed = TRUE
  )

  ggraph::ggraph(g, layout = "stress") +
    ggraph::geom_edge_link(alpha = 0.3, arrow = ggplot2::arrow(
      length = ggplot2::unit(2, "mm"), type = "closed"
    )) +
    ggraph::geom_node_point(
      ggplot2::aes(size = .data$cited_by_count),
      colour = viridisLite::viridis(1)
    ) +
    ggraph::theme_graph(base_family = "",
                        background = if (dark) "#0e0e0e" else "white") +
    sm_theme(dark = dark) +
    ggplot2::labs(title = "Citation Network", size = "Citations")
}

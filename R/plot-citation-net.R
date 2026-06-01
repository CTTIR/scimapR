#' Plot citation network
#'
#' @description
#' Visualise the citation network of top-cited works.
#'
#' @param corpus An `sm_corpus`.
#' @param top_n Number of top works to include.
#' @param dark Logical; dark mode?
#' @param precompute Logical (default `FALSE`). When `TRUE`, the graph layout is
#'   computed eagerly and a plain self-contained `ggplot` (materialised
#'   coordinates) is returned, instead of a lazy `ggraph` object. Use this when
#'   embedding the plot in an RMarkdown/knitr/`callr`/workflowr document: the
#'   heavy layout runs once here rather than in the (often memory-limited)
#'   render subprocess, where large `ggraph` objects can crash the harness.
#' @param max_nodes Optional integer node cap. `NULL` (default) keeps all nodes
#'   so existing renders are unchanged; set it to downsample large graphs to the
#'   highest-degree nodes (opt-in, with a `cli` message).
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object (a `ggraph` plot when `precompute = FALSE`, a plain
#'   `ggplot` when `precompute = TRUE`).
#'
#' @section Large graphs:
#' For big networks, prefer `precompute = TRUE` and save the returned object
#' (e.g. with [saveRDS()]); printing it in a document then re-renders cheaply
#' without recomputing the layout. See the networks section of the getting-
#' started vignette.
#'
#' @examplesIf requireNamespace("ggraph", quietly = TRUE)
#' corpus <- sm_example_corpus()
#' sm_plot_citation_network(corpus)
#'
#' @family plots
#' @export
sm_plot_citation_network <- function(corpus, top_n = 50L,
                                     dark = FALSE,
                                     precompute = FALSE,
                                     max_nodes = NULL, ...) {
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

  .sm_render_network(
    g, directed = TRUE, title = "Citation Network", dark = dark,
    precompute = precompute, max_nodes = max_nodes,
    node_size = "cited_by_count", node_label = FALSE
  )
}

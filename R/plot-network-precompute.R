# A4: lightweight precompute + node-cap path for network plots.
#
# ggraph objects compute their layout lazily at *print* time. Inside a knitr /
# callr / workflowr subprocess that lazy layout (plus the embedded graph) can
# blow up memory on large graphs. `precompute = TRUE` runs the layout eagerly
# here and returns a plain ggplot built from materialised coordinates, so the
# returned object prints cheaply in a document subprocess without re-running
# graph layout. A node cap bounds the work for very large graphs.

#' Cap a graph to its highest-degree nodes
#' @noRd
.sm_cap_graph <- function(g, max_nodes) {
  n_nodes <- nrow(tibble::as_tibble(tidygraph::activate(g, "nodes")))
  if (n_nodes <= max_nodes) return(g)
  cli::cli_inform(c(
    "i" = "Network has {n_nodes} nodes; capping to the {max_nodes} highest-degree nodes.",
    "i" = "Override with {.arg max_nodes} (larger graphs are slower to lay out and render)."
  ))
  g %>%
    tidygraph::activate("nodes") %>%
    dplyr::mutate(.sm_deg = tidygraph::centrality_degree()) %>%
    dplyr::slice_max(.data$.sm_deg, n = max_nodes, with_ties = FALSE) %>%
    dplyr::select(-".sm_deg")
}

#' Render a tidygraph as either a lazy ggraph or an eager (precomputed) ggplot
#'
#' @param g A `tbl_graph`.
#' @param directed Logical; draw directed edge arrows.
#' @param title Plot title.
#' @param dark Logical; dark mode.
#' @param precompute Logical; eager-layout plain ggplot vs lazy ggraph.
#' @param max_nodes Integer node cap.
#' @param layout ggraph/igraph layout name.
#' @param edge_weight Logical; map edge `weight` to width.
#' @param node_size Optional node column name mapped to point size.
#' @param node_label Logical; draw node text labels.
#' @noRd
.sm_render_network <- function(g, directed, title, dark,
                               precompute = FALSE, max_nodes = 200L,
                               layout = "stress",
                               edge_weight = FALSE,
                               node_size = NULL,
                               node_label = FALSE) {
  g <- .sm_cap_graph(g, max_nodes)
  fg <- if (dark) "#e8e8e8" else "#1a1a1a"
  base_col <- viridisLite::viridis(1)

  if (!precompute) {
    p <- ggraph::ggraph(g, layout = layout)
    if (edge_weight) {
      p <- p + ggraph::geom_edge_link(
        ggplot2::aes(width = .data$weight), alpha = 0.4, colour = base_col)
    } else {
      p <- p + ggraph::geom_edge_link(
        alpha = 0.3,
        arrow = if (directed) ggplot2::arrow(
          length = ggplot2::unit(2, "mm"), type = "closed") else NULL)
    }
    if (!is.null(node_size)) {
      p <- p + ggraph::geom_node_point(
        ggplot2::aes(size = .data[[node_size]]), colour = base_col)
    } else {
      p <- p + ggraph::geom_node_point(
        size = 4, colour = viridisLite::viridis(1, begin = 0.3))
    }
    if (node_label) {
      p <- p + ggraph::geom_node_text(
        ggplot2::aes(label = .data$name), repel = TRUE, size = 3)
    }
    return(
      p +
        ggraph::theme_graph(base_family = "",
                            background = if (dark) "#0e0e0e" else "white") +
        ggplot2::labs(title = title,
                      size = if (!is.null(node_size)) "Citations" else NULL)
    )
  }

  # ---- precompute: eager layout -> plain ggplot ----
  lay <- ggraph::create_layout(g, layout = layout)
  nodes_df <- as.data.frame(lay)
  edges_df <- tibble::as_tibble(tidygraph::activate(g, "edges"))

  p <- ggplot2::ggplot()
  if (nrow(edges_df) > 0L) {
    edges_df$x <- nodes_df$x[edges_df$from]
    edges_df$y <- nodes_df$y[edges_df$from]
    edges_df$xend <- nodes_df$x[edges_df$to]
    edges_df$yend <- nodes_df$y[edges_df$to]
    if (edge_weight && "weight" %in% names(edges_df)) {
      p <- p + ggplot2::geom_segment(
        data = edges_df,
        ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend,
                     yend = .data$yend, linewidth = .data$weight),
        alpha = 0.4, colour = base_col) +
        ggplot2::scale_linewidth(range = c(0.2, 2), guide = "none")
    } else {
      p <- p + ggplot2::geom_segment(
        data = edges_df,
        ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend,
                     yend = .data$yend),
        alpha = 0.3, colour = base_col,
        arrow = if (directed) ggplot2::arrow(
          length = ggplot2::unit(2, "mm"), type = "closed") else NULL)
    }
  }

  if (!is.null(node_size) && node_size %in% names(nodes_df)) {
    p <- p + ggplot2::geom_point(
      data = nodes_df,
      ggplot2::aes(x = .data$x, y = .data$y, size = .data[[node_size]]),
      colour = base_col)
  } else {
    p <- p + ggplot2::geom_point(
      data = nodes_df, ggplot2::aes(x = .data$x, y = .data$y),
      size = 3, colour = viridisLite::viridis(1, begin = 0.3))
  }

  if (node_label && "name" %in% names(nodes_df)) {
    p <- p + ggplot2::geom_text(
      data = nodes_df,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$name),
      size = 3, colour = fg, vjust = -0.6)
  }

  p +
    ggplot2::coord_equal() +
    sm_theme(dark = dark) +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      panel.border = ggplot2::element_blank()
    ) +
    ggplot2::labs(title = title,
                  size = if (!is.null(node_size)) "Citations" else NULL)
}

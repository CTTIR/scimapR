#' Plot collaboration map
#'
#' @description
#' Visualise international or institutional collaboration patterns.
#'
#' @param corpus An `sm_corpus`.
#' @param level Collaboration level.
#' @param top_n Number of top entities to include.
#' @param dark Logical; dark mode?
#' @param precompute Logical (default `FALSE`). When `TRUE`, return a plain
#'   `ggplot` with the layout computed eagerly (see [sm_plot_citation_network()]
#'   for why this matters when knitting large graphs).
#' @param max_nodes Optional integer node cap. `NULL` (default) keeps all
#'   nodes; set it to downsample large graphs to the highest-degree nodes
#'   (opt-in, with a `cli` message).
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object (`ggraph` when `precompute = FALSE`, plain `ggplot`
#'   when `precompute = TRUE`).
#'
#' @examplesIf requireNamespace("ggraph", quietly = TRUE)
#' corpus <- sm_example_corpus()
#' sm_plot_collab(corpus, level = "country")
#'
#' @family plots
#' @export
sm_plot_collab <- function(corpus,
                           level = c("country", "institution", "author"),
                           top_n = 20L,
                           dark = FALSE,
                           precompute = FALSE,
                           max_nodes = NULL, ...) {
  .check_sm_corpus(corpus)
  rlang::check_installed("ggraph",
    reason = "to plot collaboration networks.")
  level <- match.arg(level)

  if (level == "country") {
    collab <- corpus$authorships %>%
      dplyr::filter(!is.na(.data$country_code)) %>%
      dplyr::select("work_id", "country_code") %>%
      dplyr::distinct()

    pairs <- collab %>%
      dplyr::inner_join(collab, by = "work_id",
                         relationship = "many-to-many") %>%
      dplyr::filter(.data$country_code.x < .data$country_code.y) %>%
      dplyr::count(.data$country_code.x, .data$country_code.y,
                    name = "weight", sort = TRUE) %>%
      utils::head(top_n)

    if (nrow(pairs) == 0) {
      return(ggplot2::ggplot() + sm_theme(dark = dark) +
               ggplot2::labs(title = "No collaboration data"))
    }

    nodes <- unique(c(pairs$country_code.x, pairs$country_code.y))

    g <- tidygraph::tbl_graph(
      nodes = tibble::tibble(name = nodes),
      edges = tibble::tibble(
        from = match(pairs$country_code.x, nodes),
        to = match(pairs$country_code.y, nodes),
        weight = pairs$weight
      ),
      directed = FALSE
    )

    .sm_render_network(
      g, directed = FALSE, title = "Collaboration Network", dark = dark,
      precompute = precompute, max_nodes = max_nodes,
      edge_weight = TRUE, node_label = TRUE
    )
  } else if (level == "institution") {
    collab <- corpus$authorships %>%
      dplyr::filter(!is.na(.data$institution_id)) %>%
      dplyr::select("work_id", "institution_id") %>%
      dplyr::distinct()

    pairs <- collab %>%
      dplyr::inner_join(collab, by = "work_id",
                         relationship = "many-to-many") %>%
      dplyr::filter(.data$institution_id.x < .data$institution_id.y) %>%
      dplyr::count(.data$institution_id.x, .data$institution_id.y,
                    name = "weight", sort = TRUE) %>%
      utils::head(top_n)

    if (nrow(pairs) == 0) {
      return(ggplot2::ggplot() + sm_theme(dark = dark) +
               ggplot2::labs(title = "No institutional collaboration data"))
    }

    inst_lkp <- corpus$institutions %>%
      dplyr::select("institution_id", "display_name") %>%
      dplyr::distinct()

    pairs <- pairs %>%
      dplyr::left_join(inst_lkp, by = c("institution_id.x" = "institution_id")) %>%
      dplyr::rename(name_x = "display_name") %>%
      dplyr::left_join(inst_lkp, by = c("institution_id.y" = "institution_id")) %>%
      dplyr::rename(name_y = "display_name") %>%
      dplyr::mutate(
        name_x = dplyr::coalesce(.data$name_x, .data$institution_id.x),
        name_y = dplyr::coalesce(.data$name_y, .data$institution_id.y)
      )

    nodes <- unique(c(pairs$name_x, pairs$name_y))

    g <- tidygraph::tbl_graph(
      nodes = tibble::tibble(name = nodes),
      edges = tibble::tibble(
        from = match(pairs$name_x, nodes),
        to = match(pairs$name_y, nodes),
        weight = pairs$weight
      ),
      directed = FALSE
    )

    .sm_render_network(
      g, directed = FALSE, title = "Institutional Collaboration Network",
      dark = dark, precompute = precompute, max_nodes = max_nodes,
      edge_weight = TRUE, node_label = TRUE
    )

  } else {
    collab <- corpus$authorships %>%
      dplyr::filter(!is.na(.data$author_id)) %>%
      dplyr::select("work_id", "author_id") %>%
      dplyr::distinct()

    pairs <- collab %>%
      dplyr::inner_join(collab, by = "work_id",
                         relationship = "many-to-many") %>%
      dplyr::filter(.data$author_id.x < .data$author_id.y) %>%
      dplyr::count(.data$author_id.x, .data$author_id.y,
                    name = "weight", sort = TRUE) %>%
      utils::head(top_n)

    if (nrow(pairs) == 0) {
      return(ggplot2::ggplot() + sm_theme(dark = dark) +
               ggplot2::labs(title = "No author collaboration data"))
    }

    auth_lkp <- corpus$authors %>%
      dplyr::select("author_id", "display_name") %>%
      dplyr::distinct()

    pairs <- pairs %>%
      dplyr::left_join(auth_lkp, by = c("author_id.x" = "author_id")) %>%
      dplyr::rename(name_x = "display_name") %>%
      dplyr::left_join(auth_lkp, by = c("author_id.y" = "author_id")) %>%
      dplyr::rename(name_y = "display_name") %>%
      dplyr::mutate(
        name_x = dplyr::coalesce(.data$name_x, .data$author_id.x),
        name_y = dplyr::coalesce(.data$name_y, .data$author_id.y)
      )

    nodes <- unique(c(pairs$name_x, pairs$name_y))

    g <- tidygraph::tbl_graph(
      nodes = tibble::tibble(name = nodes),
      edges = tibble::tibble(
        from = match(pairs$name_x, nodes),
        to = match(pairs$name_y, nodes),
        weight = pairs$weight
      ),
      directed = FALSE
    )

    .sm_render_network(
      g, directed = FALSE, title = "Author Collaboration Network",
      dark = dark, precompute = precompute, max_nodes = max_nodes,
      edge_weight = TRUE, node_label = TRUE
    )
  }
}

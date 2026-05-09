#' Plot collaboration map
#'
#' @description
#' Visualise international or institutional collaboration patterns.
#'
#' @param corpus An `sm_corpus`.
#' @param level Collaboration level.
#' @param top_n Number of top entities to include.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("ggraph", quietly = TRUE)) {
#'   corpus <- sm_example_corpus()
#'   sm_plot_collab(corpus, level = "country")
#' }
#' }
#'
#' @family plots
#' @export
sm_plot_collab <- function(corpus,
                           level = c("country", "institution", "author"),
                           top_n = 20L,
                           dark = FALSE, ...) {
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

    ggraph::ggraph(g, layout = "stress") +
      ggraph::geom_edge_link(
        ggplot2::aes(width = .data$weight),
        alpha = 0.4,
        colour = viridisLite::viridis(1)
      ) +
      ggraph::geom_node_point(size = 4,
                               colour = viridisLite::viridis(1, begin = 0.3)) +
      ggraph::geom_node_text(ggplot2::aes(label = .data$name),
                              repel = TRUE, size = 3) +
      sm_theme(dark = dark) +
      ggplot2::labs(title = "Collaboration Network") +
      ggraph::theme_graph(base_family = "",
                          background = if (dark) "#0e0e0e" else "white")
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

    ggraph::ggraph(g, layout = "stress") +
      ggraph::geom_edge_link(
        ggplot2::aes(width = .data$weight),
        alpha = 0.4,
        colour = viridisLite::viridis(1)
      ) +
      ggraph::geom_node_point(size = 4,
                               colour = viridisLite::viridis(1, begin = 0.3)) +
      ggraph::geom_node_text(ggplot2::aes(label = .data$name),
                              repel = TRUE, size = 3) +
      sm_theme(dark = dark) +
      ggplot2::labs(title = "Institutional Collaboration Network") +
      ggraph::theme_graph(base_family = "",
                          background = if (dark) "#0e0e0e" else "white")

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

    ggraph::ggraph(g, layout = "stress") +
      ggraph::geom_edge_link(
        ggplot2::aes(width = .data$weight),
        alpha = 0.4,
        colour = viridisLite::viridis(1)
      ) +
      ggraph::geom_node_point(size = 4,
                               colour = viridisLite::viridis(1, begin = 0.3)) +
      ggraph::geom_node_text(ggplot2::aes(label = .data$name),
                              repel = TRUE, size = 3) +
      sm_theme(dark = dark) +
      ggplot2::labs(title = "Author Collaboration Network") +
      ggraph::theme_graph(base_family = "",
                          background = if (dark) "#0e0e0e" else "white")
  }
}

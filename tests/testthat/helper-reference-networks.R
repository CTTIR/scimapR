reference_edges <- function(graph, map = NULL, directed = FALSE) {
  nodes <- tibble::as_tibble(tidygraph::activate(graph, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(graph, "edges"))
  ids <- nodes$name
  if (!is.null(map)) ids <- dplyr::coalesce(unname(map[ids]), ids)
  from <- ids[edges$from]
  to <- ids[edges$to]
  lower <- if (directed) from else pmin(from, to)
  upper <- if (directed) to else pmax(from, to)
  out <- tibble::tibble(
    from = lower,
    to = upper,
    weight = edges[["weight"]] %||% rep(1L, nrow(edges))
  )
  dplyr::arrange(out, .data$from, .data$to)
}

#' Export network for Gephi (GEXF format)
#'
#' @description
#' Write a tidygraph network to GEXF XML format for use with Gephi.
#'
#' @param network A `tbl_graph` object.
#' @param path Output file path (should end in `.gexf`).
#'
#' @return `path` invisibly.
#'
#' @family export
#' @export
sm_export_gephi <- function(network, path) {
  if (!inherits(network, "tbl_graph")) {
    cli::cli_abort("{.arg network} must be a {.cls tbl_graph} object.")
  }

  nodes <- tidygraph::as_tibble(network, what = "nodes")
  edges <- tidygraph::as_tibble(network, what = "edges")

  xml_header <- '<?xml version="1.0" encoding="UTF-8"?>\n<gexf xmlns="http://gexf.net/1.3">\n  <graph defaultedgetype="undirected">\n'

  node_lines <- paste0(
    '      <node id="', seq_len(nrow(nodes)), '" label="',
    if ("name" %in% names(nodes)) nodes$name else seq_len(nrow(nodes)),
    '"/>'
  )

  edge_lines <- paste0(
    '      <edge id="', seq_len(nrow(edges)),
    '" source="', edges$from,
    '" target="', edges$to,
    if ("weight" %in% names(edges)) paste0('" weight="', edges$weight) else "",
    '"/>'
  )

  xml_content <- paste0(
    xml_header,
    "    <nodes>\n",
    paste(node_lines, collapse = "\n"), "\n",
    "    </nodes>\n",
    "    <edges>\n",
    paste(edge_lines, collapse = "\n"), "\n",
    "    </edges>\n",
    "  </graph>\n</gexf>\n"
  )

  writeLines(xml_content, path)
  .sm_done("Network exported to {.path {path}}")
  invisible(path)
}

#' Export network for VOSviewer
#'
#' @description
#' Write network to VOSviewer-compatible format.
#'
#' @param network A `tbl_graph` object.
#' @param path Output file path.
#'
#' @return `path` invisibly.
#'
#' @family export
#' @export
sm_export_vosviewer <- function(network, path) {
  if (!inherits(network, "tbl_graph")) {
    cli::cli_abort("{.arg network} must be a {.cls tbl_graph} object.")
  }

  edges <- tidygraph::as_tibble(network, what = "edges")
  nodes <- tidygraph::as_tibble(network, what = "nodes")

  node_names <- if ("name" %in% names(nodes)) nodes$name else as.character(seq_len(nrow(nodes)))

  out <- tibble::tibble(
    from = node_names[edges$from],
    to = node_names[edges$to],
    weight = if ("weight" %in% names(edges)) edges$weight else 1L
  )

  readr::write_tsv(out, path)
  .sm_done("Network exported for VOSviewer to {.path {path}}")
  invisible(path)
}

#' Export network for Cytoscape (JSON)
#'
#' @description
#' Write network to Cytoscape JSON format.
#'
#' @param network A `tbl_graph` object.
#' @param path Output file path.
#'
#' @return `path` invisibly.
#'
#' @family export
#' @export
sm_export_cytoscape <- function(network, path) {
  if (!inherits(network, "tbl_graph")) {
    cli::cli_abort("{.arg network} must be a {.cls tbl_graph} object.")
  }

  nodes <- tidygraph::as_tibble(network, what = "nodes")
  edges <- tidygraph::as_tibble(network, what = "edges")

  node_names <- if ("name" %in% names(nodes)) nodes$name else as.character(seq_len(nrow(nodes)))

  cy_nodes <- lapply(seq_len(nrow(nodes)), function(i) {
    list(data = list(id = node_names[i], name = node_names[i]))
  })

  cy_edges <- lapply(seq_len(nrow(edges)), function(i) {
    list(data = list(
      source = node_names[edges$from[i]],
      target = node_names[edges$to[i]],
      weight = if ("weight" %in% names(edges)) edges$weight[i] else 1
    ))
  })

  cy_json <- list(elements = list(nodes = cy_nodes, edges = cy_edges))
  jsonlite::write_json(cy_json, path, auto_unbox = TRUE, pretty = TRUE)

  .sm_done("Network exported for Cytoscape to {.path {path}}")
  invisible(path)
}

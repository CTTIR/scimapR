#' Export network for Gephi (GEXF format)
#'
#' @description
#' Write a tidygraph network to GEXF XML format for use with Gephi.
#' Labels are escaped as XML, and directed networks retain their direction.
#'
#' @param network A `tbl_graph` object.
#' @param path Output file path (should end in `.gexf`).
#'
#' @return `path` invisibly.
#'
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus()
#' net <- sm_network_cocitation(corpus)
#' sm_export_gephi(net, tempfile(fileext = ".gexf"))
#' }
#'
#' @family export
#' @export
sm_export_gephi <- function(network, path) {
  if (!inherits(network, "tbl_graph")) {
    cli::cli_abort("{.arg network} must be a {.cls tbl_graph} object.")
  }

  nodes <- tibble::as_tibble(tidygraph::activate(network, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(network, "edges"))
  labels <- nodes[["name"]] %||% as.character(seq_len(nrow(nodes)))
  directed <- tidygraph::with_graph(network, tidygraph::graph_is_directed())
  doc <- xml2::xml_new_root("gexf", xmlns = "http://gexf.net/1.3",
                            version = "1.3")
  graph <- xml2::xml_add_child(
    doc, "graph", mode = "static",
    defaultedgetype = if (directed) "directed" else "undirected"
  )
  xml_nodes <- xml2::xml_add_child(graph, "nodes")
  for (i in seq_len(nrow(nodes))) {
    xml2::xml_add_child(xml_nodes, "node", id = as.character(i),
                        label = as.character(labels[i]))
  }
  xml_edges <- xml2::xml_add_child(graph, "edges")
  for (i in seq_len(nrow(edges))) {
    edge <- xml2::xml_add_child(xml_edges, "edge", id = as.character(i),
                                source = as.character(edges$from[i]),
                                target = as.character(edges$to[i]))
    if ("weight" %in% names(edges)) {
      xml2::xml_set_attr(edge, "weight", as.character(edges$weight[i]))
    }
  }
  xml2::write_xml(doc, path, encoding = "UTF-8")
  .sm_done("Network exported to {.path {path}}")
  invisible(path)
}

#' Export network for VOSviewer
#'
#' @description
#' Write a headerless network file with integer node ids and positive link
#' strengths, plus a tab-separated map file with `id` and `label` columns.
#' Missing weights become 1. Directed edges are written as supplied, but
#' VOSviewer treats the links as undirected.
#'
#' @param network A `tbl_graph` object.
#' @param path Output file path.
#' @param map_path Map file path. By default, `_map` is inserted before the
#'   extension of `path`, or appended if `path` has no extension.
#'
#' @return `path` invisibly.
#'
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus()
#' net <- sm_network_cocitation(corpus)
#' sm_export_vosviewer(net, tempfile(fileext = ".tsv"))
#' # The matching map file is written beside the network file.
#' }
#'
#' @family export
#' @export
sm_export_vosviewer <- function(network, path, map_path = NULL) {
  if (!inherits(network, "tbl_graph")) {
    cli::cli_abort("{.arg network} must be a {.cls tbl_graph} object.")
  }

  edges <- tibble::as_tibble(tidygraph::activate(network, "edges"))
  nodes <- tibble::as_tibble(tidygraph::activate(network, "nodes"))
  labels <- nodes[["name"]] %||% as.character(seq_len(nrow(nodes)))
  weight <- edges[["weight"]] %||% rep(1L, nrow(edges))
  if (!is.numeric(weight) || any(!is.finite(weight) | weight <= 0)) {
    cli::cli_abort("VOSviewer link strengths must be finite positive numbers.",
                   class = "scimapR_invalid_network_weights")
  }
  if (is.null(map_path)) {
    ext <- tools::file_ext(path)
    map_path <- if (nzchar(ext)) {
      paste0(tools::file_path_sans_ext(path), "_map.", ext)
    } else {
      paste0(path, "_map")
    }
  }
  if (identical(normalizePath(path, mustWork = FALSE),
                normalizePath(map_path, mustWork = FALSE))) {
    cli::cli_abort("{.arg path} and {.arg map_path} must be different files.")
  }
  out <- tibble::tibble(from = edges$from, to = edges$to, weight = weight)
  map <- tibble::tibble(id = seq_len(nrow(nodes)), label = labels)
  readr::write_tsv(map, map_path, quote = "all")
  readr::write_tsv(out, path, col_names = FALSE)
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
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus()
#' net <- sm_network_cocitation(corpus)
#' sm_export_cytoscape(net, tempfile(fileext = ".json"))
#' }
#'
#' @family export
#' @export
sm_export_cytoscape <- function(network, path) {
  if (!inherits(network, "tbl_graph")) {
    cli::cli_abort("{.arg network} must be a {.cls tbl_graph} object.")
  }

  nodes <- tibble::as_tibble(tidygraph::activate(network, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(network, "edges"))

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

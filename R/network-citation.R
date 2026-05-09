#' Build a direct citation network
#'
#' @description
#' Constructs a directed citation network from the references table of an
#' `sm_corpus`. Each node represents a work and a directed edge runs from the
#' citing work to the cited work. Only works present in the corpus (i.e. both
#' the citing and cited work exist in `corpus$works`) are included as nodes
#' unless external references are also present via `cited_work_id`.
#'
#' @param corpus An [sm_corpus] object. Must contain a non-empty `references`
#'   table with columns `work_id` and `cited_work_id`.
#' @param call Caller environment for error reporting.
#'
#' @return A [tidygraph::tbl_graph] object (directed). Node data contains
#'   `name` (the work ID) plus any columns from `corpus$works`. Edge data
#'   contains `from`, `to`, and any additional reference metadata.
#'
#' @details
#' Empty input (zero works or zero references) returns an empty directed
#' `tbl_graph` with a single `name` column on nodes and no edges.
#'
#' @family networks
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' g <- sm_network_citation(corpus)
#' g
sm_network_citation <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)


  refs <- corpus$references
  works <- corpus$works


  # --- empty input guard ---

  if (nrow(works) == 0L || nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = TRUE))
  }


  # Keep only edges where cited_work_id is non-NA
  refs <- dplyr::filter(refs, !is.na(.data$cited_work_id))
  if (nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = works$work_id)
    nodes <- dplyr::left_join(nodes, works, by = c("name" = "work_id"))
    edges <- tibble::tibble(from = integer(), to = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = TRUE))
  }


  # Collect unique node IDs from both sides
  all_ids <- unique(c(refs$work_id, refs$cited_work_id))


  # Build node table
  nodes <- tibble::tibble(name = all_ids)
  nodes <- dplyr::left_join(nodes, works, by = c("name" = "work_id"))


  # Build edge list using integer indices
  node_idx <- stats::setNames(seq_along(nodes$name), nodes$name)
  edges <- tibble::tibble(
    from = unname(node_idx[refs$work_id]),
    to   = unname(node_idx[refs$cited_work_id])
  )


  # Remove edges where either side was not found (NA index)
  edges <- dplyr::filter(edges, !is.na(.data$from), !is.na(.data$to))


  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = TRUE)
}

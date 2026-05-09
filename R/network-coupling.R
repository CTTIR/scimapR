#' Build a bibliographic coupling network
#'
#' @description
#' Constructs an undirected bibliographic coupling network. Two works are
#' connected if they share at least `min_shared` cited references. The edge
#' weight equals the number of shared references.
#'
#' @param corpus An [sm_corpus] object with a populated `references` table.
#' @param min_shared Integer; minimum number of shared references to create an
#'   edge. Defaults to `1L`.
#' @param call Caller environment for error reporting.
#'
#' @return A [tidygraph::tbl_graph] object (undirected). Nodes carry `name`
#'   (work ID) and columns from `corpus$works`. Edges carry a `weight` column
#'   representing the number of shared references.
#'
#' @details
#' Bibliographic coupling is the mirror of co-citation: two works are coupled
#' if they cite the same references, suggesting intellectual similarity.
#'
#' Empty input (zero works, zero references, or no pairs above the threshold)
#' returns an empty undirected `tbl_graph`.
#'
#' @family networks
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' g <- sm_network_coupling(corpus, min_shared = 3L)
#' g
sm_network_coupling <- function(corpus,
                                min_shared = 1L,
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  min_shared <- .check_positive_int(min_shared, call = call)

  refs <- corpus$references
  works <- corpus$works

  # --- empty input guard ---
  if (nrow(works) == 0L || nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  refs <- dplyr::filter(refs, !is.na(.data$cited_work_id))
  if (nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Self-join on cited_work_id: two citing works sharing the same reference
  pairs <- refs %>%
    dplyr::select("work_id", "cited_work_id") %>%
    dplyr::inner_join(
      refs %>% dplyr::select(work_id_2 = "work_id", "cited_work_id"),
      by = "cited_work_id",
      relationship = "many-to-many"
    ) %>%
    dplyr::filter(.data$work_id < .data$work_id_2) %>%
    dplyr::count(.data$work_id, .data$work_id_2, name = "weight") %>%
    dplyr::filter(.data$weight >= min_shared)

  if (nrow(pairs) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Build node table
  all_ids <- unique(c(pairs$work_id, pairs$work_id_2))
  nodes <- tibble::tibble(name = all_ids)
  nodes <- dplyr::left_join(nodes, works, by = c("name" = "work_id"))

  # Build edge list
  node_idx <- stats::setNames(seq_along(nodes$name), nodes$name)
  edges <- tibble::tibble(
    from   = unname(node_idx[pairs$work_id]),
    to     = unname(node_idx[pairs$work_id_2]),
    weight = pairs$weight
  )

  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE)
}

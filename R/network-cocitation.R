#' Build a co-citation network
#'
#' @description
#' Constructs an undirected co-citation network. Two works (A and B) are
#' connected by an edge if they are both cited by a common third work. The edge
#' weight equals the number of works that co-cite A and B.
#'
#' @param corpus An [sm_corpus] object with a populated `references` table.
#' @param min_weight Integer; minimum co-citation count to retain an edge.
#'   Defaults to `2L` to reduce noise.
#' @param call Caller environment for error reporting.
#'
#' @return A [tidygraph::tbl_graph] object (undirected). Nodes carry `name`
#'   (work ID) and columns from `corpus$works`. Edges carry a `weight` column
#'   representing co-citation frequency.
#'
#' @details
#' The algorithm:
#' 1. For every citing work, enumerate all pairs of cited works.
#' 2. Count how often each pair co-occurs.
#' 3. Filter by `min_weight`.
#'
#' Empty input (zero works, zero references, or no pairs above the threshold)
#' returns an empty undirected `tbl_graph`.
#'
#' @family networks
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' g <- sm_network_cocitation(corpus, min_weight = 2L)
#' g
sm_network_cocitation <- function(corpus,
                                  min_weight = 2L,
                                  call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  min_weight <- .check_positive_int(min_weight, call = call)

  refs <- corpus$references
  works <- corpus$works

  # --- empty input guard ---
  if (nrow(works) == 0L || nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Keep only references with non-NA cited_work_id

  refs <- dplyr::filter(refs, !is.na(.data$cited_work_id))
  if (nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # For each citing work, enumerate pairs of cited works
  pairs <- refs %>%
    dplyr::select("work_id", "cited_work_id") %>%
    dplyr::inner_join(
      refs %>% dplyr::select("work_id", cited_work_id_2 = "cited_work_id"),
      by = "work_id",
      relationship = "many-to-many"
    ) %>%
    dplyr::filter(.data$cited_work_id < .data$cited_work_id_2) %>%
    dplyr::count(.data$cited_work_id, .data$cited_work_id_2, name = "weight") %>%
    dplyr::filter(.data$weight >= min_weight)

  if (nrow(pairs) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Build node table from paired works
  all_ids <- unique(c(pairs$cited_work_id, pairs$cited_work_id_2))
  nodes <- tibble::tibble(name = all_ids)
  nodes <- dplyr::left_join(nodes, works, by = c("name" = "work_id"))

  # Build edge list with integer indices
  node_idx <- stats::setNames(seq_along(nodes$name), nodes$name)
  edges <- tibble::tibble(
    from   = unname(node_idx[pairs$cited_work_id]),
    to     = unname(node_idx[pairs$cited_work_id_2]),
    weight = pairs$weight
  )

  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE)
}

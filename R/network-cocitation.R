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
#' @param linked_only Use only references with a `cited_work_id`. Defaults to
#'   `FALSE`, which includes cited items outside the corpus.
#' @param call Caller environment for error reporting.
#'
#' @return A [tidygraph::tbl_graph] object (undirected). Nodes carry `name`
#'   (work ID for corpus works, else DOI, OpenAlex id or original reference
#'   text), `in_corpus`, and columns from `corpus$works` (missing for external
#'   items). Edges carry a `weight` column representing co-citation frequency.
#'
#' @details
#' The algorithm:
#' 1. For every citing work, enumerate all pairs of cited works.
#' 2. Count how often each pair co-occurs.
#' 3. Filter by `min_weight`.
#' Each work counts a cited item once; self-references are excluded. Items
#' are keyed by `cited_work_id`, else normalised DOI, else OpenAlex id, else
#' upper-case reference text with whitespace squished and final periods
#' removed. Identifier kinds are kept separate, even when labels coincide.
#' `linked_only = TRUE` restores the earlier behaviour and warns when none
#' points to corpus works.
#'
#' Empty input (zero works, zero references, or no pairs above the threshold)
#' returns an empty undirected `tbl_graph`.
#'
#' @family networks
#' @seealso [sm_link_references()]
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' g <- sm_network_cocitation(corpus, min_weight = 2L)
#' g
sm_network_cocitation <- function(corpus,
                                  min_weight = 2L,
                                  linked_only = FALSE,
                                  call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  min_weight <- .check_positive_int(min_weight, call = call)
  .check_flag(linked_only, call = call)

  refs <- corpus$references
  works <- corpus$works

  # --- empty input guard ---
  if (nrow(works) == 0L || nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = character(), in_corpus = logical())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  if (linked_only && !any(refs$cited_work_id %in% works$work_id)) {
    .warn_references_unlinked(
      "References are present but none are linked to corpus works.", call = call
    )
  }
  keys <- .reference_keys(refs, works)
  refs$key <- keys$key
  refs$.self <- keys$.self
  if (linked_only) refs <- dplyr::filter(refs, !is.na(.data$cited_work_id))
  refs <- refs |>
    dplyr::filter(!is.na(.data$key), !.data$.self) |>
    dplyr::distinct(.data$work_id, .data$key)
  if (nrow(refs) == 0L) {
    nodes <- tibble::tibble(name = character(), in_corpus = logical())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # For each citing work, enumerate pairs of cited works
  pairs <- refs |>
    dplyr::inner_join(
      dplyr::select(refs, "work_id", key_2 = "key"),
      by = "work_id",
      relationship = "many-to-many"
    ) |>
    dplyr::filter(.data$key < .data$key_2) |>
    dplyr::count(.data$key, .data$key_2, name = "weight") |>
    dplyr::filter(.data$weight >= min_weight)

  if (nrow(pairs) == 0L) {
    nodes <- tibble::tibble(name = character(), in_corpus = logical())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Build node table from paired works
  all_keys <- unique(c(pairs$key, pairs$key_2))
  nodes <- keys[match(all_keys, keys$key), c("name", "in_corpus", ".work_id")]
  nodes <- dplyr::left_join(nodes, works, by = c(".work_id" = "work_id"),
                            na_matches = "never")
  nodes$.work_id <- NULL

  # Build edge list with integer indices
  node_idx <- stats::setNames(seq_along(all_keys), all_keys)
  edges <- tibble::tibble(
    from   = unname(node_idx[pairs$key]),
    to     = unname(node_idx[pairs$key_2]),
    weight = pairs$weight
  )

  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE)
}

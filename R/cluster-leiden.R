#' Leiden community detection
#'
#' @description
#' Clusters works using the Leiden community detection algorithm via
#' [igraph::cluster_leiden()]. If no network is provided, a semantic
#' similarity network is built automatically from embeddings.
#'
#' @param corpus An [sm_corpus] object.
#' @param network A [tidygraph::tbl_graph] or [igraph::igraph] object, or
#'   `NULL`. If `NULL` (default), a semantic similarity network is built
#'   via [sm_network_semantic()].
#' @param resolution Numeric; resolution parameter for the Leiden algorithm.
#'   Higher values produce more (smaller) clusters. Defaults to `1.0`.
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` with a `cluster_id` column added to
#'   `corpus$works`.
#'
#' @details
#' The Leiden algorithm (Traag et al., 2019) is a refinement of the Louvain
#' algorithm that guarantees well-connected communities. It operates on
#' the edge weights of the network.
#'
#' When `network = NULL`, embeddings must be present in the corpus so that
#' [sm_network_semantic()] can build a k-NN graph.
#'
#' @family clustering
#' @export
#' @examples
#' corpus <- sm_example_corpus(with_embeddings = TRUE)
#' corpus <- sm_cluster_leiden(corpus, resolution = 1.0)
#' table(corpus$works$cluster_id)
sm_cluster_leiden <- function(corpus,
                              network = NULL,
                              resolution = 1.0,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  if (!is.numeric(resolution) || length(resolution) != 1L || resolution <= 0) {
    cli::cli_abort(
      "{.arg resolution} must be a positive number.",
      call = call
    )
  }

  works <- corpus$works
  if (nrow(works) == 0L) {
    return(corpus)
  }

  # --- build or convert network ---
  if (is.null(network)) {
    .check_embeddings(corpus, call = call)
    network <- sm_network_semantic(corpus, k = 10L, call = call)
  }

  # Convert tbl_graph to igraph if needed
  if (inherits(network, "tbl_graph")) {
    g <- igraph::as.igraph(network)
  } else if (inherits(network, "igraph")) {
    g <- network
  } else {
    cli::cli_abort(
      "{.arg network} must be a {.cls tbl_graph} or {.cls igraph} object.",
      call = call
    )
  }

  if (igraph::vcount(g) == 0L) {
    return(corpus)
  }

  # Ensure weights exist; if not, set all to 1
  if (is.null(igraph::E(g)$weight)) {
    igraph::E(g)$weight <- 1
  }

  # --- Leiden clustering ---
  leiden_result <- igraph::cluster_leiden(
    g,
    objective_function = "modularity",
    resolution = resolution,
    weights = igraph::E(g)$weight
  )

  membership <- igraph::membership(leiden_result)
  node_names <- igraph::V(g)$name

  if (is.null(node_names)) {
    node_names <- as.character(seq_len(igraph::vcount(g)))
  }

  cluster_map <- tibble::tibble(
    work_id    = node_names,
    cluster_id = as.integer(membership)
  )

  # Merge into works
  if ("cluster_id" %in% names(corpus$works)) {
    corpus$works$cluster_id <- NULL
  }
  corpus$works <- dplyr::left_join(corpus$works, cluster_map, by = "work_id")

  n_clusters <- length(unique(cluster_map$cluster_id))
  cli::cli_inform(c(
    "v" = "Leiden clustering complete.",
    "i" = "{n_clusters} communit{?y/ies} found."
  ))

  corpus
}

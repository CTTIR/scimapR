#' Build a semantic similarity network
#'
#' @description
#' Constructs an undirected k-nearest-neighbour network based on work
#' embeddings. Each work is connected to its `k` nearest neighbours in
#' embedding space (cosine similarity). The edge weight is the cosine
#' similarity between the connected works.
#'
#' @param corpus An [sm_corpus] object. Must contain an `embeddings` matrix
#'   (see [sm_embed_works()]).
#' @param k Integer; number of nearest neighbours per work. Defaults to `10L`.
#' @param call Caller environment for error reporting.
#'
#' @return A [tidygraph::tbl_graph] object (undirected). Nodes carry `name`
#'   (work ID) and columns from `corpus$works`. Edges carry a `weight` column
#'   (cosine similarity, between 0 and 1).
#'
#' @details
#' Embeddings must be present in `corpus$embeddings` (a numeric matrix with
#' row names matching `work_id`). Use [sm_embed_works()] to compute them.
#'
#' The function computes cosine similarity via matrix multiplication on
#' L2-normalised vectors and selects the top-`k` neighbours for each work.
#'
#' Empty input or missing embeddings returns an empty undirected `tbl_graph`.
#'
#' @family networks
#' @export
#' @examples
#' corpus <- sm_example_corpus(with_embeddings = TRUE)
#' g <- sm_network_semantic(corpus, k = 5L)
#' g
sm_network_semantic <- function(corpus,
                                k = 10L,
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  k <- .check_positive_int(k, call = call)

  works <- corpus$works
  emb <- corpus$embeddings

  # --- empty input / missing embeddings guard ---
  if (nrow(works) == 0L || is.null(emb) || nrow(emb) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(),
                            weight = double())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  n <- nrow(emb)

  if (n < 2L) {
    nodes <- tibble::tibble(name = rownames(emb) %||% works$work_id[1])
    nodes <- dplyr::left_join(nodes, works, by = c("name" = "work_id"))
    edges <- tibble::tibble(from = integer(), to = integer(),
                            weight = double())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Clamp k to n - 1
  k_actual <- min(k, n - 1L)

  # L2-normalise rows for cosine similarity
  norms <- sqrt(rowSums(emb^2))
  norms[norms == 0] <- 1
  emb_norm <- emb / norms

  # Compute full cosine similarity matrix
  sim_mat <- tcrossprod(emb_norm)
  diag(sim_mat) <- -Inf

  # Find k-nearest neighbours per row
  nn_idx <- t(apply(sim_mat, 1, function(row) {
    order(row, decreasing = TRUE)[seq_len(k_actual)]
  }))
  nn_sim <- t(vapply(seq_len(n), function(i) {
    sim_mat[i, nn_idx[i, ]]
  }, double(k_actual)))

  # Build edge list (undirected: keep unique pairs)
  from_vec <- rep(seq_len(n), each = k_actual)
  to_vec <- as.vector(t(nn_idx))
  sim_vec <- as.vector(t(nn_sim))

  edge_df <- tibble::tibble(
    from   = from_vec,
    to     = to_vec,
    weight = sim_vec
  ) %>%
    dplyr::filter(.data$from != .data$to) %>%
    dplyr::mutate(
      a = pmin(.data$from, .data$to),
      b = pmax(.data$from, .data$to)
    ) %>%
    dplyr::group_by(.data$a, .data$b) %>%
    dplyr::summarise(weight = max(.data$weight), .groups = "drop") %>%
    dplyr::rename(from = "a", to = "b")

  # Build node table
  work_ids <- rownames(emb)
  if (is.null(work_ids)) {
    work_ids <- works$work_id[seq_len(n)]
  }
  nodes <- tibble::tibble(name = work_ids)
  nodes <- dplyr::left_join(nodes, works, by = c("name" = "work_id"))

  tidygraph::tbl_graph(nodes = nodes, edges = edge_df, directed = FALSE)
}

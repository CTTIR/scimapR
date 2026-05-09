#' HDBSCAN clustering of works
#'
#' @description
#' Clusters works using the HDBSCAN (Hierarchical Density-Based Spatial
#' Clustering of Applications with Noise) algorithm via [dbscan::hdbscan()].
#' Optionally reduces embedding dimensions first with UMAP or PCA.
#'
#' @param corpus An [sm_corpus] object with embeddings.
#' @param min_cluster_size Integer; minimum cluster size for HDBSCAN. Defaults
#'   to `15L`.
#' @param min_samples Integer or `NULL`; minimum number of samples in a
#'   neighbourhood for a point to be a core point. If `NULL` (default), set
#'   equal to `min_cluster_size`.
#' @param reducer Character; dimensionality reduction method to apply before
#'   clustering. One of `"umap"` (default), `"pca"`, or `"none"`.
#' @param n_components Integer; number of dimensions to reduce to. Defaults
#'   to `5L`.
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` with a `cluster_id` column added to
#'   `corpus$works`. Noise points (not assigned to any cluster) receive
#'   `cluster_id = 0L`.
#'
#' @details
#' Requires embeddings in `corpus$embeddings`. Compute them first with
#' [sm_embed_works()] or load from cache with [sm_embed_load()].
#'
#' The reducer step helps HDBSCAN work in a lower-dimensional space where
#' density estimation is more reliable.
#'
#' @family clustering
#' @export
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus(with_embeddings = TRUE)
#' corpus <- sm_cluster_hdbscan(corpus, min_cluster_size = 10L)
#' table(corpus$works$cluster_id)
#' }
sm_cluster_hdbscan <- function(corpus,
                               min_cluster_size = 15L,
                               min_samples = NULL,
                               reducer = c("umap", "pca", "none"),
                               n_components = 5L,
                               call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  rlang::check_installed("dbscan", reason = "for HDBSCAN clustering.")
  rlang::check_installed("uwot", reason = "for UMAP dimensionality reduction.")
  min_cluster_size <- .check_positive_int(min_cluster_size, call = call)
  reducer <- rlang::arg_match(reducer, error_call = call)
  n_components <- .check_positive_int(n_components, call = call)

  if (!is.null(min_samples)) {
    min_samples <- .check_positive_int(min_samples, call = call)
  } else {
    min_samples <- min_cluster_size
  }

  .check_embeddings(corpus, call = call)

  emb <- corpus$embeddings
  n <- nrow(emb)

  if (n == 0L) {
    return(corpus)
  }

  # --- dimensionality reduction ---
  reduced <- .reduce_dims(emb, reducer, n_components, call)

  # --- HDBSCAN ---
  # Ensure min_cluster_size is not larger than n

  mcs <- min(min_cluster_size, n)
  ms <- min(min_samples, n)

  hdb_result <- dbscan::hdbscan(reduced, minPts = mcs)

  cluster_ids <- as.integer(hdb_result$cluster)

  # Match embeddings rows to works
  emb_ids <- rownames(emb)
  if (is.null(emb_ids)) {
    emb_ids <- corpus$works$work_id[seq_len(n)]
  }

  cluster_map <- tibble::tibble(
    work_id    = emb_ids,
    cluster_id = cluster_ids
  )

  # Merge into works
  if ("cluster_id" %in% names(corpus$works)) {
    corpus$works$cluster_id <- NULL
  }
  corpus$works <- dplyr::left_join(corpus$works, cluster_map, by = "work_id")

  # Works without embeddings get NA cluster
  n_clusters <- length(unique(cluster_ids[cluster_ids > 0L]))
  n_noise <- sum(cluster_ids == 0L)
  cli::cli_inform(c(
    "v" = "HDBSCAN clustering complete.",
    "i" = "{n_clusters} cluster{?s} found, {n_noise} noise point{?s}."
  ))

  corpus
}


#' Validate that embeddings exist
#' @noRd
.check_embeddings <- function(corpus, call = rlang::caller_env()) {
  if (is.null(corpus$embeddings) || nrow(corpus$embeddings) == 0L) {
    cli::cli_abort(
      c("No embeddings found in the corpus.",
        "i" = "Compute embeddings first with {.fun sm_embed_works}.",
        "i" = "Or load cached embeddings with {.fun sm_embed_load}."),
      call = call
    )
  }
  invisible(corpus)
}


#' Reduce dimensions of an embedding matrix
#' @noRd
.reduce_dims <- function(emb, reducer, n_components, call) {
  n <- nrow(emb)
  d <- ncol(emb)

  # If already fewer dims than requested, skip

  if (d <= n_components || reducer == "none") {
    return(emb)
  }

  # Clamp n_components
  n_components <- min(n_components, d, n - 1L)

  if (reducer == "pca") {
    pca <- stats::prcomp(emb, center = TRUE, scale. = FALSE,
                         rank. = n_components)
    return(pca$x[, seq_len(n_components), drop = FALSE])
  }

  if (reducer == "umap") {
    # uwot::umap needs n_neighbors <= n - 1
    n_neighbors <- min(15L, n - 1L)
    if (n_neighbors < 2L) {
      # Too few points for UMAP, fall back to raw
      return(emb)
    }
    reduced <- uwot::umap(emb,
                           n_components = n_components,
                           n_neighbors = n_neighbors,
                           metric = "cosine",
                           n_threads = 1L,
                           verbose = FALSE)
    rownames(reduced) <- rownames(emb)
    return(reduced)
  }

  emb
}

#' K-means clustering of works
#'
#' @description
#' Clusters works using K-means clustering via [stats::kmeans()]. Optionally
#' reduces embedding dimensions first with UMAP or PCA.
#'
#' @param corpus An [sm_corpus] object with embeddings.
#' @param k Integer; the number of clusters. Required.
#' @param reducer Character; dimensionality reduction method to apply before
#'   clustering. One of `"umap"` (default), `"pca"`, or `"none"`.
#' @param n_components Integer; number of dimensions to reduce to. Defaults
#'   to `5L`.
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` with a `cluster_id` column added to
#'   `corpus$works`.
#'
#' @details
#' Requires embeddings in `corpus$embeddings`. Compute them first with
#' [sm_embed_works()] or load from cache with [sm_embed_load()].
#'
#' K-means is deterministic given a fixed random seed. Consider setting a seed
#' before calling this function for reproducibility.
#'
#' @family clustering
#' @export
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus(with_embeddings = TRUE)
#' corpus <- sm_cluster_kmeans(corpus, k = 5)
#' table(corpus$works$cluster_id)
#' }
sm_cluster_kmeans <- function(corpus,
                              k,
                              reducer = c("umap", "pca", "none"),
                              n_components = 5L,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  k <- .check_positive_int(k, call = call)
  reducer <- rlang::arg_match(reducer, error_call = call)
  n_components <- .check_positive_int(n_components, call = call)

  .check_embeddings(corpus, call = call)

  emb <- corpus$embeddings
  n <- nrow(emb)

  if (n == 0L) {
    return(corpus)
  }

  # Clamp k to number of works
  k_actual <- min(k, n)
  if (k_actual < k) {
    cli::cli_inform(c(
      "!" = "Requested {k} clusters but only {n} work{?s} available.",
      "i" = "Using k = {k_actual}."
    ))
  }

  # --- dimensionality reduction ---
  reduced <- .reduce_dims(emb, reducer, n_components, call)

  # --- K-means ---
  km_result <- stats::kmeans(reduced, centers = k_actual, nstart = 25L,
                             iter.max = 100L)

  cluster_ids <- as.integer(km_result$cluster)

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

  # Summary
  sizes <- table(cluster_ids)
  cli::cli_inform(c(
    "v" = "K-means clustering complete.",
    "i" = "{k_actual} cluster{?s}, sizes range from {min(sizes)} to {max(sizes)}."
  ))

  corpus
}

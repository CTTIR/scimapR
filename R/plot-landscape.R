#' Plot research landscape
#'
#' @description
#' UMAP/t-SNE/PCA scatter plot of work embeddings, coloured by cluster.
#'
#' @param corpus An `sm_corpus` with embeddings.
#' @param color_by Column name in works to colour by. Default `"cluster_id"`.
#' @param reducer Dimensionality reduction method.
#' @param n_components Number of output dimensions (2 for plotting).
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus()
#' corpus <- sm_cluster_hdbscan(corpus, min_cluster_size = 10)
#' sm_plot_landscape(corpus)
#' }
sm_plot_landscape <- function(corpus,
                              color_by = "cluster_id",
                              reducer = c("umap", "tsne", "pca"),
                              n_components = 2L,
                              dark = FALSE, ...) {
  .check_sm_corpus(corpus)
  reducer <- match.arg(reducer)
  if (reducer == "umap") {
    rlang::check_installed("uwot", reason = "for UMAP reduction.")
  }

  if (is.null(corpus$embeddings) || nrow(corpus$embeddings) == 0) {
    cli::cli_abort("Corpus has no embeddings. Run {.fn sm_embed_works} first.")
  }

  emb <- corpus$embeddings
  n <- nrow(emb)

  coords <- switch(reducer,
    umap = {
      n_neighbors <- min(15L, n - 1L)
      if (n_neighbors < 2) {
        cli::cli_abort("Need at least 3 works for UMAP.")
      }
      uwot::umap(emb, n_components = n_components,
                  n_neighbors = n_neighbors, verbose = FALSE)
    },
    pca = {
      pc <- stats::prcomp(emb, center = TRUE, scale. = FALSE)
      pc$x[, seq_len(min(n_components, ncol(pc$x))), drop = FALSE]
    },
    tsne = {
      rlang::check_installed("Rtsne", reason = "for t-SNE reduction")
      perp <- min(30, floor((n - 1) / 3))
      if (perp < 1) {
        cli::cli_abort("Need more works for t-SNE.")
      }
      tsne_out <- Rtsne::Rtsne(emb, dims = n_components,
                                perplexity = perp, verbose = FALSE)
      tsne_out$Y
    }
  )

  work_ids <- rownames(emb)
  plot_df <- tibble::tibble(
    x = coords[, 1],
    y = coords[, 2],
    work_id = work_ids
  )

  plot_df <- dplyr::left_join(plot_df, corpus$works, by = "work_id")

  if (color_by %in% names(plot_df) && !all(is.na(plot_df[[color_by]]))) {
    plot_df$color_var <- as.factor(plot_df[[color_by]])
    p <- ggplot2::ggplot(plot_df,
      ggplot2::aes(x = .data$x, y = .data$y, colour = .data$color_var)
    ) +
      ggplot2::geom_point(alpha = 0.7, size = 1.5) +
      sm_scale_color(discrete = TRUE)
  } else {
    p <- ggplot2::ggplot(plot_df,
      ggplot2::aes(x = .data$x, y = .data$y)
    ) +
      ggplot2::geom_point(alpha = 0.7, size = 1.5,
                          colour = viridisLite::viridis(1))
  }

  p + sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Research Landscape",
      x = paste0(toupper(reducer), " 1"),
      y = paste0(toupper(reducer), " 2"),
      colour = color_by
    )
}

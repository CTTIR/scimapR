# Tests for R/plot-landscape.R (sm_plot_landscape) -- pure ggplot.

test_that("sm_plot_landscape rejects a non-corpus input", {
  expect_error(sm_plot_landscape(list()), class = "error")
})

test_that("validates the reducer argument", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = TRUE, seed = 1)
  expect_error(sm_plot_landscape(corpus, reducer = "magic"),
               class = "error")
})

test_that("errors when corpus has no embeddings", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 2)
  expect_error(sm_plot_landscape(corpus, reducer = "pca"),
               "no embeddings")
})

test_that("errors cleanly when uwot is missing for umap", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = TRUE, seed = 3)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      stop(structure(
        class = c("rlang_error", "error", "condition"),
        list(message = "uwot not installed", call = NULL)
      ))
    },
    .package = "rlang"
  )
  expect_error(sm_plot_landscape(corpus, reducer = "umap"))
})

test_that("pca reducer returns a ggplot with a point layer", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = TRUE, seed = 4)
  p <- sm_plot_landscape(corpus, reducer = "pca")
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
  expect_equal(p$labels$title, "Research Landscape")
  expect_equal(p$labels$x, "PCA 1")
  expect_equal(p$labels$y, "PCA 2")
})

test_that("falls back to uncoloured plot when color_by is absent", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = TRUE, seed = 5)
  p <- sm_plot_landscape(corpus, color_by = "nonexistent_column",
                         reducer = "pca")
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
})

test_that("colours by an existing cluster column", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = TRUE, seed = 6)
  corpus <- sm_cluster_kmeans(corpus, k = 5, reducer = "pca")
  p <- sm_plot_landscape(corpus, color_by = "cluster_id", reducer = "pca")
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$colour, "cluster_id")
})

test_that("dark mode renders a ggplot", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = TRUE, seed = 7)
  p <- sm_plot_landscape(corpus, reducer = "pca", dark = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("the landscape shows the works that have an embedding row", {
  # a partial matrix, as sm_embed_works() leaves for works without text
  corpus <- sm_example_corpus(n_works = 40, n_authors = 10,
                              with_embeddings = TRUE, seed = 7)
  corpus$embeddings <- corpus$embeddings[-(1:4), , drop = FALSE]
  p <- sm_plot_landscape(corpus, reducer = "pca")
  expect_identical(sort(p$data$work_id), sort(corpus$works$work_id[-(1:4)]))
})

test_that("landscape UMAP recovers from the older-R PCA error without changing its metric", {
  skip_if_not_installed("uwot")
  skip_if_not_installed("irlba")
  reduce <- uwot::umap
  calls <- list()
  local_mocked_bindings(umap = function(...) {
    calls[[length(calls) + 1L]] <<- list(...)
    reduce(..., init = "pca")
  }, .package = "uwot")
  original <- get("oknum", asNamespace("irlba"))
  local_mocked_bindings(oknum = function(x) {
    if (is.null(x)) {
      stop(simpleError("LENGTH or similar applied to NULL object",
                       call = quote(oknum(scale))))
    }
    original(x)
  }, .package = "irlba")
  corpus <- sm_example_corpus(n_works = 30, seed = 10)
  expect_message(plot <- sm_plot_landscape(corpus),
                 class = "scimapR_umap_pca_fallback")
  expect_s3_class(plot, "ggplot")
  expect_setequal(plot$data$work_id, corpus$works$work_id)
  expect_true(all(is.finite(plot$data$x) & is.finite(plot$data$y)))
  expect_length(calls, 2L)
  expect_identical(calls[[1L]]$metric, "euclidean")
  expect_null(calls[[1L]]$n_threads)
  expect_null(calls[[1L]]$pca_method)
  expect_identical(calls[[2L]]$metric, "euclidean")
  expect_identical(calls[[2L]]$pca_method, "svd")
})

test_that("landscape UMAP preserves unrelated dependency errors", {
  skip_if_not_installed("uwot")
  local_mocked_bindings(umap = function(...) stop("unrelated landscape failure"),
                        .package = "uwot")
  corpus <- sm_example_corpus(n_works = 30)
  expect_error(sm_plot_landscape(corpus), "unrelated landscape failure")
})

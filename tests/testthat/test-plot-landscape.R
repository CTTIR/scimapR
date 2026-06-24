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

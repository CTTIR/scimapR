# Tests for R/plot-thematic-map.R (sm_plot_thematic_map) -- pure ggplot.

test_that("sm_plot_thematic_map rejects a non-corpus input", {
  skip_if_not_installed("ggrepel")
  expect_error(sm_plot_thematic_map(list()), class = "rlang_error")
})

test_that("errors cleanly when ggrepel is missing", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = TRUE, seed = 1)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      stop(structure(
        class = c("rlang_error", "error", "condition"),
        list(message = "ggrepel not installed", call = NULL)
      ))
    },
    .package = "rlang"
  )
  expect_error(sm_plot_thematic_map(corpus))
})

test_that("errors when the grouping column is absent", {
  skip_if_not_installed("ggrepel")
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = TRUE, seed = 2)
  # No cluster_id column present by default.
  expect_error(sm_plot_thematic_map(corpus, by = "cluster_id"),
               "not found")
})

test_that("returns a ggplot with layers when clusters exist", {
  skip_if_not_installed("ggrepel")
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = TRUE, seed = 3)
  corpus <- sm_cluster_kmeans(corpus, k = 5, reducer = "pca")
  p <- sm_plot_thematic_map(corpus)
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
  expect_equal(p$labels$title, "Thematic Map (Strategic Diagram)")
})

test_that("dark mode renders a ggplot", {
  skip_if_not_installed("ggrepel")
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = TRUE, seed = 4)
  corpus <- sm_cluster_kmeans(corpus, k = 5, reducer = "pca")
  p <- sm_plot_thematic_map(corpus, dark = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("returns 'No cluster data' plot when all cluster values are NA", {
  skip_if_not_installed("ggrepel")
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = TRUE, seed = 5)
  corpus$works$cluster_id <- NA_integer_
  p <- sm_plot_thematic_map(corpus, by = "cluster_id")
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "No cluster data")
})

# Tests for sm_plot_evolution() in R/plot-evolution.R (pure ggplot).

test_that("sm_plot_evolution validates corpus class", {
  expect_error(sm_plot_evolution(list()), class = "rlang_error")
})

test_that("sm_plot_evolution errors when cluster_id is missing", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = FALSE, seed = 1)
  expect_false("cluster_id" %in% names(corpus$works))
  expect_error(sm_plot_evolution(corpus), "cluster_id")
})

test_that("sm_plot_evolution returns a ggplot with cluster data", {
  corpus <- sm_example_corpus(n_works = 60, with_embeddings = TRUE, seed = 7)
  corpus <- sm_cluster_kmeans(corpus, k = 4, reducer = "pca")
  expect_true("cluster_id" %in% names(corpus$works))

  p <- sm_plot_evolution(corpus)
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "Topic Evolution")
  expect_equal(p$labels$y, "Number of Works")
  # one geom_area layer present
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomArea" %in% geoms)
})

test_that("sm_plot_evolution returns placeholder when no evolution data", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = TRUE, seed = 3)
  corpus <- sm_cluster_kmeans(corpus, k = 2, reducer = "pca")
  # wipe years so the filtered evolution table is empty
  corpus$works$year <- NA_integer_

  p <- sm_plot_evolution(corpus)
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "No cluster evolution data")
})

test_that("sm_plot_evolution honours dark mode", {
  corpus <- sm_example_corpus(n_works = 40, with_embeddings = TRUE, seed = 9)
  corpus <- sm_cluster_kmeans(corpus, k = 3, reducer = "pca")
  p <- sm_plot_evolution(corpus, dark = TRUE)
  expect_s3_class(p, "ggplot")
})

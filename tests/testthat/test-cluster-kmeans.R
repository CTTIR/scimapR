test_that("sm_cluster_kmeans rejects non-corpus input", {
  expect_error(sm_cluster_kmeans(list(a = 1), k = 3), "sm_corpus")
})

test_that("sm_cluster_kmeans validates k and n_components", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 1)
  expect_error(sm_cluster_kmeans(corpus, k = 0), "positive integer")
  expect_error(sm_cluster_kmeans(corpus, k = -1), "positive integer")
  expect_error(sm_cluster_kmeans(corpus, k = 3, n_components = 0),
               "positive integer")
})

test_that("sm_cluster_kmeans validates reducer argument", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 2)
  expect_error(sm_cluster_kmeans(corpus, k = 3, reducer = "bogus"))
})

test_that("sm_cluster_kmeans aborts without embeddings", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = FALSE, seed = 3)
  expect_error(sm_cluster_kmeans(corpus, k = 3), "No embeddings")
})

test_that("sm_cluster_kmeans assigns one cluster per work (pca)", {
  corpus <- sm_example_corpus(n_works = 60, n_clusters = 4,
                              with_embeddings = TRUE, seed = 4)
  set.seed(1)
  out <- suppressMessages(sm_cluster_kmeans(corpus, k = 4, reducer = "pca"))
  expect_s3_class(out, "sm_corpus")
  expect_true("cluster_id" %in% names(out$works))
  expect_equal(nrow(out$works), nrow(corpus$works))
  expect_false(any(is.na(out$works$cluster_id)))
  expect_equal(sort(unique(out$works$cluster_id)), 1:4)
})

test_that("sm_cluster_kmeans works with reducer = none", {
  corpus <- sm_example_corpus(n_works = 50, n_clusters = 3,
                              with_embeddings = TRUE, seed = 5)
  set.seed(1)
  out <- suppressMessages(sm_cluster_kmeans(corpus, k = 3, reducer = "none"))
  expect_equal(length(unique(out$works$cluster_id)), 3L)
})

test_that("sm_cluster_kmeans works with reducer = umap", {
  corpus <- sm_example_corpus(n_works = 60, n_clusters = 4,
                              with_embeddings = TRUE, seed = 6)
  set.seed(1)
  out <- suppressMessages(sm_cluster_kmeans(corpus, k = 4, reducer = "umap"))
  expect_true("cluster_id" %in% names(out$works))
  expect_false(any(is.na(out$works$cluster_id)))
})

test_that("sm_cluster_kmeans warns when k exceeds number of works", {
  corpus <- sm_example_corpus(n_works = 30, n_clusters = 3,
                              with_embeddings = TRUE, seed = 7)
  set.seed(1)
  # The clamp emits an informative message about reducing k.
  expect_message(
    try(sm_cluster_kmeans(corpus, k = 50, reducer = "none"), silent = TRUE),
    "only 30"
  )
  # NOTE (source behaviour): k is clamped to min(k, n), but when k > n the
  # clamped value equals n and stats::kmeans() rejects centers == nrow(x),
  # so the clamp branch ultimately errors rather than producing a result.
  expect_error(
    suppressMessages(sm_cluster_kmeans(corpus, k = 50, reducer = "none")),
    "cluster centres"
  )
})

test_that("sm_cluster_kmeans accepts k just below n", {
  corpus <- sm_example_corpus(n_works = 30, n_clusters = 3,
                              with_embeddings = TRUE, seed = 10)
  set.seed(1)
  out <- suppressMessages(sm_cluster_kmeans(corpus, k = 6, reducer = "none"))
  expect_equal(length(unique(out$works$cluster_id)), 6L)
})

test_that("sm_cluster_kmeans replaces an existing cluster_id column", {
  corpus <- sm_example_corpus(n_works = 40, n_clusters = 3,
                              with_embeddings = TRUE, seed = 8)
  set.seed(1)
  out1 <- suppressMessages(sm_cluster_kmeans(corpus, k = 3, reducer = "pca"))
  set.seed(2)
  out2 <- suppressMessages(sm_cluster_kmeans(out1, k = 4, reducer = "pca"))
  # Only one cluster_id column should remain
  expect_equal(sum(names(out2$works) == "cluster_id"), 1L)
  expect_equal(length(unique(out2$works$cluster_id)), 4L)
})

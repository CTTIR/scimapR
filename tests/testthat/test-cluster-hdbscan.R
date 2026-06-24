test_that("sm_cluster_hdbscan rejects non-corpus input", {
  expect_error(sm_cluster_hdbscan(list(a = 1)), "sm_corpus")
})

test_that("sm_cluster_hdbscan errors when dbscan is not installed", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 1)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "dbscan") stop("dbscan not installed")
      invisible(NULL)
    },
    .package = "rlang"
  )
  expect_error(sm_cluster_hdbscan(corpus), "dbscan")
})

test_that("sm_cluster_hdbscan errors when uwot is not installed", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 2)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "uwot") stop("uwot not installed")
      invisible(NULL)
    },
    .package = "rlang"
  )
  expect_error(sm_cluster_hdbscan(corpus), "uwot")
})

test_that("sm_cluster_hdbscan validates min_cluster_size and reducer", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 3)
  expect_error(sm_cluster_hdbscan(corpus, min_cluster_size = 0),
               "positive integer")
  expect_error(sm_cluster_hdbscan(corpus, reducer = "bogus"))
  expect_error(sm_cluster_hdbscan(corpus, min_samples = 0), "positive integer")
})

test_that("sm_cluster_hdbscan aborts without embeddings", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = FALSE, seed = 4)
  expect_error(sm_cluster_hdbscan(corpus), "No embeddings")
})

test_that("sm_cluster_hdbscan assigns cluster_id for all works (pca)", {
  corpus <- sm_example_corpus(n_works = 80, n_clusters = 4,
                              with_embeddings = TRUE, seed = 5)
  out <- suppressMessages(
    sm_cluster_hdbscan(corpus, min_cluster_size = 10L, reducer = "pca")
  )
  expect_s3_class(out, "sm_corpus")
  expect_true("cluster_id" %in% names(out$works))
  expect_equal(nrow(out$works), nrow(corpus$works))
  expect_false(any(is.na(out$works$cluster_id)))
  # Noise points are coded as 0; cluster ids are non-negative integers
  expect_true(all(out$works$cluster_id >= 0L))
})

test_that("sm_cluster_hdbscan works with reducer = umap", {
  corpus <- sm_example_corpus(n_works = 80, n_clusters = 4,
                              with_embeddings = TRUE, seed = 6)
  out <- suppressMessages(
    sm_cluster_hdbscan(corpus, min_cluster_size = 10L, reducer = "umap")
  )
  expect_true("cluster_id" %in% names(out$works))
  expect_false(any(is.na(out$works$cluster_id)))
})

test_that("sm_cluster_hdbscan works with reducer = none", {
  corpus <- sm_example_corpus(n_works = 60, n_clusters = 3,
                              with_embeddings = TRUE, seed = 7)
  out <- suppressMessages(
    sm_cluster_hdbscan(corpus, min_cluster_size = 8L, reducer = "none")
  )
  expect_true("cluster_id" %in% names(out$works))
})

test_that("sm_cluster_hdbscan uses default min_samples = min_cluster_size", {
  corpus <- sm_example_corpus(n_works = 50, n_clusters = 3,
                              with_embeddings = TRUE, seed = 8)
  out <- suppressMessages(
    sm_cluster_hdbscan(corpus, min_cluster_size = 10L,
                       min_samples = NULL, reducer = "pca")
  )
  expect_true("cluster_id" %in% names(out$works))
})

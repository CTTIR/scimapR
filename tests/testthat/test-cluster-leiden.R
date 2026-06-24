test_that("sm_cluster_leiden rejects non-corpus input", {
  expect_error(sm_cluster_leiden(list(a = 1)), "sm_corpus")
})

test_that("sm_cluster_leiden errors when igraph is not installed", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 1)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "igraph") stop("igraph not installed")
      invisible(NULL)
    },
    .package = "rlang"
  )
  expect_error(sm_cluster_leiden(corpus), "igraph")
})

test_that("sm_cluster_leiden validates resolution", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 2)
  expect_error(sm_cluster_leiden(corpus, resolution = 0), "positive number")
  expect_error(sm_cluster_leiden(corpus, resolution = -1), "positive number")
  expect_error(sm_cluster_leiden(corpus, resolution = c(1, 2)),
               "positive number")
})

test_that("sm_cluster_leiden aborts without embeddings when network is NULL", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = FALSE, seed = 3)
  expect_error(sm_cluster_leiden(corpus), "No embeddings")
})

test_that("sm_cluster_leiden assigns cluster_id from auto-built network", {
  corpus <- sm_example_corpus(n_works = 60, n_clusters = 4,
                              with_embeddings = TRUE, seed = 4)
  out <- suppressMessages(sm_cluster_leiden(corpus, resolution = 1.0))
  expect_s3_class(out, "sm_corpus")
  expect_true("cluster_id" %in% names(out$works))
  expect_equal(nrow(out$works), nrow(corpus$works))
  expect_false(any(is.na(out$works$cluster_id)))
  expect_true(all(out$works$cluster_id >= 1L))
})

test_that("sm_cluster_leiden accepts a precomputed tbl_graph network", {
  corpus <- sm_example_corpus(n_works = 50, n_clusters = 3,
                              with_embeddings = TRUE, seed = 5)
  net <- sm_network_semantic(corpus, k = 8L)
  out <- suppressMessages(sm_cluster_leiden(corpus, network = net))
  expect_true("cluster_id" %in% names(out$works))
  expect_false(any(is.na(out$works$cluster_id)))
})

test_that("sm_cluster_leiden accepts an igraph network directly", {
  corpus <- sm_example_corpus(n_works = 40, n_clusters = 3,
                              with_embeddings = TRUE, seed = 6)
  net <- sm_network_semantic(corpus, k = 6L)
  g <- igraph::as.igraph(net)
  out <- suppressMessages(sm_cluster_leiden(corpus, network = g))
  expect_true("cluster_id" %in% names(out$works))
})

test_that("sm_cluster_leiden errors on invalid network class", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = TRUE, seed = 7)
  expect_error(
    sm_cluster_leiden(corpus, network = data.frame(a = 1)),
    "tbl_graph"
  )
})

test_that("sm_cluster_leiden higher resolution gives >= clusters", {
  corpus <- sm_example_corpus(n_works = 80, n_clusters = 5,
                              with_embeddings = TRUE, seed = 8)
  out_lo <- suppressMessages(sm_cluster_leiden(corpus, resolution = 0.5))
  out_hi <- suppressMessages(sm_cluster_leiden(corpus, resolution = 3.0))
  n_lo <- length(unique(out_lo$works$cluster_id))
  n_hi <- length(unique(out_hi$works$cluster_id))
  expect_gte(n_hi, n_lo)
})

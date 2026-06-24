# Build a small clustered corpus for labelling tests.
make_clustered_corpus <- function(n = 60, k = 3, seed = 1) {
  corpus <- sm_example_corpus(n_works = n, n_clusters = k,
                              with_embeddings = TRUE, seed = seed)
  set.seed(seed)
  suppressMessages(sm_cluster_kmeans(corpus, k = k, reducer = "pca"))
}

test_that("sm_cluster_label rejects non-corpus input", {
  expect_error(sm_cluster_label(list(a = 1)), "sm_corpus")
})

test_that("sm_cluster_label validates method and n_terms", {
  corpus <- make_clustered_corpus()
  expect_error(sm_cluster_label(corpus, method = "bogus"))
  expect_error(sm_cluster_label(corpus, n_terms = 0), "positive integer")
})

test_that("sm_cluster_label errors when no cluster_id column", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = TRUE, seed = 2)
  expect_error(sm_cluster_label(corpus, method = "tfidf"), "cluster_id")
})

test_that("sm_cluster_label tfidf errors when tidytext missing", {
  corpus <- make_clustered_corpus()
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "tidytext") stop("tidytext not installed")
      invisible(NULL)
    },
    .package = "rlang"
  )
  expect_error(sm_cluster_label(corpus, method = "tfidf"), "tidytext")
})

test_that("sm_cluster_label tfidf adds cluster_label column", {
  corpus <- make_clustered_corpus(seed = 3)
  out <- suppressMessages(
    sm_cluster_label(corpus, method = "tfidf", n_terms = 3L)
  )
  expect_s3_class(out, "sm_corpus")
  expect_true("cluster_label" %in% names(out$works))
  expect_equal(nrow(out$works), nrow(corpus$works))
  # Each labelled work has a non-empty label string
  labelled <- out$works$cluster_label[!is.na(out$works$cluster_id)]
  expect_true(all(nchar(labelled) > 0L))
  # Labels are constant within a cluster
  agg <- tapply(out$works$cluster_label, out$works$cluster_id,
                function(x) length(unique(x)))
  expect_true(all(agg == 1L))
})

test_that("sm_cluster_label yake adds cluster_label column", {
  corpus <- make_clustered_corpus(seed = 4)
  out <- suppressMessages(
    sm_cluster_label(corpus, method = "yake", n_terms = 4L)
  )
  expect_true("cluster_label" %in% names(out$works))
  labelled <- out$works$cluster_label[!is.na(out$works$cluster_id)]
  expect_true(all(nchar(labelled) > 0L))
})

test_that("sm_cluster_label replaces an existing cluster_label column", {
  corpus <- make_clustered_corpus(seed = 5)
  out1 <- suppressMessages(sm_cluster_label(corpus, method = "tfidf"))
  out2 <- suppressMessages(sm_cluster_label(out1, method = "yake"))
  expect_equal(sum(names(out2$works) == "cluster_label"), 1L)
})

test_that("sm_cluster_label llm requires a provider", {
  corpus <- make_clustered_corpus(seed = 6)
  expect_error(
    sm_cluster_label(corpus, method = "llm", llm_provider = NULL),
    "llm_provider"
  )
})

test_that("sm_cluster_label llm uses a mocked provider", {
  corpus <- make_clustered_corpus(seed = 7)
  fake_provider <- list(
    chat = function(user_prompt, system_prompt = NULL) "Mocked Topic Label"
  )
  out <- suppressMessages(
    sm_cluster_label(corpus, method = "llm", llm_provider = fake_provider)
  )
  expect_true("cluster_label" %in% names(out$works))
  labels <- unique(out$works$cluster_label[!is.na(out$works$cluster_id)])
  expect_true("Mocked Topic Label" %in% labels)
})

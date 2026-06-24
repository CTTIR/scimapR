# Tests for R/network-coword.R (sm_network_coword) -- pure logic, no network.

test_that("sm_network_coword rejects a non-corpus input", {
  expect_error(sm_network_coword(list()), class = "rlang_error")
})

test_that("sm_network_coword validates field, ngram and min_freq", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_network_coword(corpus, field = "bogus"),
               class = "rlang_error")
  expect_error(sm_network_coword(corpus, ngram = 0L),
               "positive integer")
  expect_error(sm_network_coword(corpus, min_freq = -1L),
               "positive integer")
})

test_that("concepts field builds an undirected tbl_graph with name and freq", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 20,
                              with_embeddings = FALSE, seed = 5)
  g <- sm_network_coword(corpus, field = "concepts", min_freq = 3L)

  expect_s3_class(g, "tbl_graph")
  expect_false(igraph::is_directed(g))

  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(g, "edges"))
  expect_true(all(c("name", "freq") %in% names(nodes)))
  expect_true("weight" %in% names(edges))
  expect_gt(nrow(nodes), 0L)
  expect_gt(nrow(edges), 0L)
  # Every node must meet the min_freq threshold.
  expect_true(all(nodes$freq >= 3L))
  # Edge endpoints index valid nodes.
  expect_true(all(edges$from >= 1L & edges$from <= nrow(nodes)))
  expect_true(all(edges$to >= 1L & edges$to <= nrow(nodes)))
})

test_that("higher min_freq yields a smaller-or-equal network", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 20,
                              with_embeddings = FALSE, seed = 5)
  g_low <- sm_network_coword(corpus, field = "concepts", min_freq = 2L)
  g_high <- sm_network_coword(corpus, field = "concepts", min_freq = 10L)
  n_low <- nrow(tibble::as_tibble(tidygraph::activate(g_low, "nodes")))
  n_high <- nrow(tibble::as_tibble(tidygraph::activate(g_high, "nodes")))
  expect_gte(n_low, n_high)
})

test_that("empty corpus returns an empty undirected graph", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  g <- sm_network_coword(empty, field = "concepts")
  expect_s3_class(g, "tbl_graph")
  expect_false(igraph::is_directed(g))
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("impossibly high min_freq returns an empty node set", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 2)
  g <- sm_network_coword(corpus, field = "concepts", min_freq = 100000L)
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("title field tokenises free text into a graph", {
  skip_if_not_installed("tidytext")
  corpus <- sm_example_corpus(n_works = 80, n_authors = 20,
                              with_embeddings = FALSE, seed = 8)
  g <- sm_network_coword(corpus, field = "title", min_freq = 5L)
  expect_s3_class(g, "tbl_graph")
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  # Stopwords like "in" / "a" should not survive tokenisation.
  expect_false("in" %in% nodes$name)
  expect_false("a" %in% nodes$name)
})

test_that("custom stopwords are removed from free-text fields", {
  skip_if_not_installed("tidytext")
  corpus <- sm_example_corpus(n_works = 80, n_authors = 20,
                              with_embeddings = FALSE, seed = 8)
  g <- sm_network_coword(corpus, field = "title", min_freq = 5L,
                         stopwords = c("cancer"))
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  expect_false("cancer" %in% nodes$name)
})

test_that("keywords field with no keyword-vocab concepts returns empty graph", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 4)
  # Example concepts use vocabulary "openalex", never "keyword".
  g <- sm_network_coword(corpus, field = "keywords", min_freq = 1L)
  expect_s3_class(g, "tbl_graph")
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

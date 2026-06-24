# Tests for R/network-coupling.R (sm_network_coupling) -- pure tidygraph.

test_that("sm_network_coupling rejects a non-corpus input", {
  expect_error(sm_network_coupling(list()), class = "rlang_error")
})

test_that("sm_network_coupling validates min_shared", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_network_coupling(corpus, min_shared = 0L),
               "positive integer")
})

test_that("coupling network is undirected tbl_graph with weights", {
  corpus <- sm_example_corpus(n_works = 120, n_authors = 30,
                              with_embeddings = FALSE, seed = 2)
  g <- sm_network_coupling(corpus, min_shared = 1L)
  expect_s3_class(g, "tbl_graph")
  expect_false(igraph::is_directed(g))
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(g, "edges"))
  expect_true("name" %in% names(nodes))
  expect_true("weight" %in% names(edges))
  expect_true(all(edges$weight >= 1L))
  expect_true(all(edges$from >= 1L & edges$from <= nrow(nodes)))
  expect_true(all(edges$to >= 1L & edges$to <= nrow(nodes)))
})

test_that("higher min_shared yields a smaller-or-equal edge set", {
  corpus <- sm_example_corpus(n_works = 120, n_authors = 30,
                              with_embeddings = FALSE, seed = 3)
  g_low <- sm_network_coupling(corpus, min_shared = 1L)
  g_high <- sm_network_coupling(corpus, min_shared = 4L)
  e_low <- nrow(tibble::as_tibble(tidygraph::activate(g_low, "edges")))
  e_high <- nrow(tibble::as_tibble(tidygraph::activate(g_high, "edges")))
  expect_gte(e_low, e_high)
})

test_that("empty corpus returns an empty undirected graph", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  g <- sm_network_coupling(empty)
  expect_s3_class(g, "tbl_graph")
  expect_false(igraph::is_directed(g))
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("no linked references returns empty graph", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 4)
  corpus$references$cited_work_id <- NA_character_
  g <- sm_network_coupling(corpus, min_shared = 1L)
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("impossibly high min_shared returns empty graph", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 5)
  g <- sm_network_coupling(corpus, min_shared = 100000L)
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

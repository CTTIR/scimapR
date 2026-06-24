# Tests for R/network-citation.R (sm_network_citation) -- pure tidygraph.

test_that("sm_network_citation rejects a non-corpus input", {
  expect_error(sm_network_citation(list()), class = "rlang_error")
})

test_that("citation network is a directed tbl_graph", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = FALSE, seed = 2)
  g <- sm_network_citation(corpus)
  expect_s3_class(g, "tbl_graph")
  expect_true(igraph::is_directed(g))
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(g, "edges"))
  expect_true("name" %in% names(nodes))
  expect_true(all(c("from", "to") %in% names(edges)))
  expect_gt(nrow(nodes), 0L)
  expect_gt(nrow(edges), 0L)
  expect_true(all(edges$from >= 1L & edges$from <= nrow(nodes)))
  expect_true(all(edges$to >= 1L & edges$to <= nrow(nodes)))
})

test_that("empty corpus returns an empty directed graph", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  g <- sm_network_citation(empty)
  expect_s3_class(g, "tbl_graph")
  expect_true(igraph::is_directed(g))
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("references present but unlinked returns work nodes, zero edges", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 3)
  corpus$references$cited_work_id <- NA_character_
  g <- sm_network_citation(corpus)
  expect_s3_class(g, "tbl_graph")
  expect_true(igraph::is_directed(g))
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(g, "edges"))
  expect_equal(nrow(nodes), nrow(corpus$works))
  expect_equal(nrow(edges), 0L)
})

test_that("node metadata is joined from works", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 4)
  g <- sm_network_citation(corpus)
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  # works columns such as title/year should be present on nodes
  expect_true("title" %in% names(nodes) || "year" %in% names(nodes))
})

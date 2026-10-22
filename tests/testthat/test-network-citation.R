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
  expect_warning(g <- sm_network_citation(corpus),
                 class = "scimapR_references_unlinked")
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


test_that("citation networks use reader links and drop repeated self-loops", {
  x <- sm_read_wos(test_path("fixtures", "link-wos-two.txt"), verbose = FALSE)
  expect_equal(reference_edges(sm_network_citation(x), directed = TRUE),
               tibble::tibble(from = x$works$work_id[2],
                              to = x$works$work_id[1], weight = 1L))
  x$references <- tibble::tibble(work_id = "A",
                                 cited_work_id = c("B", "B", "A"))
  x$works <- tibble::tibble(work_id = c("A", "B"))
  expect_equal(reference_edges(sm_network_citation(x), directed = TRUE),
               tibble::tibble(from = "A", to = "B", weight = 1L))
})

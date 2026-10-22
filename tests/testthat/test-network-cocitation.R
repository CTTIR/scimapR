# Tests for R/network-cocitation.R (sm_network_cocitation) -- pure tidygraph.

test_that("sm_network_cocitation rejects a non-corpus input", {
  expect_error(sm_network_cocitation(list()), class = "rlang_error")
})

test_that("sm_network_cocitation validates min_weight", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_network_cocitation(corpus, min_weight = 0L),
               "positive integer")
  expect_error(sm_network_cocitation(corpus, min_weight = -2L),
               "positive integer")
})

test_that("co-citation network is undirected tbl_graph with weights", {
  corpus <- sm_example_corpus(n_works = 120, n_authors = 30,
                              with_embeddings = FALSE, seed = 2)
  g <- sm_network_cocitation(corpus, min_weight = 1L)
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

test_that("higher min_weight yields a smaller-or-equal edge set", {
  corpus <- sm_example_corpus(n_works = 120, n_authors = 30,
                              with_embeddings = FALSE, seed = 3)
  g_low <- sm_network_cocitation(corpus, min_weight = 1L)
  g_high <- sm_network_cocitation(corpus, min_weight = 3L)
  e_low <- nrow(tibble::as_tibble(tidygraph::activate(g_low, "edges")))
  e_high <- nrow(tibble::as_tibble(tidygraph::activate(g_high, "edges")))
  expect_gte(e_low, e_high)
})

test_that("empty corpus returns an empty undirected graph", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  g <- sm_network_cocitation(empty)
  expect_s3_class(g, "tbl_graph")
  expect_false(igraph::is_directed(g))
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("no linked references returns empty graph", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 4)
  corpus$references$cited_work_id <- NA_character_
  expect_warning(g <- sm_network_cocitation(corpus, min_weight = 1L,
                                            linked_only = TRUE),
                 class = "scimapR_references_unlinked")
  expect_s3_class(g, "tbl_graph")
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("impossibly high min_weight returns empty graph", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 5)
  g <- sm_network_cocitation(corpus, min_weight = 100000L)
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})


test_that("co-citation includes external references with node metadata", {
  x <- sm_read_wos(test_path("fixtures", "link-wos-two.txt"), verbose = FALSE)
  g <- sm_network_cocitation(x, min_weight = 1L)
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  expect_setequal(nodes$name, c(x$works$work_id[1], "10.9999/ext.l1"))
  expect_identical(nodes$in_corpus, nodes$name == x$works$work_id[1])
  expect_true(is.na(nodes$title[nodes$name == "10.9999/ext.l1"]))
  expect_equal(reference_edges(g)$weight, 1L)
})

test_that("co-citation counts each cited pair once per citing work", {
  works <- tibble::tibble(work_id = c("A", "B", "C"))
  refs <- tibble::tibble(work_id = "C", cited_work_id = c("A", "B", "A", "C"))
  x <- sm_corpus(works, references = refs)
  expect_equal(reference_edges(sm_network_cocitation(x, min_weight = 1L)),
               tibble::tibble(from = "A", to = "B", weight = 1L))
  expect_equal(nrow(reference_edges(sm_network_cocitation(x))), 0L)
})

test_that("co-citation by external DOIs preserves linked weights", {
  x <- sm_example_corpus(n_works = 30, with_embeddings = FALSE, seed = 1)
  g <- sm_network_cocitation(x, min_weight = 1L)
  baseline <- reference_edges(g)
  expect_true(all(tibble::as_tibble(g)$in_corpus))
  map <- stats::setNames(x$works$work_id, x$works$doi)
  x$references$cited_work_id <- NA_character_
  expect_equal(reference_edges(sm_network_cocitation(x, min_weight = 1L), map),
               baseline)
})

test_that("co-citation keys do not merge equal labels of different kinds", {
  refs <- tibble::tibble(work_id = "C",
                         cited_work_id = c("10.9999/shared", NA),
                         cited_doi = c(NA, "10.9999/shared"))
  x <- sm_corpus(tibble::tibble(work_id = c("C", "10.9999/shared")),
                 references = refs)
  g <- sm_network_cocitation(x, min_weight = 1L)
  nodes <- tibble::as_tibble(g)
  expect_equal(nrow(nodes), 2L)
  expect_identical(nodes$name, rep("10.9999/shared", 2))
  expect_equal(sum(nodes$in_corpus), 1L)
  expect_equal(nrow(reference_edges(g)), 1L)
})

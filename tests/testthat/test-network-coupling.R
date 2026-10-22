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
  expect_warning(g <- sm_network_coupling(corpus, min_shared = 1L,
                                          linked_only = TRUE),
                 class = "scimapR_references_unlinked")
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("impossibly high min_shared returns empty graph", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 5)
  g <- sm_network_coupling(corpus, min_shared = 100000L)
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})


test_that("coupling counts the external DOI shared by reader-built works", {
  x <- sm_read_wos(test_path("fixtures", "link-wos-two.txt"), verbose = FALSE)
  edges <- reference_edges(sm_network_coupling(x))
  expect_equal(edges, tibble::tibble(from = x$works$work_id[1],
                                     to = x$works$work_id[2], weight = 1L))
})

test_that("coupling counts a repeated cited item only once per work", {
  works <- tibble::tibble(work_id = c("A", "B", "R"))
  refs <- tibble::tibble(work_id = c("A", "A", "B", "A"),
                         cited_work_id = c("R", "R", "R", "A"))
  x <- sm_corpus(works, references = refs)
  expect_equal(reference_edges(sm_network_coupling(x)),
               tibble::tibble(from = "A", to = "B", weight = 1L))
})

test_that("coupling by external DOIs preserves shared-reference weights", {
  x <- sm_example_corpus(n_works = 30, with_embeddings = FALSE, seed = 1)
  baseline <- reference_edges(sm_network_coupling(x))
  x$references$cited_work_id <- NA_character_
  expect_equal(reference_edges(sm_network_coupling(x)), baseline)
})

test_that("coupling normalises OpenAlex IDs and raw reference text", {
  works <- tibble::tibble(work_id = c("A", "B"))
  refs <- tibble::tibble(work_id = rep(c("A", "B"), each = 2),
                         cited_work_id = NA_character_,
                         cited_raw = c("W9990000999", " Roe A, 2020. ",
                                       "https://openalex.org/W9990000999",
                                       "ROE  A, 2020"))
  x <- sm_corpus(works, references = refs)
  expect_equal(reference_edges(sm_network_coupling(x))$weight, 2L)
})

test_that("coupling excludes self-references expressed as DOI or OpenAlex id", {
  x <- sm_corpus(
    tibble::tibble(work_id = c("A", "B"), doi = c("10.9999/a", "10.9999/b"),
                   openalex_id = c("W101", "W102")),
    references = tibble::tibble(work_id = rep(c("A", "B"), 2),
                                cited_work_id = NA_character_,
                                cited_doi = c(rep("10.9999/a", 2), NA, NA),
                                cited_raw = c(NA, NA, "W101", "W101"))
  )
  expect_equal(nrow(reference_edges(sm_network_coupling(x))), 0L)
})

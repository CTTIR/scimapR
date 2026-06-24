# Tests for R/network-collab.R (sm_network_collab) -- pure tidygraph logic.

test_that("sm_network_collab rejects a non-corpus input", {
  expect_error(sm_network_collab(list()), class = "rlang_error")
})

test_that("sm_network_collab validates the level argument", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_network_collab(corpus, level = "planet"),
               class = "rlang_error")
})

test_that("author-level network is an undirected tbl_graph with weights", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = FALSE, seed = 2)
  g <- sm_network_collab(corpus, level = "author")
  expect_s3_class(g, "tbl_graph")
  expect_false(igraph::is_directed(g))

  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(g, "edges"))
  expect_true("name" %in% names(nodes))
  # author metadata joined
  expect_true("display_name" %in% names(nodes))
  expect_true("weight" %in% names(edges))
  expect_gt(nrow(nodes), 0L)
  expect_true(all(edges$weight >= 1L))
  expect_true(all(edges$from >= 1L & edges$from <= nrow(nodes)))
  expect_true(all(edges$to >= 1L & edges$to <= nrow(nodes)))
})

test_that("country-level network builds without metadata join", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 25,
                              with_embeddings = FALSE, seed = 3)
  g <- sm_network_collab(corpus, level = "country")
  expect_s3_class(g, "tbl_graph")
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  expect_setequal(names(nodes), "name")
  expect_gt(nrow(nodes), 0L)
})

test_that("empty corpus returns an empty undirected graph", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  g <- sm_network_collab(empty, level = "author")
  expect_s3_class(g, "tbl_graph")
  expect_false(igraph::is_directed(g))
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("institution level errors when column missing", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 4)
  corpus$authorships$institution_id <- NULL
  expect_error(sm_network_collab(corpus, level = "institution"),
               "not found")
})

test_that("all-NA entity column returns isolate-free empty graph", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 5)
  corpus$authorships$institution_id <- NA_character_
  g <- sm_network_collab(corpus, level = "institution")
  expect_s3_class(g, "tbl_graph")
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

test_that("single-author works produce isolate nodes, zero edges", {
  corpus <- sm_example_corpus(n_works = 8, n_authors = 8,
                              with_embeddings = FALSE,
                              with_trajectory_seed = FALSE, seed = 6)
  # Force every work to have exactly one unique author => no co-authorship.
  corpus$authorships <- corpus$authorships %>%
    dplyr::group_by(.data$work_id) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup()
  corpus$authorships$author_id <-
    paste0("A", formatC(seq_len(nrow(corpus$authorships)),
                        width = 9, flag = "0"))
  g <- sm_network_collab(corpus, level = "author")
  expect_s3_class(g, "tbl_graph")
  nodes <- tibble::as_tibble(tidygraph::activate(g, "nodes"))
  edges <- tibble::as_tibble(tidygraph::activate(g, "edges"))
  expect_gt(nrow(nodes), 0L)
  expect_equal(nrow(edges), 0L)
})

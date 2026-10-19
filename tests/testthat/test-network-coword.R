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
  # Example concepts are OpenAlex concepts only, neither author nor indexer
  # keywords, so the default keyword network is empty, with a message.
  expect_message(
    g <- sm_network_coword(corpus, field = "keywords", min_freq = 1L),
    class = "scimapR_coword_no_keywords"
  )
  expect_s3_class(g, "tbl_graph")
  expect_equal(nrow(tibble::as_tibble(tidygraph::activate(g, "nodes"))), 0L)
})

# ---- keyword vocabularies ------------------------------------------------

node_names <- function(g) {
  tibble::as_tibble(tidygraph::activate(g, "nodes"))$name
}

terms_of <- function(corpus, vocabulary) {
  concepts <- corpus$concepts
  unique(tolower(concepts$concept_name[concepts$vocabulary %in% vocabulary]))
}

test_that("keywords field uses the author keywords by default", {
  fix <- realuse_corpus()
  expect_silent(g <- sm_network_coword(fix, field = "keywords",
                                       min_freq = 3L))
  nodes <- node_names(g)
  expect_gt(length(nodes), 0L)
  expect_true(all(nodes %in% terms_of(fix, "author-keywords")))
  expect_true(all(c("orthohantavirus", "hemorrhage control",
                    "exertional heat illness") %in% nodes))
})

test_that("vocabulary = 'indexer_keyword' builds a Keywords Plus network", {
  fix <- realuse_corpus()
  g <- sm_network_coword(fix, field = "keywords",
                         vocabulary = "indexer_keyword", min_freq = 3L)
  nodes <- node_names(g)
  expect_gt(length(nodes), 0L)
  expect_true(all(nodes %in% terms_of(fix, "keywords-plus")))
  expect_false(any(nodes %in% terms_of(fix, "author-keywords")))

  # The argument shares its name with the concepts column; a single
  # vocabulary must select only its own rows.
  g_plus <- sm_network_coword(fix, field = "keywords",
                              vocabulary = "Keywords Plus", min_freq = 3L)
  expect_setequal(node_names(g_plus), nodes)
  g_both <- sm_network_coword(fix, field = "keywords",
                              vocabulary = c("author_keyword", "keywords-plus"),
                              min_freq = 3L)
  expect_gt(length(node_names(g_both)), length(nodes))
})

test_that("keywords fall back to indexer keywords with a message", {
  fix <- realuse_corpus()
  fix$concepts <- fix$concepts[fix$concepts$vocabulary != "author-keywords", ]
  expect_message(
    g <- sm_network_coword(fix, field = "keywords", min_freq = 3L),
    class = "scimapR_coword_keyword_fallback"
  )
  nodes <- node_names(g)
  expect_gt(length(nodes), 0L)
  expect_true(all(nodes %in% terms_of(fix, "keywords-plus")))
})

test_that("keywords stored under a legacy name are still found", {
  fix <- realuse_corpus()
  canonical <- node_names(sm_network_coword(fix, field = "keywords",
                                            min_freq = 3L))
  is_kw <- fix$concepts$vocabulary == "author-keywords"
  fix$concepts$vocabulary[is_kw] <- "keyword"
  legacy <- node_names(sm_network_coword(fix, field = "keywords",
                                         min_freq = 3L))
  expect_setequal(legacy, canonical)
})

test_that("vocabulary restricts the concepts field", {
  fix <- realuse_corpus()
  g <- sm_network_coword(fix, field = "concepts", vocabulary = "category",
                         min_freq = 3L)
  nodes <- node_names(g)
  expect_gt(length(nodes), 0L)
  expect_true(all(nodes %in% terms_of(fix, c("wos-category",
                                             "wos-subject-category"))))
  # NULL keeps every vocabulary, as before.
  all_terms <- node_names(sm_network_coword(fix, field = "concepts",
                                            min_freq = 3L))
  expect_true(all(nodes %in% all_terms))
  expect_true(any(terms_of(fix, "author-keywords") %in% all_terms))
})

test_that("unknown vocabularies give an error listing the vocabularies", {
  fix <- realuse_corpus()
  expect_error(
    sm_network_coword(fix, field = "keywords", vocabulary = "nope"),
    "sm_concept_vocabularies"
  )
  expect_error(
    sm_network_coword(fix, field = "keywords", vocabulary = NA_character_),
    class = "rlang_error"
  )
  expect_error(
    sm_network_coword(fix, field = "title", vocabulary = "author_keyword"),
    "vocabulary"
  )
})

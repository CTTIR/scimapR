# Tests for R/enrich-specter.R (sm_enrich_specter).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_specter rejects a non-corpus input", {
  expect_error(sm_enrich_specter(list()), class = "rlang_error")
})

test_that("specter skips when all works lack DOIs", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$works$doi <- NA_character_
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_specter(corpus, verbose = TRUE),
    "already have embeddings or have no DOIs"
  )
  expect_identical(out, corpus)
})

test_that("specter skips when all works already have embeddings", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = TRUE, seed = 2)
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  out <- sm_enrich_specter(corpus, verbose = FALSE)
  expect_identical(out$embeddings, corpus$embeddings)
})

test_that("specter attaches embeddings returned by the API", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  vec <- as.list(seq_len(4))

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      # One paper object per work in the batch, each with a 4-d vector.
      list(
        list(paperId = "p1", embedding = list(vector = vec)),
        list(paperId = "p2", embedding = list(vector = vec)),
        list(paperId = "p3", embedding = list(vector = vec))
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_specter(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_false(is.null(out$embeddings))
  expect_equal(nrow(out$embeddings), 3L)
  expect_equal(ncol(out$embeddings), 4L)
  expect_equal(as.numeric(out$embeddings[1, ]), c(1, 2, 3, 4))
  expect_true("semantic_scholar" %in% out$provenance$source)
})

test_that("specter tolerates a NULL paper / missing embedding", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(NULL, list(paperId = "p2"))  # one NULL, one with no embedding
    },
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_specter(corpus, verbose = TRUE),
    "No SPECTER embeddings retrieved"
  )
  expect_null(out$embeddings)
})

test_that("specter returns corpus unchanged when the request errors", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 5)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )
  out <- sm_enrich_specter(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_null(out$embeddings)
})

test_that("specter merges new embeddings with existing ones of equal dim", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  # Seed one existing embedding row of dimension 4 for work 1.
  existing <- matrix(c(9, 9, 9, 9), nrow = 1)
  rownames(existing) <- corpus$works$work_id[1]
  corpus$embeddings <- existing

  vec <- as.list(seq_len(4))
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(
        list(paperId = "p2", embedding = list(vector = vec)),
        list(paperId = "p3", embedding = list(vector = vec))
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_specter(corpus, verbose = FALSE)
  expect_equal(nrow(out$embeddings), 3L)
  expect_equal(as.numeric(out$embeddings[corpus$works$work_id[1], ]),
               c(9, 9, 9, 9))
})

test_that("specter uses an API key header when one is provided", {
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 7)
  vec <- as.list(seq_len(4))
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(list(paperId = "p1", embedding = list(vector = vec)))
    },
    .package = "httr2"
  )
  out <- sm_enrich_specter(corpus, api_key = "fake-key", verbose = FALSE)
  expect_equal(nrow(out$embeddings), 1L)
})

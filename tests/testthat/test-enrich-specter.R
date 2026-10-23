# Tests for R/enrich-specter.R (sm_enrich_specter).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2")
# or httr2::local_mocked_responses().

# Record existing embeddings as Semantic Scholar's SPECTER v2 vectors
as_specter_v2 <- function(corpus) {
  corpus$metadata$embedding <- .s2_embedding_record("specter_v2", NULL,
                                                    corpus$embeddings)
  corpus
}

# Mock one batch answer: one paper per DOI, each with a 4-d vector
local_specter_answer <- function(n, vec = as.list(seq_len(4)),
                                 env = parent.frame()) {
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) httr2::response(status_code = 200L),
    resp_body_json = function(resp, ...) {
      lapply(seq_len(n), function(i) {
        list(paperId = paste0("p", i),
             embedding = list(model = "specter_v2", vector = vec))
      })
    },
    .package = "httr2", .env = env
  )
}

test_that("sm_enrich_specter rejects a non-corpus input", {
  local_http_env()
  expect_error(sm_enrich_specter(list()), class = "rlang_error")
})

test_that("specter skips when all works lack DOIs", {
  local_http_env()
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
  local_http_env()
  # the existing embeddings are SPECTER v2 vectors from Semantic Scholar;
  # embeddings of another or an unrecorded model stop instead (below)
  corpus <- as_specter_v2(sm_example_corpus(n_works = 4, n_authors = 3,
                                            with_embeddings = TRUE, seed = 2))
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  out <- sm_enrich_specter(corpus, verbose = FALSE)
  expect_identical(out$embeddings, corpus$embeddings)
})

test_that("specter attaches embeddings returned by the API", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  local_specter_answer(3)

  out <- suppressMessages(sm_enrich_specter(corpus, verbose = FALSE))
  expect_s3_class(out, "sm_corpus")
  expect_false(is.null(out$embeddings))
  expect_equal(nrow(out$embeddings), 3L)
  expect_equal(ncol(out$embeddings), 4L)
  expect_equal(as.numeric(out$embeddings[1, ]), c(1, 2, 3, 4))
  expect_true("semantic_scholar" %in% out$provenance$source)

  rec <- out$metadata$embedding
  expect_identical(rec$model_id, "embedding.specter_v2")
  expect_identical(rec$backend, "semantic-scholar")
  expect_identical(rec$revision, "specter_v2")
  expect_identical(c(rec$n_works, rec$n_dimensions), c(3L, 4L))
  # an enrichment, which sm_rebuild_from_cert() does not replay
  added <- out$provenance[!is.na(out$provenance$kind), ]
  expect_identical(unique(added$kind), "enrichment")
  expect_identical(nrow(added), 3L)
})

test_that("specter asks Semantic Scholar for SPECTER v2 vectors", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 3)
  urls <- character()
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      urls <<- c(urls, req$url)
      httr2::response(status_code = 200L)
    },
    resp_body_json = function(resp, ...) list(),
    .package = "httr2"
  )
  suppressMessages(sm_enrich_specter(corpus, verbose = FALSE))
  expect_length(urls, 1L)
  expect_match(urls, "fields=paperId%2Cembedding.specter_v2", fixed = TRUE)
})

test_that("specter tolerates a NULL paper / missing embedding", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) httr2::response(status_code = 200L),
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
  expect_null(out$metadata$embedding)
})

test_that("specter warns and returns the corpus unchanged when requests fail", {
  local_http_env()
  # before, a failed batch was reported only with verbose = TRUE
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 5)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )
  expect_warning(
    out <- sm_enrich_specter(corpus, verbose = FALSE),
    "1 of 1 Semantic Scholar request failed",
    class = "scimapR_specter_failed"
  )
  expect_s3_class(out, "sm_corpus")
  expect_null(out$embeddings)
})

test_that("specter tries once more after HTTP 429", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 7)
  answers <- list(
    httr2::response(429L, headers = list(`Retry-After` = "0")),
    httr2::response_json(body = list(list(
      paperId = "p1", embedding = list(model = "specter_v2",
                                       vector = list(1, 2, 3))
    )))
  )
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    answers[[calls]]
  })
  out <- suppressMessages(sm_enrich_specter(corpus, verbose = FALSE))
  expect_identical(calls, 2L)
  expect_identical(dim(out$embeddings), c(1L, 3L))
})

test_that("specter warns about a rate limit that does not pass", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 7)
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    httr2::response(429L, headers = list(`Retry-After` = "0"))
  })
  expect_warning(
    out <- sm_enrich_specter(corpus, api_key = "", verbose = FALSE),
    "SEMANTIC_SCHOLAR_API_KEY",
    class = "scimapR_specter_failed"
  )
  expect_identical(calls, 2L)
  expect_null(out$embeddings)
})

test_that("specter fills gaps in its own embeddings and keeps them", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  # One existing SPECTER v2 row of dimension 4 for work 1.
  existing <- matrix(c(9, 9, 9, 9), nrow = 1)
  rownames(existing) <- corpus$works$work_id[1]
  corpus$embeddings <- existing
  corpus <- as_specter_v2(corpus)

  local_specter_answer(2)
  out <- suppressMessages(sm_enrich_specter(corpus, verbose = FALSE))
  expect_equal(nrow(out$embeddings), 3L)
  expect_equal(as.numeric(out$embeddings[corpus$works$work_id[1], ]),
               c(9, 9, 9, 9))
  expect_identical(out$metadata$embedding$model_id, "embedding.specter_v2")
  expect_identical(out$metadata$embedding$n_works, 3L)
})

test_that("specter does not mix embeddings of another model by default", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  # one existing row of the same width, but of an unrecorded model
  existing <- matrix(c(9, 9, 9, 9), nrow = 1)
  rownames(existing) <- corpus$works$work_id[1]
  corpus$embeddings <- existing
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_error(sm_enrich_specter(corpus, verbose = FALSE),
               "mix_models = TRUE",
               class = "scimapR_embedding_model_mismatch")

  # mpnet embeddings of another width are not discarded either
  corpus$embeddings <- matrix(1, nrow = 3, ncol = 6,
                              dimnames = list(corpus$works$work_id, NULL))
  corpus$metadata$embedding <- .new_embedding_record(
    "mpnet", "sentence-transformers/all-mpnet-base-v2",
    "sentence-transformers", n_works = 3, n_dimensions = 6
  )
  expect_error(sm_enrich_specter(corpus, verbose = FALSE),
               "all-mpnet-base-v2",
               class = "scimapR_embedding_model_mismatch")
  expect_error(sm_enrich_specter(corpus, replace = TRUE, mix_models = TRUE),
               "not both")
})

test_that("specter mixes models only when asked, as a recorded mix", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  existing <- matrix(c(9, 9, 9, 9), nrow = 1)
  rownames(existing) <- corpus$works$work_id[1]
  corpus$embeddings <- existing

  local_specter_answer(2)
  out <- suppressMessages(
    sm_enrich_specter(corpus, mix_models = TRUE, verbose = FALSE)
  )
  expect_equal(nrow(out$embeddings), 3L)
  expect_equal(as.numeric(out$embeddings[corpus$works$work_id[1], ]),
               c(9, 9, 9, 9))
  rec <- out$metadata$embedding
  expect_identical(rec$model_id, "mixed")
  expect_identical(rec$models, c("unknown", "embedding.specter_v2"))

  # a mix needs one width
  corpus$embeddings <- cbind(existing, 9)
  expect_error(
    suppressMessages(
      sm_enrich_specter(corpus, mix_models = TRUE, verbose = FALSE)
    ),
    "replace = TRUE", class = "scimapR_embedding_model_mismatch"
  )
})

test_that("specter replaces embeddings of another model only when asked", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  corpus$embeddings <- matrix(1, nrow = 3, ncol = 6,
                              dimnames = list(corpus$works$work_id, NULL))
  corpus$metadata$embedding <- .new_embedding_record(
    "minilm-l6", "sentence-transformers/all-MiniLM-L6-v2",
    "sentence-transformers", n_works = 3, n_dimensions = 6
  )

  local_specter_answer(3)
  msgs <- testthat::capture_messages(
    out <- sm_enrich_specter(corpus, replace = TRUE, verbose = FALSE)
  )
  expect_match(msgs, "Replaced 3 rows of embeddings of", all = FALSE)
  expect_identical(dim(out$embeddings), c(3L, 4L))
  expect_identical(out$metadata$embedding$model_id, "embedding.specter_v2")
})

test_that("specter replaces the example corpus's embeddings as documented", {
  local_http_env()
  # the call of the embeddings vignette: the example embeddings record no
  # model, so the plain call stops and replace = TRUE goes on
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = TRUE, seed = 42)
  expect_null(corpus$metadata$embedding)
  local_specter_answer(3)
  expect_error(sm_enrich_specter(corpus, verbose = FALSE),
               "replace = TRUE",
               class = "scimapR_embedding_model_mismatch")

  msgs <- testthat::capture_messages(
    out <- sm_enrich_specter(corpus, replace = TRUE, verbose = FALSE)
  )
  expect_match(msgs, "whose model is not recorded", all = FALSE)
  expect_identical(rownames(out$embeddings), corpus$works$work_id)
  expect_identical(out$metadata$embedding$model_id, "embedding.specter_v2")
})

test_that("specter uses an API key header when one is provided", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 7)
  vec <- as.list(seq_len(4))
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) httr2::response(status_code = 200L),
    resp_body_json = function(resp, ...) {
      list(list(paperId = "p1", embedding = list(vector = vec)))
    },
    .package = "httr2"
  )
  out <- suppressMessages(
    sm_enrich_specter(corpus, api_key = "fake-key", verbose = FALSE)
  )
  expect_equal(nrow(out$embeddings), 1L)
})

test_that("specter rejects long rate limits without another request", {
  local_http_env()
  calls <- 0L
  local_mocked_bindings(req_perform = function(...) {
    calls <<- calls + 1L
    http_response(status = 429L, headers = list(`Retry-After` = "3600"))
  }, .package = "httr2")
  expect_error(.s2_perform(httr2::request("https://example.org")),
               class = "scimapR_rate_limited")
  expect_identical(calls, 1L)
})

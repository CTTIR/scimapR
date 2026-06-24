# Tests for R/enrich-altmetric.R (sm_enrich_altmetric).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_altmetric rejects a non-corpus input", {
  expect_error(sm_enrich_altmetric(list()), class = "rlang_error")
})

test_that("altmetric skips when no DOIs are present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$works$doi <- NA_character_
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_altmetric(corpus, verbose = TRUE),
    "No DOIs in corpus"
  )
  expect_identical(out$works$doi, corpus$works$doi)
})

test_that("altmetric adds attention columns from the API response", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(
        score = 42.5,
        readers = list(mendeley = 17L),
        cited_by_tweeters_count = 8L,
        cited_by_msm_count = 3L
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_altmetric(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_true(all(c("altmetric_score", "mendeley_readers",
                    "twitter_count", "news_count") %in% names(out$works)))
  expect_true(all(out$works$altmetric_score == 42.5))
  expect_true(all(out$works$mendeley_readers == 17L))
  expect_true(all(out$works$twitter_count == 8L))
  expect_true(all(out$works$news_count == 3L))
  expect_true("altmetric" %in% out$provenance$source)
})

test_that("altmetric leaves scores NA when the API returns NULL", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) NULL,
    .package = "httr2"
  )

  out <- sm_enrich_altmetric(corpus, verbose = FALSE)
  expect_true(all(is.na(out$works$altmetric_score)))
  # Provenance is still appended for all DOI-bearing works.
  expect_true("altmetric" %in% out$provenance$source)
})

test_that("altmetric tolerates request errors", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )
  out <- sm_enrich_altmetric(corpus, verbose = FALSE)
  expect_true(all(is.na(out$works$altmetric_score)))
  expect_s3_class(out, "sm_corpus")
})

test_that("altmetric works with an explicit API key supplied", {
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 5)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) list(score = 1.0),
    .package = "httr2"
  )
  out <- sm_enrich_altmetric(corpus, api_key = "fake-key", verbose = FALSE)
  expect_equal(out$works$altmetric_score[1], 1.0)
})

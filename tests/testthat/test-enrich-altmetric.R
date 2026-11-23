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
  expect_warning(
    out <- sm_enrich_altmetric(corpus, api_key = "fake-key", verbose = FALSE),
    class = "scimapR_altmetric_unchecked"
  )
  expect_true(all(is.na(out$works$altmetric_score)))
  expect_s3_class(out, "sm_corpus")
  expect_false("altmetric" %in% out$provenance$source)
})

test_that("altmetric failures without a key name the missing key", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      rlang::abort("HTTP 403 Forbidden.",
                   class = c("httr2_http_403", "httr2_http", "httr2_error"))
    },
    .package = "httr2"
  )
  w <- expect_warning(
    sm_enrich_altmetric(corpus, api_key = "", verbose = FALSE),
    class = "scimapR_altmetric_unchecked"
  )
  expect_match(conditionMessage(w), "ALTMETRIC_API_KEY")
  expect_setequal(w$work_ids, corpus$works$work_id[!is.na(corpus$works$doi)])
})

test_that("altmetric treats a 404 as 'no record' without warning", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      rlang::abort("HTTP 404 Not Found.",
                   class = c("httr2_http_404", "httr2_http", "httr2_error"))
    },
    .package = "httr2"
  )
  expect_no_warning(
    out <- sm_enrich_altmetric(corpus, api_key = "fake-key", verbose = FALSE)
  )
  expect_true(all(is.na(out$works$altmetric_score)))
  expect_true("altmetric" %in% out$provenance$source)
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

test_that("altmetric stops requesting after an unauthorised answer", {
  withr::local_envvar(ALTMETRIC_API_KEY = "")
  corpus <- sm_example_corpus(n_works = 5, n_authors = 2,
                              with_embeddings = FALSE, seed = 6)
  corpus$works$doi <- paste0("10.9999/alt.", seq_len(5))
  calls <- 0L
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      calls <<- calls + 1L
      rlang::abort("HTTP 401 Unauthorized.",
                   class = c("httr2_http_401", "httr2_http", "httr2_error"))
    },
    req_throttle = function(req, ...) req,
    .package = "httr2"
  )
  w <- expect_warning(
    out <- sm_enrich_altmetric(corpus, verbose = FALSE),
    class = "scimapR_altmetric_unchecked"
  )
  expect_identical(calls, 1L)
  expect_setequal(w$work_ids, corpus$works$work_id)
  expect_match(conditionMessage(w), "remaining DOIs were not requested")
  expect_false("altmetric" %in% out$provenance$source)
})

test_that("altmetric keeps requesting after other failures", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2,
                              with_embeddings = FALSE, seed = 7)
  corpus$works$doi <- paste0("10.9999/alt.", seq_len(3))
  calls <- 0L
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      calls <<- calls + 1L
      rlang::abort("HTTP 503 Service Unavailable.",
                   class = c("httr2_http_503", "httr2_http", "httr2_error"))
    },
    req_throttle = function(req, ...) req,
    .package = "httr2"
  )
  w <- expect_warning(
    sm_enrich_altmetric(corpus, api_key = "fake-key", verbose = FALSE),
    class = "scimapR_altmetric_unchecked"
  )
  expect_identical(calls, 3L)
  expect_no_match(conditionMessage(w), "not requested")
})

test_that("altmetric percent-encodes DOIs in the request path", {
  corpus <- sm_corpus(works = tibble::tibble(
    work_id = "W1",
    doi = "10.1002/(sici)1097-4571(199806)49:8<693::aid-asi4>3.0.co;2-0#x"
  ))
  urls <- character()
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      urls <<- c(urls, req$url)
      structure(list(), class = "sm_fake_resp")
    },
    resp_body_json = function(resp, ...) list(score = 3),
    req_throttle = function(req, ...) req,
    .package = "httr2"
  )
  out <- sm_enrich_altmetric(corpus, api_key = "fake-key", verbose = FALSE)
  expect_length(urls, 1L)
  # the whole DOI, "#x" included, is the path: nothing is cut off as a
  # fragment or query
  path <- sub("\\?.*$", "", urls)
  expect_false(grepl("#", urls, fixed = TRUE))
  expect_identical(
    utils::URLdecode(sub("^https://api\\.altmetric\\.com/v1/doi/", "", path)),
    corpus$works$doi
  )
  expect_equal(out$works$altmetric_score, 3)
})

test_that("altmetric is silent with verbose = FALSE", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 8)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) list(score = 2),
    .package = "httr2"
  )
  expect_silent(sm_enrich_altmetric(corpus, api_key = "k", verbose = FALSE))
  expect_message(sm_enrich_altmetric(corpus, api_key = "k", verbose = TRUE),
                 "Enriched 2 works with Altmetric data")
})

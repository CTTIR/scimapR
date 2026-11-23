# Tests for R/enrich-unpaywall.R (sm_enrich_unpaywall).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_unpaywall rejects a non-corpus input", {
  expect_error(sm_enrich_unpaywall(list(), mailto = "a@b.com"),
               class = "rlang_error")
})

test_that("unpaywall requires a mailto address", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 1)
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_error(
    sm_enrich_unpaywall(corpus, mailto = ""),
    "mailto"
  )
})

test_that("unpaywall skips when no DOIs are present", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  corpus$works$doi <- NA_character_
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = TRUE),
    "No DOIs in corpus"
  )
  expect_identical(out$works$doi, corpus$works$doi)
})

test_that("unpaywall updates oa_status and oa_url from the API", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(
        oa_status = "gold",
        best_oa_location = list(url_for_pdf = "https://example.org/x.pdf")
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_true(all(out$works$oa_status == "gold"))
  expect_true("oa_url" %in% names(out$works))
  expect_true(all(out$works$oa_url == "https://example.org/x.pdf"))
  expect_true("unpaywall" %in% out$provenance$source)
})

test_that("unpaywall falls back to landing page URL then plain url", {
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 4)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(
        oa_status = "green",
        best_oa_location = list(url = "https://example.org/landing")
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE)
  expect_equal(out$works$oa_url[1], "https://example.org/landing")
})

test_that("unpaywall handles a missing best_oa_location", {
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 5)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) list(oa_status = "closed"),
    .package = "httr2"
  )

  out <- sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE)
  expect_equal(out$works$oa_status[1], "closed")
  expect_true(is.na(out$works$oa_url[1]))
})

test_that("unpaywall tolerates request errors", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 6)
  before <- corpus$works$oa_status

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )

  w <- expect_warning(
    out <- sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE),
    class = "scimapR_unpaywall_unchecked"
  )
  expect_equal(out$works$oa_status, before)
  expect_s3_class(out, "sm_corpus")
  expect_setequal(w$work_ids, corpus$works$work_id[!is.na(corpus$works$doi)])
  expect_false("unpaywall" %in% out$provenance$source)
})

test_that("unpaywall keeps earlier values of works whose lookup failed", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 7)
  corpus$works$doi <- c("10.9999/up.1", "10.9999/up.2")
  corpus$works$oa_status <- c("green", "green")
  corpus$works$oa_url <- c("https://example.org/old1", "https://example.org/old2")
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      if (grepl("up.1", req$url, fixed = TRUE)) {
        rlang::abort("HTTP 500.",
                     class = c("httr2_http_500", "httr2_http", "httr2_error"))
      }
      structure(list(), class = "sm_fake_resp")
    },
    resp_body_json = function(resp, ...) list(oa_status = "closed"),
    req_throttle = function(req, ...) req,
    .package = "httr2"
  )
  w <- expect_warning(
    out <- sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE),
    class = "scimapR_unpaywall_unchecked"
  )
  expect_identical(w$work_ids, corpus$works$work_id[1])
  # the failed work keeps its status and URL, the answered one is updated
  expect_identical(out$works$oa_status, c("green", "closed"))
  expect_identical(out$works$oa_url, c("https://example.org/old1", NA))
  prov <- out$provenance[out$provenance$source == "unpaywall", ]
  expect_identical(prov$work_id, corpus$works$work_id[2])
})

test_that("unpaywall treats a 404 as an answer without warning", {
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1,
                              with_embeddings = FALSE, seed = 8)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      rlang::abort("HTTP 404 Not Found.",
                   class = c("httr2_http_404", "httr2_http", "httr2_error"))
    },
    .package = "httr2"
  )
  expect_no_warning(
    out <- sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE)
  )
  expect_true("unpaywall" %in% out$provenance$source)
})

test_that("unpaywall is silent with verbose = FALSE", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 9)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) list(oa_status = "gold"),
    .package = "httr2"
  )
  expect_silent(
    sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE)
  )
  expect_message(
    sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = TRUE),
    "Enriched 2 works with Unpaywall data"
  )
})

test_that("unpaywall percent-encodes DOIs in the request path", {
  corpus <- sm_corpus(works = tibble::tibble(work_id = "W1",
                                             doi = "10.1000/a#b?c"))
  urls <- character()
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      urls <<- c(urls, req$url)
      structure(list(), class = "sm_fake_resp")
    },
    resp_body_json = function(resp, ...) list(oa_status = "closed"),
    .package = "httr2"
  )
  sm_enrich_unpaywall(corpus, mailto = "a@b.com", verbose = FALSE)
  expect_match(urls, "^https://api\\.unpaywall\\.org/v2/10\\.1000/a%23b%3Fc\\?email=")
})

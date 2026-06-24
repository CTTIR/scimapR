# Tests for R/enrich-retraction.R (sm_enrich_retraction).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_retraction rejects a non-corpus input", {
  expect_error(sm_enrich_retraction(list()), class = "rlang_error")
})

test_that("retraction check short-circuits when no DOIs present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$works$doi <- NA_character_
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_retraction(corpus, verbose = TRUE),
    "No DOIs"
  )
  expect_identical(out$works, corpus$works)
})

test_that("OpenAlex-reported retraction flags the matching work", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  corpus$works$is_retracted <- FALSE
  target_doi <- corpus$works$doi[2]

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      # Distinguish OpenAlex (results) vs Crossref (message) by reusing one fn:
      # OpenAlex flags doi #2; Crossref always returns 0 results.
      list(
        results = list(list(doi = target_doi, is_retracted = TRUE)),
        message = list(`total-results` = 0L)
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_retraction(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_true(out$works$is_retracted[2])
  expect_equal(sum(out$works$is_retracted), 1L)
  expect_true("retraction_check" %in% out$provenance$source)
})

test_that("no retractions reported leaves all works unflagged", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  corpus$works$is_retracted <- FALSE

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(results = list(), message = list(`total-results` = 0L))
    },
    .package = "httr2"
  )

  out <- sm_enrich_retraction(corpus, verbose = FALSE)
  expect_false(any(out$works$is_retracted))
  # Provenance still appended for all checked DOIs.
  expect_true("retraction_check" %in% out$provenance$source)
})

test_that("Crossref retraction notice flags a work OpenAlex missed", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  corpus$works$is_retracted <- FALSE

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      # OpenAlex finds nothing; Crossref reports a retraction notice for all.
      list(results = list(), message = list(`total-results` = 1L))
    },
    .package = "httr2"
  )

  out <- sm_enrich_retraction(corpus, verbose = FALSE)
  # Every DOI gets a positive Crossref hit -> all flagged.
  expect_true(all(out$works$is_retracted))
})

test_that("request errors are tolerated and yield no false positives", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 5)
  corpus$works$is_retracted <- FALSE

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )

  out <- sm_enrich_retraction(corpus, verbose = FALSE)
  expect_false(any(out$works$is_retracted))
  expect_s3_class(out, "sm_corpus")
})

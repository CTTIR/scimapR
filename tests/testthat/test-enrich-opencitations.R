# Tests for R/enrich-opencitations.R (sm_enrich_opencitations).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_opencitations rejects a non-corpus input", {
  expect_error(sm_enrich_opencitations(list()), class = "rlang_error")
})

test_that("opencitations skips when no DOIs are present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$works$doi <- NA_character_
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_opencitations(corpus, verbose = TRUE),
    "No DOIs in corpus"
  )
  expect_identical(out$works, corpus$works)
})

test_that("opencitations updates citation counts and adds references", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  n_refs_before <- nrow(corpus$references)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      # Two citing records per DOI.
      list(
        list(citing = "10.9999/citing.a"),
        list(citing = "10.9999/citing.b")
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  # cited_by_count updated to 2 for all (each DOI returned 2 citing records).
  expect_true(all(out$works$cited_by_count == 2L))
  expect_gt(nrow(out$references), n_refs_before)
  expect_true("opencitations" %in% out$provenance$source)
})

test_that("opencitations leaves counts unchanged when API returns nothing", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  before <- corpus$works$cited_by_count

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) list(),  # empty result
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  expect_equal(out$works$cited_by_count, before)
  expect_false("opencitations" %in% out$provenance$source)
})

test_that("opencitations tolerates request errors", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  before <- corpus$works$cited_by_count

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  expect_equal(out$works$cited_by_count, before)
  expect_s3_class(out, "sm_corpus")
})

test_that("opencitations skips citing records that are NA", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 5)
  n_refs_before <- nrow(corpus$references)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      # Records present (so count is set) but no usable 'citing' field.
      list(list(other = "x"), list(other = "y"))
    },
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  # Counts updated because length(result) > 0 ...
  expect_true(all(out$works$cited_by_count == 2L))
  # ... but no new references because all citing DOIs were NA.
  expect_equal(nrow(out$references), n_refs_before)
})

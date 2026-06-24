test_that("sm_audit_funding rejects non-corpus input", {
  expect_error(sm_audit_funding(list(a = 1)), "sm_corpus")
  expect_error(sm_audit_funding(42), "sm_corpus")
})

test_that("sm_audit_funding validates the source argument", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 1)
  expect_error(sm_audit_funding(corpus, source = "bogus"))
})

test_that("sm_audit_funding returns empty result for empty corpus", {
  corpus <- make_empty_corpus()
  res <- sm_audit_funding(corpus, source = "crossref")
  expect_s3_class(res, "sm_audit_funding")
  expect_equal(res$n_works_total, 0L)
  expect_equal(res$n_works_funded, 0L)
  expect_equal(res$coverage, 0.0)
  expect_equal(nrow(res$funders), 0L)
  expect_equal(res$source, "crossref")
})

test_that("sm_audit_funding (crossref) returns empty when rcrossref missing", {
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 2)
  testthat::local_mocked_bindings(
    is_installed = function(...) FALSE,
    .package = "rlang"
  )
  expect_message(sm_audit_funding(corpus, source = "crossref"), "rcrossref")
  res <- suppressMessages(sm_audit_funding(corpus, source = "crossref"))
  expect_s3_class(res, "sm_audit_funding")
  expect_equal(res$n_works_total, 8L)
  expect_equal(res$n_works_funded, 0L)
  expect_equal(nrow(res$funders), 0L)
  expect_equal(res$coverage, 0.0)
})

test_that("sm_audit_funding (openalex) returns empty when openalexR missing", {
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 3)
  testthat::local_mocked_bindings(
    is_installed = function(...) FALSE,
    .package = "rlang"
  )
  expect_message(sm_audit_funding(corpus, source = "openalex"), "openalexR")
  res <- suppressMessages(sm_audit_funding(corpus, source = "openalex"))
  expect_s3_class(res, "sm_audit_funding")
  expect_equal(res$source, "openalex")
  expect_equal(res$n_works_funded, 0L)
})

test_that("sm_audit_funding aggregates funder data correctly", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 4)
  # Mock the crossref fetcher to return deterministic funder rows.
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, call) {
      tibble::tibble(
        work_id = c(works$work_id[1], works$work_id[1], works$work_id[2]),
        funder_name = c("NIH", "NSF", "NIH"),
        funder_doi = c("10.13039/nih", "10.13039/nsf", "10.13039/nih")
      )
    }
  )
  res <- sm_audit_funding(corpus, source = "crossref")
  expect_s3_class(res, "sm_audit_funding")
  expect_equal(res$n_works_total, 10L)
  # Two distinct funded works
  expect_equal(res$n_works_funded, 2L)
  expect_equal(res$coverage, round(2 / 10, 3))
  # NIH appears in 2 works, NSF in 1, sorted descending
  expect_equal(res$funders$funder_name[1], "NIH")
  expect_equal(res$funders$n_works[1], 2L)
  expect_true(all(c("funder_name", "funder_doi", "n_works", "pct") %in%
                    names(res$funders)))
  expect_equal(res$funders$pct[1], round(100 * 2 / 10, 2))
})

test_that("sm_audit_funding informs when fetcher returns no rows", {
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE, seed = 5)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, call) {
      tibble::tibble(
        work_id = character(), funder_name = character(),
        funder_doi = character()
      )
    }
  )
  expect_message(sm_audit_funding(corpus, source = "crossref"),
                 "No funding data")
  res <- suppressMessages(sm_audit_funding(corpus, source = "crossref"))
  expect_equal(res$n_works_total, 5L)
  expect_equal(res$n_works_funded, 0L)
})

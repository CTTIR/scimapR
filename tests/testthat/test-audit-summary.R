test_that("sm_audit_summary rejects non-corpus input", {
  expect_error(sm_audit_summary(list(a = 1)), "sm_corpus")
})

test_that("sm_audit_summary runs all audits and builds overview", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 1)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, call) {
      tibble::tibble(work_id = character(), funder_name = character(),
                     funder_doi = character())
    }
  )
  res <- suppressMessages(sm_audit_summary(corpus))
  expect_s3_class(res, "sm_audit_summary")
  expect_s3_class(res$geographic, "sm_audit_geographic")
  expect_s3_class(res$gender, "sm_audit_gender")
  expect_s3_class(res$funding, "sm_audit_funding")
  expect_s3_class(res$oa, "sm_audit_oa")
  # Overview has one row per audit
  expect_equal(nrow(res$overview), 4L)
  expect_equal(res$overview$audit,
               c("geographic", "gender", "funding", "open_access"))
  expect_true(all(c("audit", "coverage", "top_finding") %in%
                    names(res$overview)))
  # Gender audit run with manual method
  expect_equal(res$gender$method, "manual")
})

test_that("sm_audit_summary reuses pre-computed audits", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 2)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, call) {
      tibble::tibble(work_id = character(), funder_name = character(),
                     funder_doi = character())
    }
  )
  oa <- sm_audit_oa(corpus)
  geo <- sm_audit_geographic(corpus)
  res <- suppressMessages(sm_audit_summary(corpus, oa, geo))
  # The exact same objects should be reused (identical)
  expect_identical(res$oa, oa)
  expect_identical(res$geographic, geo)
})

test_that("sm_audit_summary overview reflects oa pct_open in top_finding", {
  corpus <- sm_example_corpus(n_works = 25, n_authors = 12,
                              with_embeddings = FALSE, seed = 3)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, call) {
      tibble::tibble(work_id = character(), funder_name = character(),
                     funder_doi = character())
    }
  )
  res <- suppressMessages(sm_audit_summary(corpus))
  oa_row <- res$overview[res$overview$audit == "open_access", ]
  expect_match(oa_row$top_finding, "open access")
})

test_that(".extract_audit finds matching class in dots", {
  oa <- sm_audit_oa(sm_example_corpus(n_works = 5, with_embeddings = FALSE,
                                      seed = 4))
  found <- .extract_audit(list(1, "x", oa), "sm_audit_oa")
  expect_identical(found, oa)
  expect_null(.extract_audit(list(1, "x"), "sm_audit_oa"))
})

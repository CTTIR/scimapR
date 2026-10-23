test_that("sm_audit_summary rejects non-corpus input", {
  local_http_env()
  expect_error(sm_audit_summary(list(a = 1)), "sm_corpus")
})

test_that("sm_audit_summary runs all audits and builds overview", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 1)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      funding_answer(tibble::tibble(work_id = character(),
                                    funder_name = character(),
                                    funder_doi = character()), works)
    }
  )
  res <- suppressMessages(sm_audit_summary(corpus, online = TRUE))
  expect_s3_class(res, "sm_audit_summary")
  expect_s3_class(res$geographic, "sm_audit_geographic")
  expect_s3_class(res$gender, "sm_audit_gender")
  expect_s3_class(res$funding, "sm_audit_funding")
  expect_identical(res$funding$source, "crossref")
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
  local_http_env()
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 2)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      funding_answer(tibble::tibble(work_id = character(),
                                    funder_name = character(),
                                    funder_doi = character()), works)
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
  local_http_env()
  corpus <- sm_example_corpus(n_works = 25, n_authors = 12,
                              with_embeddings = FALSE, seed = 3)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      funding_answer(tibble::tibble(work_id = character(),
                                    funder_name = character(),
                                    funder_doi = character()), works)
    }
  )
  res <- suppressMessages(sm_audit_summary(corpus))
  oa_row <- res$overview[res$overview$audit == "open_access", ]
  expect_match(oa_row$top_finding, "open access")
})

test_that("sm_audit_summary() sends no web request unless online = TRUE", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 5)
  n_calls <- 0L
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      n_calls <<- n_calls + 1L
      funding_answer(tibble::tibble(work_id = character(),
                                    funder_name = character(),
                                    funder_doi = character()), works)
    }
  )
  expect_message(res <- sm_audit_summary(corpus), "online = TRUE")
  expect_identical(n_calls, 0L)
  expect_s3_class(res$funding, "sm_audit_funding")
  expect_identical(res$funding$source, "none")
  expect_identical(nrow(res$funding$funders), 0L)
  expect_identical(res$funding$n_works_total, nrow(corpus$works))
  expect_true(is.na(res$funding$coverage))
  funding_row <- res$overview[res$overview$audit == "funding", ]
  expect_true(is.na(funding_row$coverage))
  expect_match(funding_row$top_finding, "not run")
  expect_false(anyNA(res$overview$coverage[res$overview$audit != "funding"]))

  res_online <- suppressMessages(sm_audit_summary(corpus, online = TRUE))
  expect_identical(n_calls, 1L)
  expect_identical(res_online$funding$source, "crossref")
  overview <- res_online$overview
  expect_identical(overview$coverage[overview$audit == "funding"], 0)
})

test_that("sm_audit_summary() uses a precomputed funding audit offline", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 6)
  funding <- structure(
    list(
      funders = tibble::tibble(funder_name = "Example Research Council",
                               funder_doi = "10.9999/funder.1",
                               n_works = 4L, pct = 20),
      coverage = 0.2, n_works_total = 20L, n_works_funded = 4L,
      source = "crossref"
    ),
    class = "sm_audit_funding"
  )
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      stop("no Crossref request expected")
    }
  )
  res <- suppressMessages(sm_audit_summary(corpus, funding))
  expect_identical(res$funding, funding)
  funding_row <- res$overview[res$overview$audit == "funding", ]
  expect_identical(funding_row$coverage, 0.2)
  expect_match(funding_row$top_finding, "Example Research Council")
})

test_that("sm_audit_summary() validates online", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE, seed = 7)
  expect_error(sm_audit_summary(corpus, online = NA), "online")
  expect_error(sm_audit_summary(corpus, online = "yes"), "online")
})

test_that(".extract_audit finds matching class in dots", {
  local_http_env()
  oa <- sm_audit_oa(sm_example_corpus(n_works = 5, with_embeddings = FALSE,
                                      seed = 4))
  found <- .extract_audit(list(1, "x", oa), "sm_audit_oa")
  expect_identical(found, oa)
  expect_null(.extract_audit(list(1, "x"), "sm_audit_oa"))
})

test_that("the sm_audit_summary() examples send no Crossref request", {
  local_http_env()
  # R CMD check --as-cran runs \donttest code; the example used to run the
  # default Crossref funding audit on the 200-work example corpus.
  exprs <- rd_example_exprs("sm_audit_summary")
  n_dois <- 0L
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      n_dois <<- n_dois + sum(!is.na(works$doi) & nzchar(works$doi))
      funding_answer(tibble::tibble(work_id = character(),
                                    funder_name = character(),
                                    funder_doi = character()), works)
    }
  )
  env <- run_example_exprs(exprs)
  expect_s3_class(env$summary_audit, "sm_audit_summary")
  expect_identical(n_dois, 0L)
})

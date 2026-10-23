test_that("sm_audit_funding rejects non-corpus input", {
  local_http_env()
  expect_error(sm_audit_funding(list(a = 1)), "sm_corpus")
  expect_error(sm_audit_funding(42), "sm_corpus")
})

test_that("sm_audit_funding validates the source argument", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 1)
  expect_error(sm_audit_funding(corpus, source = "bogus"))
})

test_that("sm_audit_funding returns empty result for empty corpus", {
  local_http_env()
  corpus <- make_empty_corpus()
  res <- sm_audit_funding(corpus, source = "crossref")
  expect_s3_class(res, "sm_audit_funding")
  expect_equal(res$n_works_total, 0L)
  expect_equal(res$n_works_funded, 0L)
  expect_equal(res$coverage, 0.0)
  expect_equal(nrow(res$funders), 0L)
  expect_equal(res$source, "crossref")
})

test_that("native funding requests work without optional client packages", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE)
  local_mocked_bindings(is_installed = function(...) FALSE, .package = "rlang")
  calls <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    if (grepl("crossref", req$url)) {
      items <- lapply(corpus$works$doi, function(doi) list(DOI = doi))
      return(http_response(list(message = list(items = items,
                                               `total-results` = 8L))))
    }
    records <- lapply(corpus$works$openalex_id, function(id) {
      list(id = id, funders = list(), awards = list())
    })
    http_response(list(results = records))
  }, .package = "httr2")
  for (source in c("crossref", "openalex")) {
    res <- sm_audit_funding(corpus, source, api_key = "", mailto = "")
    expect_identical(res$n_works_checked, 8L)
    expect_equal(res$coverage, 0)
    expect_identical(res$n_works_failed, 0L)
  }
  expect_identical(calls, 2L)
})

test_that("sm_audit_funding aggregates funder data correctly", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 4)
  # Mock the crossref fetcher to return deterministic funder rows.
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      funding_answer(tibble::tibble(
        work_id = c(works$work_id[1], works$work_id[1], works$work_id[2]),
        funder_name = c("NIH", "NSF", "NIH"),
        funder_doi = c("10.13039/nih", "10.13039/nsf", "10.13039/nih")
      ), works)
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
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE, seed = 5)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      funding_answer(tibble::tibble(
        work_id = character(), funder_name = character(),
        funder_doi = character()
      ), works)
    }
  )
  expect_message(sm_audit_funding(corpus, source = "crossref"),
                 "No funding data")
  res <- suppressMessages(sm_audit_funding(corpus, source = "crossref"))
  expect_equal(res$n_works_total, 5L)
  expect_equal(res$n_works_funded, 0L)
})

test_that("the sm_audit_funding() examples send no Crossref request", {
  local_http_env()
  # R CMD check --as-cran runs \donttest code; the examples used to send one
  # Crossref request per DOI of the 200-work example corpus.
  exprs <- rd_example_exprs("sm_audit_funding")
  n_calls <- 0L
  n_dois <- 0L
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, ...) {
      n_calls <<- n_calls + 1L
      n_dois <<- n_dois + sum(!is.na(works$doi) & nzchar(works$doi))
      funding_answer(tibble::tibble(work_id = character(),
                                    funder_name = character(),
                                    funder_doi = character()), works)
    }
  )
  run_example_exprs(exprs)
  expect_gt(n_calls, 0L)
  expect_identical(n_dois, 0L)
})

test_that("funding coverage excludes failed batches and missing identifiers", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 41, n_authors = 3)
  corpus$works$doi <- c(paste0("10.9999/funding", 1:40), NA_character_)
  calls <- 0L
  local_mocked_bindings(.sm_sleep = function(seconds) NULL)
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    if (calls > 1L) return(http_response(status = 500L))
    items <- lapply(seq_len(20L), function(i) {
      record <- list(DOI = corpus$works$doi[i])
      if (i <= 2L) record$funder <- list(list(name = "Invented Research Fund",
                                              DOI = "10.9999/funder"))
      record
    })
    http_response(list(message = list(items = items, `total-results` = 20L)))
  }, .package = "httr2")
  expect_warning(res <- sm_audit_funding(corpus, api_key = "", mailto = ""),
                 class = "scimapR_funding_lookup_failed")
  expect_identical(calls, 4L)
  expect_identical(res$n_works_checked, 20L)
  expect_identical(res$n_works_failed, 20L)
  expect_identical(res$n_works_no_id, 1L)
  expect_equal(res$coverage, 0.1)
  expect_equal(res$funders$pct, 10)
})

test_that("all failed funding lookups are distinct from an audit not run", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 60, n_authors = 3)
  calls <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    http_response(status = 429L, headers = list(`Retry-After` = "3600"))
  }, .package = "httr2")
  expect_warning(res <- sm_audit_funding(corpus, api_key = "", mailto = ""),
                 class = "scimapR_funding_lookup_failed")
  expect_identical(calls, 1L)
  expect_identical(res$n_works_failed, 60L)
  expect_true(is.na(res$coverage))
  audit <- suppressMessages(sm_audit_summary(corpus, res))
  finding <- audit$overview$top_finding[audit$overview$audit == "funding"]
  expect_identical(finding, "no work could be checked")
})

test_that("funding reports missing identifiers without a request", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$works$doi <- corpus$works$openalex_id <- NA_character_
  local_mocked_bindings(req_perform = function(...) stop("unexpected request"),
                        .package = "httr2")
  for (source in c("crossref", "openalex")) {
    expect_message(res <- sm_audit_funding(corpus, source, api_key = "",
                                           mailto = ""),
                   "identifiers")
    expect_identical(res$n_works_no_id, 3L)
    expect_identical(res$n_works_checked, 0L)
    expect_true(is.na(res$coverage))
  }
})

test_that("funding accepts current and legacy fields and DOI fallback", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$works$openalex_id <- c("W99999019", "W2", NA_character_)
  corpus$works$doi <- c("10.9999/funding19", "10.9999/legacy", "10.9999/doi")
  fixture <- jsonlite::fromJSON(test_path("fixtures", "openalex-funding.json"),
                                simplifyVector = FALSE)
  local_mocked_bindings(req_perform = function(req, ...) {
    headers <- httr2::req_get_headers(req, redacted = "reveal")
    expect_identical(headers$Authorization, "Bearer FUNDING-KEY")
    filter <- httr2::url_parse(req$url)$query$filter
    records <- if (startsWith(filter, "doi:")) {
      list(list(doi = "10.9999/doi", funders = list()))
    } else {
      list(fixture, list(id = "W2", grants = list(list(
        funder = "https://openalex.org/F99999020",
        funder_display_name = "Invented Legacy Fund"
      ))))
    }
    http_response(list(results = records))
  }, .package = "httr2")
  res <- sm_audit_funding(corpus, source = "openalex", api_key = "FUNDING-KEY")
  expect_identical(res$n_works_checked, 3L)
  expect_identical(res$n_works_funded, 2L)
  expect_equal(res$coverage, 0.667)
  expect_setequal(res$funders$funder_name,
                  c("Invented Research Fund", "Invented Legacy Fund"))
})

test_that("awards use funder names and ids, never award titles", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1)
  corpus$works$openalex_id <- "W1"
  funder <- list(id = "F1", display_name = "Fund A")
  record <- list(id = "W1", funders = list(funder),
                 awards = list(list(id = "G1", display_name = "Award A",
                                    funder_id = "F1"),
                               list(id = "G2", display_name = "Award B")))
  local_mocked_bindings(req_perform = function(...) {
    http_response(list(results = list(record)))
  }, .package = "httr2")
  out <- sm_audit_funding(corpus, source = "openalex", api_key = "")
  expect_identical(out$funders$funder_name, "Fund A")
  expect_identical(out$funders$n_works, 1L)
})

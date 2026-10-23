# Tests for R/enrich-retraction.R (sm_enrich_retraction).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_retraction rejects a non-corpus input", {
  local_http_env()
  expect_error(sm_enrich_retraction(list()), class = "rlang_error")
})

test_that("retraction check short-circuits when no DOIs present", {
  local_http_env()
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

test_that("retraction checks keep answers and stop on rate limits", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 60, n_authors = 3)
  corpus$works$doi <- paste0("10.9999/retract", 1:60)
  corpus$works$is_retracted <- FALSE
  oa_calls <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    query <- httr2::url_parse(req$url)$query
    if (grepl("openalex", req$url)) {
      oa_calls <<- oa_calls + 1L
      expect_null(query$mailto)
      expect_false(grepl("is_retracted:true", query$filter, fixed = TRUE))
      headers <- httr2::req_get_headers(req, redacted = "reveal")
      expect_identical(headers$Authorization, "Bearer TEST-KEY")
      if (oa_calls == 2L) return(http_response(status = 429L))
      records <- lapply(corpus$works$doi[1:49], function(doi) {
        list(doi = doi, is_retracted = doi == corpus$works$doi[2])
      })
      return(http_response(list(results = records)))
    }
    expect_identical(query$mailto, "lab@example.org")
    expect_match(query$filter, "updates:10.9999/", fixed = TRUE)
    expect_identical(query$rows, "100")
    http_response(list(message = list(items = list(), `total-results` = 0L)))
  }, .package = "httr2")
  warn <- expect_warning(
    out <- sm_enrich_retraction(corpus, verbose = FALSE,
                                api_key = "TEST-KEY",
                                mailto = "lab@example.org"),
    class = "scimapR_retraction_unchecked"
  )
  expect_identical(oa_calls, 2L)
  expect_length(warn$work_ids, 10L)
  expect_match(conditionMessage(warn), "OPENALEX_API_KEY", fixed = TRUE)
  expect_false(grepl("TEST-KEY", conditionMessage(warn), fixed = TRUE))
  rows <- out$provenance[out$provenance$source == "retraction_check", ]
  expect_setequal(rows$work_id, corpus$works$work_id[1:49])
  expect_identical(which(out$works$is_retracted), 2L)
})

test_that("Crossref notices flag only the named retraction targets", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$works$is_retracted <- FALSE
  failed <- FALSE
  local_mocked_bindings(req_perform = function(req, ...) {
    if (grepl("openalex", req$url)) {
      return(http_response(list(results = list(list(doi = corpus$works$doi[1],
                                                    is_retracted = FALSE)))))
    }
    query <- httr2::url_parse(req$url)$query
    expect_match(query$filter, "updates:", fixed = TRUE)
    if (failed) return(http_response(status = 400L))
    http_response(list(message = list(`total-results` = 1L, items = list(list(
      `update-to` = list(list(DOI = toupper(corpus$works$doi[2]),
                              type = "Retraction"),
                         list(DOI = corpus$works$doi[3], type = "correction"))
    )))))
  }, .package = "httr2")
  out <- sm_enrich_retraction(corpus, verbose = FALSE, api_key = "",
                              mailto = "")
  expect_identical(which(out$works$is_retracted), 2L)
  rows <- out$provenance[out$provenance$source == "retraction_check", ]
  expect_setequal(rows$work_id, corpus$works$work_id[1:2])
  failed <- TRUE
  expect_warning(out <- sm_enrich_retraction(corpus, verbose = FALSE,
                                             api_key = "", mailto = ""),
                 class = "scimapR_retraction_unchecked")
  expect_false(any(out$works$is_retracted))
})

test_that("all failed retraction requests abort before Crossref", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3)
  calls <- character()
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- c(calls, req$url)
    stop("api down")
  }, .package = "httr2")
  expect_error(sm_enrich_retraction(corpus, verbose = FALSE, api_key = ""),
               class = "scimapR_retraction_failed")
  expect_length(calls, 1L)
  expect_true(all(grepl("openalex", calls)))
})

test_that("empty retraction answers do not claim checks or clear flags", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$works$is_retracted[1] <- TRUE
  local_mocked_bindings(req_perform = function(...) {
    http_response(list(
      results = list(), message = list(items = list(), `total-results` = 0L)
    ))
  }, .package = "httr2")
  out <- sm_enrich_retraction(corpus, verbose = FALSE, api_key = "",
                              mailto = "")
  expect_identical(out, corpus)
})

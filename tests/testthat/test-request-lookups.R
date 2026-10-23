test_that("OpenAlex batches match normalized identifiers and stop at a limit", {
  local_http_env()
  seen <- list()
  local_mocked_bindings(.sm_sleep = function(seconds) NULL)
  local_mocked_bindings(req_perform = function(req, ...) {
    q <- httr2::url_parse(req$url)$query
    seen[[length(seen) + 1L]] <<- q
    if (length(seen) == 2L) return(http_response(status = 429L))
    http_response(list(results = list(list(doi = "https://doi.org/10.9999/A1")),
                       meta = list(next_cursor = NULL)))
  }, .package = "httr2")
  ids <- paste0("10.9999/a", 1:110)
  run <- .openalex_lookup(ids, select = "doi,is_retracted", api_key = "")
  expect_length(seen, 2L)
  expect_identical(seen[[1]]$per_page, "100")
  expect_length(run$records, 1L)
  expect_setequal(run$failed, ids[51:110])
  expect_s3_class(run$condition, "scimapR_rate_limited")
  expect_identical(run$records[[1]]$doi, "10.9999/a1")
})

test_that("Crossref lookups page filters and continue after failed batches", {
  local_http_env()
  seen <- list()
  local_mocked_bindings(.sm_sleep = function(seconds) NULL)
  local_mocked_bindings(req_perform = function(req, ...) {
    q <- httr2::url_parse(req$url)$query
    seen[[length(seen) + 1L]] <<- q
    if (grepl("a21", q$filter, fixed = TRUE)) {
      return(http_response(status = 400L))
    }
    suffix <- if (q$cursor == "*") "a1" else "a2"
    http_response(list(message = list(
      items = list(list(DOI = paste0("https://doi.org/10.9999/", suffix))),
      `total-results` = 2L, `next-cursor` = "next"
    )))
  }, .package = "httr2")
  ids <- paste0("10.9999/a", 1:25)
  run <- .crossref_lookup(ids, filter_name = "updates", rows = 1L,
                          mailto = "lab@example.org")
  expect_length(seen, 3L)
  expect_match(seen[[1]]$filter, "updates:10.9999/a1,updates:10.9999/a2",
               fixed = TRUE)
  expect_identical(seen[[2]]$cursor, "next")
  expect_identical(seen[[1]]$mailto, "lab@example.org")
  expect_length(run$records, 2L)
  expect_identical(run$records[[1]]$DOI, "10.9999/a1")
  expect_identical(run$failed, ids[21:25])
  expect_s3_class(run$condition, "scimapR_request_failed")
})

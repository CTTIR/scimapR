test_that("transient HTTP failures retry with bounded backoff", {
  local_http_env()
  calls <- 0L
  waits <- numeric()
  local_mocked_bindings(.sm_sleep = function(seconds) {
    waits <<- c(waits,
                seconds)
  })
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    http_response(status = if (calls < 3L) 503L else 200L)
  }, .package = "httr2")
  expect_s3_class(.sm_http_perform(httr2::request("https://example.org"),
                                   "Example"), "httr2_response")
  expect_identical(calls, 3L)
  expect_equal(waits, c(1, 2))
  calls <- 0L
  err <- expect_error(.sm_http_perform(httr2::request("https://example.org"),
                                       "Example", max_tries = 2L),
                      class = "scimapR_http_error")
  expect_identical(calls, 2L)
  expect_s3_class(err, "scimapR_request_failed")
  expect_identical(err$status, 503L)
})

test_that("rate limits retry only short announced waits", {
  local_http_env()
  calls <- 0L
  wait <- "1"
  sleeps <- numeric()
  local_mocked_bindings(.sm_sleep = function(seconds) {
    sleeps <<- c(sleeps, seconds)
  })
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    if (calls == 2L) return(http_response())
    http_response(status = 429L, headers = list(`retry-after` = wait))
  }, .package = "httr2")
  req <- httr2::request("https://example.org")
  .sm_http_perform(req, "Example")
  expect_identical(calls, 2L)
  expect_equal(sleeps, 1)
  for (value in c("3600", "unknown")) {
    calls <- 0L
    wait <- value
    err <- expect_error(.sm_http_perform(req, "Example"),
                        class = "scimapR_rate_limited")
    expect_identical(calls, 1L)
    expect_s3_class(err, "scimapR_request_failed")
    expect_identical(err$status, 429L)
  }
})

test_that("rate headers accept dates, epochs and hyphenated names", {
  local_http_env()
  now <- as.POSIXct("2026-10-20 18:00:00", tz = "UTC")
  before <- Sys.getlocale("LC_TIME")
  resp <- http_response(headers = list(
    `rEtRy-AfTeR` = "Wed, 21 Oct 2026 00:00:00 GMT",
    `X-Rate-Limit-Remaining` = "0"
  ))
  info <- .sm_rate_limit_info(resp, now)
  expect_equal(info$retry_after, 21600)
  expect_identical(info$remaining, "0")
  expect_identical(Sys.getlocale("LC_TIME"), before)
  for (header in c("X-RateLimit-Reset", "X-Rate-Limit-Reset")) {
    resp <- http_response(headers = stats::setNames(list("60"), header))
    info <- .sm_rate_limit_info(resp, now)
    expect_equal(as.numeric(info$reset_at), as.numeric(now) + 60)
  }
  resp <- http_response(headers = list(`X-RateLimit-Reset` = "1792540800"))
  info <- .sm_rate_limit_info(resp, now)
  expect_equal(info$reset_at, as.POSIXct("2026-10-21", tz = "UTC"))
})

test_that("network errors retry but arbitrary errors do not expose secrets", {
  local_http_env()
  req <- httr2::request("https://example.org/works") |>
    httr2::req_url_query(api_key = "KEY-019", mailto = "lab@example.org") |>
    httr2::req_headers(Authorization = "Bearer AUTH-019")
  calls <- 0L
  local_mocked_bindings(.sm_sleep = function(seconds) NULL)
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    stop(paste(req$url, "KEY-019 lab@example.org Bearer AUTH-019 {T} {x}"))
  }, .package = "httr2")
  err <- expect_error(.sm_http_perform(req, "Example"),
                      class = "scimapR_network_error")
  expect_identical(calls, 1L)
  expect_true(is.na(err$status))
  expect_false(grepl("KEY-019|AUTH-019|lab@example|https://",
                     conditionMessage(err)))
  expect_match(conditionMessage(err$parent), "{T} {x}", fixed = TRUE)
  calls <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    rlang::abort("connection failed", class = "httr2_failure")
  }, .package = "httr2")
  expect_error(.sm_http_perform(req, "Example"),
               class = "scimapR_network_error")
  expect_identical(calls, 3L)
})

test_that("HTTP diagnostics preserve braces and remove request secrets", {
  local_http_env()
  req <- httr2::request("https://example.org/works") |>
    httr2::req_url_query(mailto = "lab@example.org") |>
    httr2::req_headers(Authorization = "Bearer BODY-KEY")
  local_mocked_bindings(req_perform = function(...) {
    http_response(list(error = "bad {T} {x} BODY-KEY lab@example.org"),
                  status = 400L)
  }, .package = "httr2")
  err <- expect_error(.sm_http_perform(req, "Example"),
                      class = "scimapR_http_error")
  expect_match(conditionMessage(err), "{T} {x}", fixed = TRUE)
  expect_false(grepl("BODY-KEY|lab@example", conditionMessage(err)))
})

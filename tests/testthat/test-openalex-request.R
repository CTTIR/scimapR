# Tests for R/openalex-request.R: the OpenAlex request helper shared by the
# fetchers and enrichers (offline; httr2::req_perform is mocked).

json_response <- function(body, status = 200L, headers = list()) {
  httr2::response(
    status_code = status,
    url = "https://api.openalex.org/works",
    headers = c(list(`Content-Type` = "application/json"), headers),
    body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null"))
  )
}

too_many <- function(headers = list()) {
  json_response(list(error = "Rate limit exceeded"), status = 429L,
                headers = headers)
}

test_that("the API key goes into the header and never into the URL", {
  req <- .openalex_build_request("works", list(filter = "doi:10.9999/a"),
                                 api_key = "KEY-0001", mailto = "")
  expect_false(grepl("KEY-0001", req$url, fixed = TRUE))
  expect_false(grepl("api_key", req$url, fixed = TRUE))
  expect_false(grepl("mailto", req$url, fixed = TRUE))
  skip_if_not(exists("req_get_headers", asNamespace("httr2")))
  headers <- httr2::req_get_headers(req, redacted = "reveal")
  expect_identical(headers$Authorization, "Bearer KEY-0001")

  no_key <- .openalex_build_request("works", list(), api_key = "",
                                    mailto = "lab@example.org")
  expect_null(httr2::req_get_headers(no_key)$Authorization)
  expect_match(no_key$url, "mailto=lab%40example.org", fixed = TRUE)
})

test_that("HTTP 429 aborts at once with the reset time and the budget", {
  calls <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      calls <<- calls + 1L
      too_many(list(`Retry-After` = "21600",
                    `X-RateLimit-Remaining-USD` = "0"))
    },
    .package = "httr2"
  )
  before <- Sys.time()
  err <- expect_error(.openalex_request("works", list(), api_key = ""),
                      class = "scimapR_openalex_rate_limit")
  expect_s3_class(err, "scimapR_openalex_error")
  expect_identical(calls, 1L)
  expect_identical(err$status, 429L)
  expect_equal(err$retry_after, 21600)
  expect_equal(as.numeric(difftime(err$reset_at, before, units = "secs")),
               21600, tolerance = 60)
  expect_identical(err$remaining, "0")
  expect_identical(err$remaining_header, "X-RateLimit-Remaining-USD")
  expect_false(err$key_set)
  msg <- conditionMessage(err)
  expect_match(msg, "HTTP 429")
  expect_match(msg, "resets at [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8} UTC")
  expect_match(msg, "X-RateLimit-Remaining-USD", fixed = TRUE)
  expect_match(msg, "OPENALEX_API_KEY", fixed = TRUE)
})

test_that("HTTP 429 with a key says the budget of the key is spent", {
  local_mocked_bindings(
    req_perform = function(req, ...) {
      too_many(list(`x-ratelimit-reset` = "3600",
                    `x-ratelimit-remaining` = "0"))
    },
    .package = "httr2"
  )
  err <- expect_error(.openalex_request("works", list(), api_key = "KEY-0002"),
                      class = "scimapR_openalex_rate_limit")
  expect_true(err$key_set)
  expect_true(is.na(err$retry_after))
  expect_false(is.na(err$reset_at))
  expect_identical(err$remaining_header, "X-RateLimit-Remaining")
  msg <- conditionMessage(err)
  expect_match(msg, "An API key was sent", fixed = TRUE)
  expect_false(grepl("KEY-0002", msg, fixed = TRUE))
})

test_that("rate-limit headers are read in their documented forms", {
  now <- as.POSIXct("2026-10-20 18:00:00", tz = "UTC")
  date <- too_many(list(`Retry-After` = "Wed, 21 Oct 2026 00:00:00 GMT"))
  info <- .openalex_rate_info(date, now = now)
  expect_equal(info$retry_after, 6 * 3600)
  expect_equal(info$reset_at, as.POSIXct("2026-10-21", tz = "UTC"))

  epoch <- too_many(list(`X-RateLimit-Reset` = "1792540800"))
  info <- .openalex_rate_info(epoch, now = now)
  expect_true(is.na(info$retry_after))
  expect_equal(info$reset_at, as.POSIXct("2026-10-21", tz = "UTC"))

  bare <- .openalex_rate_info(too_many(), now = now)
  expect_true(is.na(bare$reset_at))
  expect_true(is.na(bare$remaining))
  expect_true(is.na(.openalex_wait_seconds("soon", now)))
  expect_true(is.na(.http_date_seconds("Mittwoch, 21 Okt 2026 00:00:00 GMT")))
})

test_that("a 429 without headers still names the key setting", {
  local_mocked_bindings(
    req_perform = function(req, ...) too_many(),
    .package = "httr2"
  )
  err <- expect_error(.openalex_request("works"),
                      class = "scimapR_openalex_rate_limit")
  expect_match(conditionMessage(err), "did not say when", fixed = TRUE)
  expect_match(conditionMessage(err), "OPENALEX_API_KEY", fixed = TRUE)
})

test_that("a short Retry-After (the per-second limit) is retried once", {
  calls <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      calls <<- calls + 1L
      if (calls == 1L) {
        too_many(list(`Retry-After` = "0"))
      } else {
        json_response(list(meta = list(count = 1L), results = list(
          list(id = "https://openalex.org/W9999300001")
        )))
      }
    },
    .package = "httr2"
  )
  body <- .openalex_request("works")
  expect_identical(calls, 2L)
  expect_length(body$results, 1L)

  # a second short 429 in a row aborts
  calls <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      calls <<- calls + 1L
      too_many(list(`Retry-After` = "0"))
    },
    .package = "httr2"
  )
  expect_error(.openalex_request("works"),
               class = "scimapR_openalex_rate_limit")
  expect_identical(calls, 2L)
})

test_that("other failures abort with their status, without the query", {
  local_mocked_bindings(
    req_perform = function(req, ...) {
      json_response(list(error = "Internal"), status = 500L)
    },
    .package = "httr2"
  )
  err <- expect_error(.openalex_request("works"),
                      class = "scimapR_openalex_failed")
  expect_identical(err$status, 500L)
  expect_match(conditionMessage(err), "HTTP 500", fixed = TRUE)

  local_mocked_bindings(
    req_perform = function(req, ...) {
      stop("Could not reach ", req$url)
    },
    .package = "httr2"
  )
  err <- expect_error(
    .openalex_request("works", list(filter = "doi:10.9999/secret.1"),
                      mailto = "lab@example.org"),
    class = "scimapR_openalex_failed"
  )
  expect_true(is.na(err$status))
  msg <- conditionMessage(err)
  expect_match(msg, "https://api.openalex.org/works", fixed = TRUE)
  expect_false(grepl("10.9999", msg, fixed = TRUE))
  expect_false(grepl("example.org", msg, fixed = TRUE))
})

test_that("cursor paging collects every page", {
  pages <- list(
    `*` = list(meta = list(next_cursor = "page2"),
               results = list(list(id = "W1"), list(id = "W2"))),
    page2 = list(meta = list(next_cursor = NULL),
                 results = list(list(id = "W3")))
  )
  seen <- character()
  local_mocked_bindings(
    req_perform = function(req, ...) {
      cursor <- httr2::url_parse(req$url)$query$cursor
      seen <<- c(seen, cursor)
      json_response(pages[[cursor]])
    },
    .package = "httr2"
  )
  out <- .openalex_fetch_all("works", list(filter = "doi:10.9999/a"))
  expect_identical(vapply(out, function(x) x$id, character(1)),
                   c("W1", "W2", "W3"))
  expect_identical(seen, c("*", "page2"))
})

test_that("batches count failures or stop, and a rate limit always stops", {
  fetch <- function(b) {
    if (b == "bad") {
      cli::cli_abort("failed", class = c("scimapR_openalex_failed",
                                         "scimapR_openalex_error"),
                     status = 503L)
    }
    if (b == "limit") {
      .openalex_abort_rate_limit(list(), key_set = FALSE)
    }
    list(b)
  }
  run <- .openalex_batches(list("a", "bad", "c"), fetch, on_failure = "skip")
  expect_identical(run$failed, 2L)
  expect_identical(run$n_failed, 1L)
  expect_identical(run$n_batches, 3L)
  expect_null(run$results[[2]])
  expect_identical(run$results[[3]], list("c"))

  err <- expect_error(.openalex_batches(list("a", "bad"), fetch),
                      class = "scimapR_openalex_failed")
  expect_identical(err$n_done, 1L)
  expect_match(conditionMessage(err), "batch 2 of 2 (HTTP 503)", fixed = TRUE)

  err <- expect_error(
    .openalex_batches(list("a", "b", "limit"), fetch, on_failure = "skip",
                      context = "Nothing was joined."),
    class = "scimapR_openalex_rate_limit"
  )
  expect_identical(err$n_done, 2L)
  expect_identical(err$n_batches, 3L)
  expect_identical(err$n_fetched, 2L)
  expect_match(conditionMessage(err), "2 of 3 batches had been fetched",
               fixed = TRUE)
  expect_match(conditionMessage(err), "Nothing was joined.", fixed = TRUE)
})

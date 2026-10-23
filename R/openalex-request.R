# OpenAlex requests shared by the fetchers and enrichers: the API key, the
# rate-limit (HTTP 429) abort and the count of failed batches.

#' Root of the OpenAlex API
#' @noRd
.openalex_api_url <- "https://api.openalex.org"

#' Longest `Retry-After` (seconds) that one request waits out
#'
#' OpenAlex also answers HTTP 429 when more than ten requests arrive in a
#' second; such a short wait is retried once. A longer one (the daily
#' budget, which resets at midnight UTC) aborts at once.
#' @noRd
.openalex_short_wait <- 2

#' Build one OpenAlex API request
#'
#' A GET request to `endpoint` (such as `"works"`) with the query parameters
#' in `query`. The API key goes into the `Authorization: Bearer` header,
#' never into the URL; `mailto`, when given, is sent as the `mailto` query
#' parameter. HTTP errors are not turned into R errors here, so that
#' `.openalex_request()` can read the status and the headers.
#'
#' @param endpoint Path below the API root, such as `"works"`.
#' @param query Named list of query parameters (`NULL` entries are left
#'   out).
#' @param api_key API key, or `""` for none.
#' @param mailto Contact address, or `""` for none.
#' @return An httr2 request.
#' @noRd
.openalex_build_request <- function(endpoint, query = list(), api_key = "",
                                    mailto = "") {
  api_key <- .openalex_setting(api_key)
  mailto <- .openalex_setting(mailto)
  if (nzchar(mailto)) query$mailto <- mailto
  req <- httr2::request(paste0(.openalex_api_url, "/", endpoint)) |>
    httr2::req_url_query(!!!query) |>
    httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_throttle(rate = 10 / 1)
  if (nzchar(api_key)) {
    req <- httr2::req_headers(req, Authorization = paste("Bearer", api_key))
  }
  req
}

#' Perform one OpenAlex API request
#'
#' Sends the request of `.openalex_build_request()`. An HTTP 429 with a
#' `Retry-After` of at most `.openalex_short_wait` seconds is retried once;
#' any other 429 aborts at once (`.openalex_abort_rate_limit()`, class
#' `scimapR_openalex_rate_limit`), and every other failure aborts with
#' class `scimapR_openalex_failed` (field `status`, `NA` without a
#' response). Both classes inherit from `scimapR_openalex_error`. No
#' message contains the key, the mailto address or a query string.
#'
#' @inheritParams .openalex_build_request
#' @param call Caller environment for the conditions.
#' @return The parsed JSON body (a list).
#' @noRd
.openalex_request <- function(endpoint, query = list(), api_key = "",
                              mailto = "", call = rlang::caller_env()) {
  api_key <- .openalex_setting(api_key)
  req <- .openalex_build_request(endpoint, query, api_key = api_key,
                                 mailto = mailto)
  body <- tryCatch(
    .sm_http_read(req, "OpenAlex", max_tries = 2L,
                  max_wait = .openalex_short_wait, call = call),
    scimapR_request_failed = function(cnd) {
      if (inherits(cnd, "scimapR_rate_limited")) {
        .openalex_abort_rate_limit(cnd, key_set = nzchar(api_key), call = call)
      }
      cli::cli_abort(
        "OpenAlex API request failed.",
        class = c("scimapR_openalex_failed", "scimapR_openalex_error",
                  class(cnd)[startsWith(class(cnd), "scimapR_")]),
        status = cnd$status, service = "OpenAlex",
        retry_after = cnd$retry_after, reset_at = cnd$reset_at,
        remaining = cnd$remaining, parent = cnd, call = call
      )
    }
  )
  body
}

#' A failure message without query strings and without the mailto address
#'
#' Query strings carry the filters (the identifiers asked for) and the
#' mailto address, which messages should not repeat.
#' @noRd
.openalex_scrub <- function(msg, mailto = "") {
  msg <- gsub("(https?://[^?[:space:]]*)\\?[^[:space:]]*", "\\1", msg)
  if (nzchar(mailto)) msg <- gsub(mailto, "<mailto>", msg, fixed = TRUE)
  msg
}

#' A key or address setting as one string, `""` when unset
#' @noRd
.openalex_setting <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return("")
  trimws(as.character(x))
}

#' Fetch every page of one OpenAlex query (cursor paging)
#'
#' @param per_page Results per page (OpenAlex allows up to 100 here).
#' @param max_n Stop once this many results are in.
#' @inheritParams .openalex_request
#' @return The records of all pages (a list).
#' @noRd
.openalex_fetch_all <- function(endpoint, query = list(), per_page = 100L,
                                max_n = Inf, api_key = "", mailto = "",
                                call = rlang::caller_env()) {
  out <- list()
  cursor <- "*"
  repeat {
    page <- c(query, list(per_page = per_page, cursor = cursor))
    body <- .openalex_request(endpoint, page, api_key = api_key,
                              mailto = mailto, call = call)
    results <- body[["results"]] %||% list()
    out <- c(out, results)
    cursor <- body[["meta"]][["next_cursor"]]
    if (length(results) == 0L || is.null(cursor) || length(out) >= max_n) {
      break
    }
  }
  out
}

#' Run OpenAlex requests batch by batch and count the failed batches
#'
#' A rate limit (HTTP 429) always aborts at once, whatever `on_failure`
#' says, with the number of batches (`n_done`) and records (`n_fetched`)
#' fetched before it. Any other failed
#' batch aborts too with `on_failure = "abort"`; with `"skip"` it is left
#' out and counted, so the caller can report what it could not check.
#'
#' @param batches A list, one element per batch.
#' @param fetch A function of one batch that returns its records.
#' @param on_failure `"abort"` or `"skip"`.
#' @param context Plain-text lines added to an abort, such as what happens
#'   to the records fetched so far.
#' @param call Caller environment for the conditions.
#' @return A list: `results` (along `batches`, `NULL` for a failed batch),
#'   `failed` (the indices of the failed batches), `n_failed` and
#'   `n_batches`.
#' @noRd
.openalex_batches <- function(batches, fetch, on_failure = c("abort", "skip"),
                              context = character(),
                              call = rlang::caller_env(),
                              on_rate_limit = c("abort", "return")) {
  on_failure <- rlang::arg_match(on_failure)
  on_rate_limit <- rlang::arg_match(on_rate_limit)
  n <- length(batches)
  results <- vector("list", n)
  failed <- integer()
  condition <- NULL
  for (i in seq_len(n)) {
    done <- sprintf("%d of %d batch%s had been fetched.", i - 1L, n,
                    if (n == 1L) "" else "es")
    results[i] <- list(tryCatch(
      fetch(batches[[i]]),
      scimapR_openalex_rate_limit = function(cnd) {
        if (on_rate_limit == "return") {
          failed <<- c(failed, seq.int(i, n))
          condition <<- cnd
          return(NULL)
        }
        .openalex_abort_rate_limit(cnd, key_set = cnd$key_set,
                                   context = c(done, context),
                                   n_done = i - 1L, n_batches = n,
                                   n_fetched = sum(lengths(results)),
                                   call = call)
      },
      scimapR_openalex_failed = function(cnd) {
        if (on_failure == "skip") {
          failed <<- c(failed, i)
          condition <<- cnd
          return(NULL)
        }
        status <- if (is.na(cnd$status)) {
          "no response"
        } else {
          paste("HTTP", cnd$status)
        }
        cli::cli_abort(
          c(sprintf("OpenAlex API request failed for batch %d of %d (%s).",
                    i, n, status),
            stats::setNames(.sm_cli_escape(c(done, context)),
                            rep("i", length(c(done, context))))),
          class = c("scimapR_openalex_failed", "scimapR_openalex_error",
                    "scimapR_request_failed"),
          status = cnd$status, n_done = i - 1L, n_batches = n, call = call
        )
      }
    ))
    if (inherits(condition, "scimapR_rate_limited")) break
  }
  list(results = results, failed = failed, n_failed = length(failed),
       n_batches = n, condition = condition)
}

#' Rate-limit headers of an OpenAlex HTTP 429 response
#'
#' Reads `Retry-After` (seconds or an HTTP date), `X-RateLimit-Reset`
#' (seconds until the reset, or an epoch time) and the remaining budget,
#' `X-RateLimit-Remaining-USD` before `X-RateLimit-Remaining`. Header
#' names are matched in any case and every header may be absent.
#' @return A list: `retry_after` (seconds, `NA` when not given), `reset_at`
#'   (POSIXct in UTC, `NA` when unknown), `remaining` and
#'   `remaining_header` (the value and the name of the budget header, `NA`
#'   when absent).
#' @noRd
.openalex_rate_info <- function(resp, now = Sys.time()) {
  .sm_rate_limit_info(resp, now)
}

.openalex_wait_seconds <- function(value, now = Sys.time()) {
  .sm_wait_seconds(value, now)
}

#' Abort because OpenAlex answered HTTP 429
#'
#' The message names the reset time, the remaining budget that OpenAlex
#' reports and whether an API key was sent, and says where the key is set
#' (`OPENALEX_API_KEY` or `api_key`); it never contains the key itself.
#'
#' @param info A list with `retry_after`, `reset_at`, `remaining` and
#'   `remaining_header` (`.openalex_rate_info()`), or a condition of this
#'   class, whose fields are reused.
#' @param key_set Whether the request carried an API key.
#' @param context Plain-text lines to add, such as the progress of a batch
#'   run.
#' @param n_done,n_batches Batches fetched before the limit and in all.
#' @param n_fetched Records fetched before the limit.
#' @param engine The client: `"native"` reads the response headers;
#'   `"openalexR"` does not expose them.
#' @noRd
.openalex_abort_rate_limit <- function(info, key_set, context = character(),
                                       n_done = NA_integer_,
                                       n_batches = NA_integer_,
                                       n_fetched = NA_integer_,
                                       engine = "native",
                                       call = rlang::caller_env()) {
  reset_at <- info$reset_at %||% .POSIXct(NA_real_, tz = "UTC")
  remaining <- info$remaining %||% NA_character_
  remaining_header <- info$remaining_header %||% NA_character_
  reset <- if (!is.na(reset_at)) {
    hours <- max(as.numeric(difftime(reset_at, Sys.time(), units = "hours")),
                 0)
    paste0("The request budget resets at ",
           format(reset_at, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
           " (in about ", .openalex_hours(hours), ").")
  } else if (identical(engine, "openalexR")) {
    paste0("The openalexR engine does not pass on the response headers, so ",
           "the reset time and the remaining budget are unknown; the daily ",
           "budget resets at midnight UTC.")
  } else {
    "OpenAlex did not say when the request budget resets."
  }
  budget <- if (!is.na(remaining)) {
    paste0("Remaining budget reported by OpenAlex (", remaining_header,
           "): ", remaining, ".")
  }
  key <- if (isTRUE(key_set)) {
    paste0("An API key was sent (from api_key or OPENALEX_API_KEY), so its ",
           "budget is used up; wait for the reset.")
  } else {
    paste0("No API key was sent: requests without a key share one small ",
           "daily budget with everyone on the same network address. Set a ",
           "free OpenAlex API key in the OPENALEX_API_KEY environment ",
           "variable, or pass it as api_key.")
  }
  lines <- c(reset, budget, key, context)
  cli::cli_abort(
    c("OpenAlex refused the request with HTTP 429 (too many requests).",
      stats::setNames(.sm_cli_escape(lines), rep("i", length(lines)))),
    class = c("scimapR_openalex_rate_limit", "scimapR_openalex_error",
              "scimapR_rate_limited", "scimapR_request_failed"),
    service = "OpenAlex",
    status = 429L,
    retry_after = info$retry_after %||% NA_real_,
    reset_at = reset_at,
    remaining = remaining,
    remaining_header = remaining_header,
    key_set = isTRUE(key_set),
    n_done = n_done,
    n_batches = n_batches,
    n_fetched = as.integer(n_fetched),
    call = call
  )
}

#' "6 hours", "45 minutes" or "1 minute"
#' @noRd
.openalex_hours <- function(hours) {
  if (hours >= 1.5) return(paste(round(hours), "hours"))
  minutes <- max(round(hours * 60), 1)
  paste(minutes, if (minutes == 1) "minute" else "minutes")
}

# Lookup results include failed identifiers separately from absent records.
.openalex_lookup <- function(ids, by = c("doi", "openalex"), select,
                             api_key = "", call = rlang::caller_env()) {
  by <- rlang::arg_match(by)
  normalize <- if (by == "doi") .normalize_doi else .openalex_short_id
  ids <- unique(normalize(ids))
  ids <- ids[!is.na(ids) & nzchar(ids)]
  batches <- unname(split(ids, ceiling(seq_along(ids) / 50L)))
  run <- .openalex_batches(
    batches,
    function(batch) {
      .openalex_fetch_all("works", list(
        filter = paste0(by, ":", paste(batch, collapse = "|")),
        select = select
      ), per_page = 100L, api_key = api_key, call = call)
    }, on_failure = "skip", on_rate_limit = "return", call = call
  )
  records <- unlist(run$results, recursive = FALSE, use.names = FALSE)
  records <- lapply(records, function(record) {
    if (!is.null(record$doi)) record$doi <- .normalize_doi(record$doi)
    if (!is.null(record$id)) record$id <- .openalex_short_id(record$id)
    record
  })
  list(records = records, failed = as.character(unlist(batches[run$failed],
                                                       use.names = FALSE)),
       condition = run$condition)
}

# Prefer an OpenAlex identifier, with DOI fallback only when it is absent.
.openalex_work_lookup <- function(works, select, api_key, call) {
  keys <- .openalex_lookup_keys(works, by = c("openalex_id", "doi"))
  records <- vector("list", nrow(works))
  failed <- character()
  condition <- NULL
  for (type in c("openalex_id", "doi")) {
    rows <- which(keys$type == type & !is.na(keys$key))
    if (!length(rows)) next
    if (inherits(condition, "scimapR_rate_limited")) {
      failed <- c(failed, works$work_id[rows])
      next
    }
    run <- .openalex_lookup(keys$key[rows],
                            by = if (type == "doi") "doi" else "openalex",
                            select = select, api_key = api_key, call = call)
    ids <- vapply(run$records, function(record) {
      if (type == "doi") .normalize_doi(record$doi %||% NA_character_) else
        .openalex_short_id(record$id %||% NA_character_)
    }, character(1))
    hit <- match(keys$key[rows], ids)
    records[rows[!is.na(hit)]] <- run$records[hit[!is.na(hit)]]
    failed <- c(failed, works$work_id[rows[keys$key[rows] %in% run$failed]])
    condition <- run$condition %||% condition
  }
  list(records = records, failed = failed, condition = condition,
       ids = keys$key)
}

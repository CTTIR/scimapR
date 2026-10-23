# Shared requests use explicit retries so mocked responses follow the same path.
.sm_http_perform <- function(req, service, max_tries = 3L, max_wait = 60,
                             call = rlang::caller_env()) {
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  for (attempt in seq_len(max_tries)) {
    resp <- tryCatch(httr2::req_perform(req), error = identity)
    network <- inherits(resp, "error")
    info <- if (network) {
      list(retry_after = NA_real_, reset_at = .POSIXct(NA_real_, tz = "UTC"),
           remaining = NA_character_, remaining_header = NA_character_)
    } else {
      .sm_rate_limit_info(resp)
    }
    status <- if (network) NA_integer_ else httr2::resp_status(resp)
    if (!network && status < 400L) return(resp)
    wait <- info$retry_after
    if (is.na(wait) && !is.na(info$reset_at)) {
      wait <- max(as.numeric(difftime(info$reset_at, Sys.time(),
                                      units = "secs")), 0)
    }
    retry <- if (network) {
      inherits(resp, "httr2_failure")
    } else if (status == 429L) {
      !is.na(wait) && wait <= max_wait
    } else {
      status %in% c(500L, 502L, 503L, 504L)
    }
    if (retry && attempt < max_tries) {
      if (is.na(wait) || wait > max_wait) wait <- min(2^(attempt - 1L),
                                                      max_wait)
      .sm_sleep(wait)
      next
    }
    kind <- if (network) "network_error" else if (status == 429L) {
      "rate_limited"
    } else {
      "http_error"
    }
    message <- if (network) {
      "{service} request failed: no response."
    } else {
      "{service} request failed: HTTP {status}."
    }
    if (!is.na(info$reset_at)) {
      reset <- format(info$reset_at, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
      message <- c(message, "i" = paste0("The request budget resets at ",
                                         reset, "."))
    }
    if (!network) {
      detail <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
      detail <- conditionMessage(.sm_http_parent(simpleError(detail), req))
      if (nzchar(detail)) {
        message <- c(message, "i" = .sm_cli_escape(substr(detail, 1L, 500L)))
      }
    }
    parent <- if (network) .sm_http_parent(resp, req) else NULL
    cli::cli_abort(
      message, class = c(paste0("scimapR_", kind), "scimapR_request_failed"),
      service = service, status = as.integer(status),
      retry_after = info$retry_after, reset_at = info$reset_at,
      remaining = info$remaining, remaining_header = info$remaining_header,
      parent = parent, call = call
    )
  }
}

# Keep the diagnostic text and classes, without retaining requests or secrets.
.sm_http_parent <- function(cnd, req) {
  msg <- conditionMessage(cnd)
  query <- httr2::url_parse(req$url)$query
  headers <- if (exists("req_get_headers", asNamespace("httr2"))) {
    httr2::req_get_headers(req, redacted = "reveal")
  } else {
    req$headers
  }
  values <- unlist(c(query, headers), use.names = FALSE)
  values <- as.character(values[!is.na(values)])
  values <- unique(c(values, sub("^Bearer ", "", values)))
  values <- values[nzchar(values)]
  values <- values[order(nchar(values), decreasing = TRUE)]
  msg <- gsub("https?://[^[:space:]]+", "<request>", msg)
  for (value in values) msg <- gsub(value, "<redacted>", msg, fixed = TRUE)
  rlang::error_cnd(class = setdiff(class(cnd), c("error", "condition")),
                   message = msg)
}

.sm_sleep <- function(seconds) Sys.sleep(seconds)

.sm_rate_limit_info <- function(resp, now = Sys.time()) {
  header <- function(name) {
    value <- httr2::resp_header(resp, name)
    if (is.null(value) || !nzchar(trimws(value[1]))) {
      NA_character_
    } else {
      trimws(value[1])
    }
  }
  retry_after <- .sm_wait_seconds(header("Retry-After"), now)
  reset <- .sm_wait_seconds(header("X-RateLimit-Reset"), now)
  if (is.na(reset)) {
    reset <- .sm_wait_seconds(header("X-Rate-Limit-Reset"), now)
  }
  wait <- if (is.na(retry_after)) reset else retry_after
  budget <- c("X-RateLimit-Remaining-USD", "X-RateLimit-Remaining",
              "X-Rate-Limit-Remaining")
  values <- vapply(budget, header, character(1))
  hit <- which(!is.na(values))[1]
  list(
    retry_after = retry_after,
    reset_at = .POSIXct(as.numeric(now) + wait, tz = "UTC"),
    remaining = if (is.na(hit)) NA_character_ else unname(values[hit]),
    remaining_header = if (is.na(hit)) NA_character_ else budget[hit]
  )
}

#' Seconds to wait, from a header that gives seconds, an epoch time or an
#' HTTP date; `NA` when the value is missing or unreadable
#' @noRd
.sm_wait_seconds <- function(value, now = Sys.time()) {
  if (is.na(value)) return(NA_real_)
  secs <- suppressWarnings(as.numeric(value))
  if (!is.na(secs)) {
    # a large number is a point in time (epoch seconds), not a delay
    if (secs > 1e9) secs <- secs - as.numeric(now)
    return(if (is.finite(secs)) max(secs, 0) else NA_real_)
  }
  at <- .http_date_seconds(value)
  if (is.na(at)) NA_real_ else max(at - as.numeric(now), 0)
}

#' Epoch seconds of an HTTP date such as "Wed, 21 Oct 2026 00:00:00 GMT",
#' read without the locale's month names; `NA` when it does not parse
#' @noRd
.http_date_seconds <- function(x) {
  old <- Sys.getlocale("LC_TIME")
  on.exit(Sys.setlocale("LC_TIME", old), add = TRUE)
  Sys.setlocale("LC_TIME", "C")
  at <- strptime(x, "%a, %d %b %Y %H:%M:%S GMT", tz = "UTC")
  as.numeric(as.POSIXct(at))
}

# Report partial lookup failures without exposing the underlying request.
.sm_warn_unchecked <- function(work_ids, condition, class, message, call,
                               key_setting = NULL) {
  reset_at <- condition$reset_at %||% .POSIXct(NA_real_, tz = "UTC")
  lines <- c("{message}")
  if (!is.na(reset_at)) {
    reset <- format(reset_at, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
    lines <- c(lines, "i" = paste0("The request budget resets at ", reset, "."))
  }
  if (inherits(condition, "scimapR_rate_limited") && !is.null(key_setting)) {
    lines <- c(lines,
               "i" = "Check the {key_setting} setting or wait for the reset.")
  }
  cli::cli_warn(lines, class = class, work_ids = work_ids,
                reset_at = reset_at, call = call)
}

# The default remains an error; recoverable pages are attached to the condition.
.sm_fetch_abort <- function(cnd, source, collected, parse, n_expected,
                            first_message, call) {
  n_fetched <- length(collected)
  partial <- if (n_fetched) tryCatch(parse(collected), error = function(e) NULL)
  reason <- conditionMessage(cnd)
  if (!is.null(partial)) {
    partial$metadata$fetch_incomplete <- list(
      source = source, n_fetched = n_fetched, n_expected = n_expected,
      reason = reason
    )
  }
  lines <- c("{first_message}")
  if (n_fetched) {
    lines <- c(lines,
               "i" = "{n_fetched} of {n_expected} records had been fetched.")
    lines <- c(lines, "i" = if (is.null(partial)) {
      "The earlier pages could not be parsed; no partial corpus is available."
    } else {
      "Recover the earlier works with {.code rlang::last_error()$partial}."
    })
  } else if (inherits(cnd, "scimapR_openalex_rate_limit")) {
    lines <- c(lines, "i" = "0 works had been fetched; none are returned.")
  }
  classes <- class(cnd)[startsWith(class(cnd), "scimapR_")]
  if (n_fetched) classes <- c("scimapR_fetch_incomplete", classes)
  cli::cli_abort(
    lines, class = classes, partial = partial, n_fetched = n_fetched,
    service = cnd$service, status = cnd$status, retry_after = cnd$retry_after,
    reset_at = cnd$reset_at, remaining = cnd$remaining,
    remaining_header = cnd$remaining_header, key_set = cnd$key_set,
    parent = cnd, call = call
  )
}

.sm_http_read <- function(req, service, read = httr2::resp_body_json,
                          max_tries = 3L, max_wait = 60,
                          call = rlang::caller_env()) {
  tryCatch({
    resp <- .sm_http_perform(req, service, max_tries, max_wait, call)
    read(resp)
  }, error = function(cnd) {
    if (inherits(cnd, "scimapR_request_failed")) stop(cnd)
    cli::cli_abort(
      "{service} response could not be read.",
      class = c("scimapR_network_error", "scimapR_request_failed"),
      service = service, status = NA_integer_, retry_after = NA_real_,
      reset_at = .POSIXct(NA_real_, tz = "UTC"), remaining = NA_character_,
      parent = .sm_http_parent(cnd, req), call = call
    )
  })
}

.sm_fetch_page <- function(req, service, source, collected, parse, n_expected,
                           first_message, call, read = httr2::resp_body_json) {
  tryCatch(.sm_http_read(req, service, read = read, call = call),
    scimapR_request_failed = function(cnd) {
      .sm_fetch_abort(cnd, source, collected, parse, n_expected,
                      first_message, call)
    }
  )
}

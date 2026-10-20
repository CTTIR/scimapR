# Internal helpers for the timestamps stored in corpus metadata and
# certificates (build_date, last_refresh, created), and for date columns
# such as works$citations_as_of.

#' One UTC form for written timestamps (certificates)
#' @noRd
.utc_time_format <- "%Y-%m-%dT%H:%M:%SZ"

#' Read a stored timestamp as one UTC date-time
#'
#' Corpus metadata can hold a timestamp in several forms: POSIXct from
#' `Sys.time()`, a Date, numeric epoch seconds (a corpus restored from a
#' database or JSON table), or ISO 8601 text (a certificate read back from
#' YAML). This helper turns each of them into one POSIXct in UTC:
#'
#' - POSIXct or POSIXlt: the same instant;
#' - Date: midnight UTC of that day;
#' - numeric: seconds since 1970-01-01 00:00:00 UTC;
#' - character or factor: ISO 8601, either a bare date or a date and a time
#'   (`hh:mm` or `hh:mm:ss`, optional fractional seconds) joined by `T` or a
#'   space, with an optional `Z`, `UTC`, `GMT`, `+hh`, `+hhmm` or `+hh:mm`
#'   offset (a time without one is UTC). The whole string must have this
#'   form: a zone name such as `CEST`, trailing text, or a date or time that
#'   does not exist gives NA. The helper never throws;
#' - anything else, `NULL` or `NA`: NA.
#'
#' Length 0 gives NA and several values give the latest one. A number that
#' read as seconds falls before 1973 (below 1e8, where a bare year or a day
#' count would land) or after next year (a millisecond epoch lands in year
#' 58,000) gives NA with one message. Dates, date-times and text carry their
#' own unit and are taken as given.
#' Base R only, with explicit origins, so it runs on R 4.1.
#'
#' @param x The stored value.
#' @param what Name of the value, used in the message.
#' @return A length-1 POSIXct with time zone UTC.
#' @noRd
.as_utc_time <- function(x, what = "timestamp") {
  na <- .POSIXct(NA_real_, tz = "UTC")
  if (is.factor(x)) x <- as.character(x)
  if (inherits(x, "POSIXt")) x <- as.POSIXct(x)

  secs <- if (inherits(x, "POSIXct")) {
    as.numeric(x)
  } else if (inherits(x, "Date")) {
    as.numeric(unclass(x)) * 86400
  } else if (is.numeric(x)) {
    as.numeric(x)
  } else if (is.character(x)) {
    vapply(x, .parse_iso_seconds, numeric(1), USE.NAMES = FALSE)
  } else {
    numeric()
  }

  ok <- which(is.finite(secs))
  if (length(ok) == 0L) return(na)
  pick <- ok[which.max(secs[ok])]

  this_year <- as.integer(format(Sys.time(), "%Y", tz = "UTC"))
  beyond <- as.numeric(ISOdatetime(this_year + 2L, 1, 1, 0, 0, 0, tz = "UTC"))
  if (is.numeric(x) && (secs[pick] < 1e8 || secs[pick] >= beyond)) {
    cli::cli_inform(
      c(
        "!" = "Ignoring {.field {what}} {.val {format(x[pick])}}: as seconds
               since 1970-01-01 UTC it falls before 1973 or after
               {this_year + 1L}.",
        "i" = "Milliseconds, day counts and bare years are not epoch
               seconds."
      ),
      class = "scimapR_implausible_time"
    )
    return(na)
  }
  .POSIXct(secs[pick], tz = "UTC")
}

#' Parse one ISO 8601 string to epoch seconds; NA when it does not parse
#'
#' strptime() accepts a matching prefix and ignores the rest of the string,
#' so trying formats in turn would read a `+hh` offset, a zone name or
#' trailing text as UTC and an invalid time as midnight. The string is
#' therefore normalised, matched as a whole against the ISO shape, and
#' parsed with the one format that this shape gives.
#' @noRd
.parse_iso_seconds <- function(s) {
  if (is.na(s)) return(NA_real_)
  s <- trimws(s)
  # A bare date is midnight UTC with or without a UTC designator. After a
  # time, Z, UTC and GMT are +0000, a space before the offset is dropped,
  # and +hh:mm and +hh become +hhmm.
  s <- sub("^([0-9]{4}-[0-9]{2}-[0-9]{2})\\s*(Z|UTC|GMT)$", "\\1", s,
           ignore.case = TRUE)
  s <- sub("\\s*(Z|UTC|GMT)$", "+0000", s, ignore.case = TRUE)
  s <- sub("\\s+([+-][0-9]{2}(:?[0-9]{2})?)$", "\\1", s)
  s <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", s)
  s <- sub("(:[0-9]{2}(\\.[0-9]+)?[+-][0-9]{2})$", "\\100", s)

  # parts: 2 time with offset, 3 separator, 4 seconds, 6 offset
  shape <- paste0("^[0-9]{4}-[0-9]{2}-[0-9]{2}",
                  "(([T ])[0-9]{2}:[0-9]{2}(:[0-9]{2}(\\.[0-9]+)?)?",
                  "([+-][0-9]{4})?)?$")
  # PCRE reports unmatched optional groups as ""; the default engine
  # mistook the last digit of a long fraction (.123456) for an offset
  parts <- regmatches(s, regexec(shape, s, perl = TRUE))[[1]]
  if (length(parts) == 0L) return(NA_real_)
  fmt <- paste0(
    "%Y-%m-%d", parts[3],
    if (nzchar(parts[2])) "%H:%M",
    if (nzchar(parts[4])) ":%OS",
    if (nzchar(parts[6])) "%z"
  )
  tryCatch(
    as.numeric(as.POSIXct(strptime(s, fmt, tz = "UTC"))),
    error = function(e) NA_real_,
    warning = function(w) NA_real_
  )
}

#' Format a stored timestamp in UTC; NA_character_ when it is missing
#' @noRd
.format_utc_time <- function(x, fmt = .utc_time_format, what = "timestamp") {
  time <- .as_utc_time(x, what = what)
  if (is.na(time)) NA_character_ else format(time, fmt, tz = "UTC")
}

#' Calendar year (UTC) of a time from .as_utc_time()
#' @noRd
.utc_year <- function(time) {
  as.integer(format(time, "%Y", tz = "UTC"))
}

#' Read a stored date column as one Date per value
#'
#' For columns documented as Date, such as `works$citations_as_of`, which
#' a table store can give back in another form. A Date stays as it is; a
#' POSIXct or POSIXlt gives its day in UTC; a number counts days since
#' 1970-01-01, as R keeps dates and as SQLite (through RSQLite) and other
#' table stores write them; text or a factor is read as ISO 8601 by
#' `.as_utc_time()`, one value at a time; anything else gives NA. Unlike
#' `.as_utc_time()`, which reads numbers as seconds, it reads them as days,
#' so a day count after next year (epoch seconds or milliseconds read as
#' days) gives NA, with one message.
#'
#' @param x The stored values.
#' @param what Name of the values, used in the message.
#' @return A Date vector along `x`.
#' @noRd
.as_day_dates <- function(x, what = "date") {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(as.POSIXct(x), tz = "UTC"))
  if (is.factor(x)) x <- as.character(x)
  days <- if (is.numeric(x)) {
    as.numeric(x)
  } else if (is.character(x)) {
    vapply(x, function(s) {
      as.numeric(as.Date(.as_utc_time(s, what = what), tz = "UTC"))
    }, numeric(1), USE.NAMES = FALSE)
  } else {
    rep(NA_real_, length(x))
  }
  days[!is.finite(days)] <- NA_real_

  if (is.numeric(x)) {
    this_year <- as.integer(format(Sys.time(), "%Y", tz = "UTC"))
    beyond <- as.numeric(as.Date(sprintf("%d-01-01", this_year + 2L)))
    late <- !is.na(days) & days >= beyond
    if (any(late)) {
      cli::cli_inform(
        c(
          "!" = "{.field {what}}: ignoring {sum(late)} value{?s} after
                 {this_year + 1L} when read as days since 1970-01-01.",
          "i" = "Epoch seconds and milliseconds are not day counts."
        ),
        class = "scimapR_implausible_time"
      )
      days[late] <- NA_real_
    }
  }
  as.Date(days, origin = "1970-01-01")
}

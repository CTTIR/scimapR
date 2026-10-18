# Tests for R/utils-time.R (.as_utc_time() and its formatters).

utc <- function(secs) .POSIXct(secs, tz = "UTC")

test_that(".as_utc_time reads date-times, dates, numbers and ISO text", {
  withr::local_timezone("America/Los_Angeles")
  instant <- utc(1792195200) # 2026-10-17 00:00:00 UTC
  local <- as.POSIXct("2026-10-16 17:00:00", tz = "America/Los_Angeles")
  expect_identical(.as_utc_time(instant), instant)
  expect_identical(.as_utc_time(local), instant)
  expect_identical(attr(.as_utc_time(local), "tzone"), "UTC")
  expect_identical(.as_utc_time(as.POSIXlt(instant, tz = "Asia/Tokyo")),
                   instant)
  expect_identical(.as_utc_time(as.Date("2026-10-17")), instant)
  expect_identical(.as_utc_time(1792195200), instant)
  expect_identical(.as_utc_time(1792195200L), instant)
  expect_identical(.as_utc_time("2026-10-17"), instant)
  expect_identical(.as_utc_time(factor("2026-10-17")), instant)
  expect_identical(.as_utc_time("2026-10-17T00:00:00Z"), instant)
  expect_identical(.as_utc_time("2026-10-17 00:00:00 UTC"), instant)
  expect_identical(.as_utc_time("2026-10-17T02:00:00+02:00"), instant)
  expect_identical(.as_utc_time("2026-10-17 02:00:00+0200"), instant)
  expect_identical(.as_utc_time(" 2026-10-16T17:00:00-0700 "), instant)
  expect_identical(.as_utc_time("2026-10-16T17:00-07:00"), instant)
  expect_identical(.as_utc_time("2026-10-17T00:00:00"), instant)
  expect_identical(.as_utc_time("2026-10-17 00:00"), instant)
  expect_identical(.as_utc_time("2026-10-17T11:45:00.5Z"),
                   utc(1792237500.5))
})

test_that("a 1 January timestamp keeps its year west and east of UTC", {
  for (tz in c("America/Los_Angeles", "Pacific/Auckland")) {
    withr::with_timezone(tz, {
      new_year <- .as_utc_time(as.Date("2026-01-01"))
      expect_identical(new_year, utc(1767225600))
      expect_identical(.utc_year(new_year), 2026L)
      expect_identical(.utc_year(.as_utc_time(1767225600)), 2026L)
      expect_identical(.format_utc_time(as.Date("2026-01-01")),
                       "2026-01-01T00:00:00Z")
      expect_identical(.format_utc_time(1767225599),
                       "2025-12-31T23:59:59Z")
    })
  }
})

test_that(".as_utc_time gives one NA time for missing or unsupported input", {
  na <- utc(NA_real_)
  expect_identical(.as_utc_time(NULL), na)
  expect_identical(.as_utc_time(NA), na)
  expect_identical(.as_utc_time(NA_real_), na)
  expect_identical(.as_utc_time(NA_character_), na)
  expect_identical(.as_utc_time(character()), na)
  expect_identical(.as_utc_time(numeric()), na)
  expect_identical(.as_utc_time(Inf), na)
  expect_identical(.as_utc_time(TRUE), na)
  expect_identical(.as_utc_time(list(1792195200)), na)
  expect_identical(.as_utc_time(""), na)
  expect_identical(.as_utc_time("not a date"), na)
  expect_identical(.as_utc_time("2026-13-45"), na)
  expect_silent(out <- .as_utc_time(c("garbage", NA, "2026-99-99T25:61:00Z")))
  expect_identical(out, na)
})

test_that(".as_utc_time reads +hh offsets and rejects text that is not ISO", {
  withr::local_timezone("America/Los_Angeles")
  na <- utc(NA_real_)
  quarter_to_noon <- utc(1792237500) # 2026-10-17 11:45:00 UTC
  expect_identical(.as_utc_time("2026-10-17T13:45:00+02"), quarter_to_noon)
  expect_identical(.as_utc_time("2026-10-17T06:45-05"), quarter_to_noon)
  expect_identical(.as_utc_time("2026-10-17T13:45:00+05"),
                   utc(1792237500 - 3 * 3600))
  expect_identical(.as_utc_time("2026-10-17 13:45:00 +02:00"),
                   quarter_to_noon)
  expect_identical(.as_utc_time("2026-10-17 UTC"), utc(1792195200))
  # an hour-only offset can move the instant into the next UTC year
  new_year <- .as_utc_time("2026-12-31T23:30:00-05")
  expect_identical(new_year, utc(1798777800)) # 2027-01-01 04:30:00 UTC
  expect_identical(.utc_year(new_year), 2027L)

  # strptime() alone would accept a matching prefix of each of these
  not_iso <- c(
    "2026-10-17 13:45:00 CEST", "2026-10-17abc", "2026-10-17garbage",
    "2026-10-17T13:45:00+0200 extra", "2026-10-17T25:61:00Z",
    "2026-10-17T25:00:00Z", "2026-10-17T13:61", "2026-02-30", "26-10-17",
    "2026-10-17+02:00", "2026-10-17T13:45:00+15", "2026-10-17T13"
  )
  for (s in not_iso) {
    expect_identical(.as_utc_time(s), na, info = s)
  }
})

test_that(".as_utc_time returns the latest of several values", {
  expect_identical(.as_utc_time(c(1767225600, NA, 1792195200)),
                   utc(1792195200))
  expect_identical(.as_utc_time(c("2026-10-17", "garbage", "2026-01-01")),
                   utc(1792195200))
  expect_length(.as_utc_time(as.Date(c("2026-01-01", "2026-10-17"))), 1L)
})

test_that("implausible numbers give NA with one message", {
  na <- utc(NA_real_)
  bad <- c(
    milliseconds = 1792195200000,
    bare_year = 2026,
    day_count = 20743,
    negative = -1e10,
    year_3000 = 32503680000
  )
  for (value in bad) {
    expect_message(
      out <- .as_utc_time(value, what = "metadata$last_refresh"),
      "last_refresh",
      class = "scimapR_implausible_time"
    )
    expect_identical(out, na)
  }
  # dates, date-times and text carry their own unit and are taken as given
  expect_no_message(old <- .as_utc_time(as.Date("1950-06-01")))
  expect_identical(old, utc(-618105600))
  expect_no_message(future <- .as_utc_time("2999-01-01"))
  expect_identical(.utc_year(future), 2999L)
})

test_that(".format_utc_time writes one UTC ISO 8601 form and reads it back", {
  withr::local_timezone("Pacific/Auckland")
  written <- .format_utc_time(1792237500)
  expect_identical(written, "2026-10-17T11:45:00Z")
  expect_identical(.as_utc_time(written), utc(1792237500))
  expect_identical(.format_utc_time(NA), NA_character_)
  expect_identical(.format_utc_time(1792237500, "%Y-%m-%d"), "2026-10-17")
})

# Tests for sm_citation_window() (R/citation-window.R).

window_corpus <- function(as_of = as.Date("2026-10-17")) {
  works <- tibble::tibble(
    work_id = sprintf("W%d", 1:7),
    title = paste("Synthetic work", 1:7),
    # W1 complete; W2 window runs into the as-of year; W3 enriched without
    # citations; W4 starts before the ten-year horizon; W5 not enriched;
    # W6 has no publication year; W7 has counts of an unknown date
    year = c(2018L, 2023L, 2019L, 2015L, 2018L, NA, 2018L),
    citations_as_of = c(rep(as_of, 4), NA, as_of, NA)
  )
  yearly <- tibble::tibble(
    work_id = c("W1", "W1", "W1", "W1", "W2", "W2", "W4", "W4", "W6", "W7"),
    year = c(2018L, 2019L, 2021L, 2022L, 2024L, 2026L, 2017L, 2018L, 2020L,
             2019L),
    cited_by_count = c(2L, 5L, 4L, 9L, 3L, 1L, 6L, 2L, 3L, 4L)
  )
  suppressMessages(sm_corpus_from_tables(
    list(works = works, citations_by_year = yearly)
  ))
}

test_that("windows count the publication year and the window years after", {
  out <- sm_citation_window(window_corpus(), window = 3)
  expect_named(out, c("work_id", "year", "window", "citations", "complete"))
  expect_identical(out$work_id, sprintf("W%d", 1:7))
  expect_identical(out$window, rep(3L, 7))
  # W1: 2018-2021 holds 2 + 5 + 4 (2020 had no citations); 2022 is outside
  expect_identical(out$citations, c(11L, 4L, 0L, 8L, NA, NA, 4L))
  expect_identical(out$complete, c(TRUE, FALSE, TRUE, FALSE, FALSE, FALSE,
                                   FALSE))
  expect_type(out$year, "integer")
  expect_type(out$citations, "integer")
  expect_type(out$complete, "logical")

  # window = 0 is the publication year alone
  zero <- sm_citation_window(window_corpus(), window = 0)
  expect_identical(zero$citations[1:4], c(2L, 0L, 0L, 0L))
  # a window that ends in the year before the as-of year is complete
  w2 <- sm_citation_window(window_corpus(), window = 2)
  expect_identical(w2$complete[2], TRUE)
  expect_identical(w2$citations[2], 3L)
})

test_that("the horizon follows the as-of date, never today's date", {
  # counts dated 2022 cover 2013 to 2022, so 2015 to 2018 is complete
  early <- sm_citation_window(window_corpus(as.Date("2022-03-01")), 3)
  expect_identical(early$complete[1], TRUE)
  expect_identical(early$complete[4], TRUE)
  late <- sm_citation_window(window_corpus(as.Date("2031-01-05")), 3)
  # 2018 is before the horizon of 2031 (2022 to 2031)
  expect_identical(late$complete[1], FALSE)
  expect_identical(late$complete[3], FALSE)
})

test_that("corpora without counts or works give typed results", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  out <- sm_citation_window(empty)
  expect_identical(nrow(out), 0L)
  expect_named(out, c("work_id", "year", "window", "citations", "complete"))
  expect_type(out$citations, "integer")

  plain <- sm_example_corpus(n_works = 5, seed = 1)
  expect_message(out <- sm_citation_window(plain),
                 class = "scimapR_no_citations_by_year")
  expect_true(all(is.na(out$citations)))
  expect_false(any(out$complete))
  expect_identical(nrow(out), 5L)

  expect_error(sm_citation_window(plain, window = -1), "0 or more")
  expect_error(sm_citation_window(plain, window = 1.5), "whole number")
  expect_error(sm_citation_window(list()), class = "rlang_error")
})

test_that("works$citations_as_of may be text, and may be missing", {
  corpus <- window_corpus()
  dated <- sm_citation_window(corpus)
  corpus$works$citations_as_of <- format(corpus$works$citations_as_of)
  expect_identical(sm_citation_window(corpus)$complete[1], TRUE)
  corpus$works$citations_as_of <- unclass(window_corpus()$works$citations_as_of)
  expect_type(corpus$works$citations_as_of, "double")
  expect_identical(sm_citation_window(corpus), dated)
  corpus$works$citations_as_of <- NULL
  out <- sm_citation_window(corpus)
  expect_false(any(out$complete))
  expect_identical(out$citations[1], 11L)
  expect_true(is.na(out$citations[3]))
})

test_that("works$citations_as_of stored as a day count is read as that date", {
  # SQLite (through RSQLite) and other table stores keep a Date as days
  # since 1970-01-01, so a corpus restored from them has a numeric column;
  # these numbers were read as epoch seconds, so every window was partial,
  # with one message per work
  fix <- realuse_corpus()
  tables <- list(works = fix$works, citations_by_year = fix$citations_by_year)
  tables$works$citations_as_of <- as.numeric(tables$works$citations_as_of)
  stored <- suppressMessages(sm_corpus_from_tables(tables))
  expect_type(stored$works$citations_as_of, "double")
  expect_no_message(out <- sm_citation_window(stored, window = 3))
  expect_identical(out, sm_citation_window(fix, window = 3))
  expect_true(any(out$complete))

  # epoch seconds are no day counts: ignored with one message
  stored$works$citations_as_of <- stored$works$citations_as_of * 86400
  expect_message(out <- sm_citation_window(stored, window = 3),
                 class = "scimapR_implausible_time")
  expect_false(any(out$complete))
})

test_that("the real-use fixture has yearly counts for its windows", {
  fix <- realuse_corpus()
  out <- sm_citation_window(fix, window = 3)
  expect_identical(nrow(out), nrow(fix$works))
  enriched <- !is.na(fix$works$citations_as_of)
  expect_false(anyNA(out$citations[enriched]))
  expect_true(all(is.na(out$citations[!enriched])))
  # the fixture's counts are dated 2026-10-17, so windows ending before
  # 2026 and starting in 2017 or later are complete
  expected <- enriched & fix$works$year >= 2017L & fix$works$year + 3L < 2026L
  expect_identical(out$complete, expected)
})

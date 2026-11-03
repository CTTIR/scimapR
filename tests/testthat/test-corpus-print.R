test_that("print.sm_corpus returns invisibly and does not error", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)

  expect_invisible(print(corpus))
  out <- capture.output(res <- print(corpus))
  expect_s3_class(res, "sm_corpus")
})

test_that("print.sm_corpus works on empty corpus", {
  works <- tibble::tibble(
    work_id = character(), doi = character(), title = character(),
    abstract = character(), year = integer(), type = character(),
    source_id = character(), cited_by_count = integer(),
    oa_status = character(), language = character(),
    pmid = character(), arxiv_id = character(),
    openalex_id = character(), is_retracted = logical(),
    retraction_date = as.Date(character()),
    last_refreshed = as.POSIXct(character())
  )
  corpus <- sm_corpus(works = works)

  expect_no_error(capture.output(print(corpus)))
})

test_that("format.sm_corpus returns a character string", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  fmt <- format(corpus)

  expect_type(fmt, "character")
  expect_length(fmt, 1L)
  expect_match(fmt, "sm_corpus")
})

test_that("summary.sm_corpus returns expected list elements", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = TRUE, seed = 1)
  s <- summary(corpus)

  expect_type(s, "list")
  expect_named(s, c("n_works", "n_authors", "n_institutions", "n_sources",
                     "n_references", "n_concepts", "has_embeddings",
                     "n_provenance", "n_screening", "year_range", "is_locked"))
  expect_equal(s$n_works, 10L)
  expect_true(s$has_embeddings)
})

test_that("str.sm_corpus runs without error", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  expect_no_error(capture.output(str(corpus)))
})

test_that("str() lists the yearly citation counts only when present", {
  out <- cli::cli_fmt(str(realuse_corpus()))
  expect_true(any(grepl("citations_by_year:", out, fixed = TRUE)))
  out <- cli::cli_fmt(str(sm_example_corpus(n_works = 5)))
  expect_false(any(grepl("citations_by_year", out, fixed = TRUE)))
})
test_that("printing a locked corpus does not hash its content", {
  x <- suppressMessages(sm_lock(sm_example_corpus(n_works = 10, seed = 1)))
  x$works$title[1] <- "Changed title"
  local_mocked_bindings(sm_hash_corpus = function(...) stop("hash attempted"))
  expect_match(paste(cli::cli_fmt(print(x)), collapse = "\n"), "Locked")
})

test_that("refresh timestamps print as UTC dates in every supported form", {
  x <- realuse_corpus()
  times <- list(1792195200, as.POSIXct("2026-10-17", tz = "UTC"),
                as.Date("2026-10-17"), "2026-10-17T02:00:00+02:00")
  for (time in times) {
    x$metadata$last_refresh <- time
    out <- paste(cli::cli_fmt(print(x)), collapse = "\n")
    expect_match(out, "last refreshed: 2026-10-17 00:00 UTC", fixed = TRUE)
  }
})

test_that("missing and unsupported refresh timestamps keep their meaning", {
  x <- realuse_corpus()
  for (time in list(NULL, NA_real_, as.POSIXct(NA), NA_character_)) {
    x$metadata$last_refresh <- time
    expect_match(paste(cli::cli_fmt(print(x)), collapse = "\n"),
                 "last refreshed: never", fixed = TRUE)
  }
  for (time in list("not a date", c("first", "second"), numeric())) {
    x$metadata$last_refresh <- time
    out <- paste(cli::cli_fmt(print(x)), collapse = "\n")
    for (value in format(time)) expect_match(out, value, fixed = TRUE)
  }
})

test_that("corpus print has stable output across timestamp and lock states", {
  x <- realuse_corpus()
  expect_snapshot(print(x))
  x$metadata$last_refresh <- as.POSIXct("2024-03-06 12:34:56", tz = "UTC")
  expect_snapshot(print(x))
  x$metadata$is_locked <- TRUE
  expect_snapshot(print(x))
  x <- sm_corpus(.empty_works())
  expect_snapshot(print(x))
})

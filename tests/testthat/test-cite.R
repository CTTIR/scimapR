# Tests for R/cite.R (sm_cite_corpus).

test_that("sm_cite_corpus rejects a non-corpus input", {
  expect_error(sm_cite_corpus(list()), class = "rlang_error")
})

test_that("sm_cite_corpus validates the style argument", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  # match.arg() raises a base error, not an rlang condition.
  expect_error(
    suppressMessages(sm_cite_corpus(corpus, style = "apa")),
    "should be one of"
  )
})

test_that("text style reports counts, year range and hash", {
  corpus <- sm_example_corpus(n_works = 12, n_authors = 6,
                              with_embeddings = FALSE, seed = 2,
                              year_range = c(2018L, 2020L))
  out <- suppressMessages(sm_cite_corpus(corpus, style = "text"))
  expect_type(out, "character")
  expect_match(out, "scimapR")
  expect_match(out, "12 works")
  expect_match(out, "6 authors")
  expect_match(out, "2018-2020")
  expect_match(out, "Corpus hash:")
  expect_match(out, "synthetic")
})

test_that("BibTeX citation prints and returns its literal braces", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4, seed = 3)
  printed <- cli::cli_fmt(out <- sm_cite_corpus(corpus, style = "bibtex"))
  expect_match(out, "@misc{", fixed = TRUE)
  expect_match(out, "title = {scimapR Corpus}", fixed = TRUE)
  expect_true(any(grepl("@misc{", printed, fixed = TRUE)))
})

test_that("yaml style produces a structured block", {
  corpus <- sm_example_corpus(n_works = 7, n_authors = 5,
                              with_embeddings = FALSE, seed = 4)
  out <- suppressMessages(sm_cite_corpus(corpus, style = "yaml"))
  expect_match(out, "corpus_citation:")
  expect_match(out, "tool: scimapR")
  expect_match(out, "n_works: 7")
  expect_match(out, "n_authors: 5")
})

test_that("year range is N/A for an empty corpus", {
  corpus <- sm_example_corpus(n_works = 0, n_authors = 2,
                              with_embeddings = FALSE, seed = 5)
  out <- suppressMessages(sm_cite_corpus(corpus, style = "text"))
  expect_match(out, "0 works")
  expect_match(out, "N/A")
})

test_that("a numeric, text or missing build_date gives a UTC date", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 7)
  # epoch seconds, as a corpus restored from a table stores them
  corpus$metadata$build_date <- 1792195200
  out <- suppressMessages(sm_cite_corpus(corpus, style = "yaml"))
  expect_match(out, "build_date: \"2026-10-17\"", fixed = TRUE)
  corpus$metadata$build_date <- "2026-10-16T23:30:00-02:00"
  out <- suppressMessages(sm_cite_corpus(corpus, style = "text"))
  expect_match(out, " on 2026-10-17. ", fixed = TRUE)
  corpus$metadata$build_date <- NA
  out <- suppressMessages(sm_cite_corpus(corpus, style = "text"))
  expect_match(out, " on unknown. ", fixed = TRUE)
})

test_that("refresh sources are stripped from the source listing", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  corpus$provenance$source[1] <- "openalex_refresh"
  out <- suppressMessages(sm_cite_corpus(corpus, style = "text"))
  expect_no_match(out, "openalex_refresh")
})


test_that("citation printing preserves YAML indentation and source braces", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3)
  printed <- cli::cli_fmt(sm_cite_corpus(corpus, style = "yaml"))
  expect_true("  tool: scimapR" %in% printed)
  corpus$provenance$source[1] <- "{T}est"
  printed <- paste(cli::cli_fmt(sm_cite_corpus(corpus)), collapse = "\n")
  expect_match(printed, "{T}est", fixed = TRUE)
})

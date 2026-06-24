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

# KNOWN BUG: the bibtex citation string contains literal `{` / `}` (BibTeX
# braces). `cli::cli_text(citation)` then tries to interpret them as cli/glue
# expressions and fails to parse. So `style = "bibtex"` currently errors before
# it can return the (otherwise correctly built) citation string. This test
# pins that behaviour; if the source switches to a verbatim printer the test
# should be updated to assert on the returned string instead.
test_that("bibtex style currently errors on cli brace parsing (known bug)", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 3)
  expect_error(
    sm_cite_corpus(corpus, style = "bibtex"),
    "cli"
  )
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

test_that("refresh sources are stripped from the source listing", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  corpus$provenance$source[1] <- "openalex_refresh"
  out <- suppressMessages(sm_cite_corpus(corpus, style = "text"))
  expect_no_match(out, "openalex_refresh")
})

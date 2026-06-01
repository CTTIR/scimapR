# Regression tests for the bug fixes G1-G4.

# ---- G1: OpenAlex abstract inverted-index reconstruction --------------------

test_that("G1: .openalex_abstract reconstructs word order", {
  inv <- list(
    "Hello" = list(0),
    "world" = list(1, 3),
    "again" = list(2)
  )
  out <- .openalex_abstract(list(abstract_inverted_index = inv))
  expect_type(out, "character")
  expect_length(out, 1L)
  expect_identical(out, "Hello world again world")
})

test_that("G1: .openalex_abstract is type-stable on empty/NULL/malformed input", {
  expect_identical(.openalex_abstract(list(abstract_inverted_index = NULL)),
                   NA_character_)
  expect_identical(.openalex_abstract(list(abstract_inverted_index = list())),
                   NA_character_)
  expect_identical(.openalex_abstract(list()), NA_character_)
  # positions present but contain no usable integers
  expect_identical(
    .openalex_abstract(list(abstract_inverted_index = list("x" = list()))),
    NA_character_
  )
})

test_that("G1: parsing OpenAlex results never errors on a bad abstract record", {
  json <- jsonlite::read_json(
    system.file("extdata", "example_openalex_inverted.json", package = "scimapR")
  )
  results <- json$results
  corpus <- expect_no_error(
    suppressMessages(.parse_openalex_results(results, "test", FALSE,
                                             rlang::current_env()))
  )
  expect_true(is_sm_corpus(corpus))
  expect_equal(nrow(corpus$works), 3L)
  # normal record reconstructs; empty / missing become NA
  expect_false(is.na(corpus$works$abstract[1]))
  expect_true(is.na(corpus$works$abstract[2]))
  expect_true(is.na(corpus$works$abstract[3]))
})

# ---- G2: openalexR DOI filter auto-batching ---------------------------------

test_that("G2: .parse_openalex_filter splits keys and OR-values", {
  parsed <- .parse_openalex_filter("type:journal-article,doi:10.1/a|10.1/b|10.1/c")
  expect_named(parsed, c("type", "doi"))
  expect_identical(parsed$type, "journal-article")
  expect_identical(parsed$doi, c("10.1/a", "10.1/b", "10.1/c"))
  expect_null(.parse_openalex_filter(NULL))
  expect_null(.parse_openalex_filter(""))
})

test_that("G2: long DOI lists are split into the expected number of batches", {
  dois <- paste0("10.1/", seq_len(120))
  filter <- paste0("type:journal-article,doi:", paste(dois, collapse = "|"))
  parsed <- .parse_openalex_filter(filter)
  batches <- .batch_openalex_filter(parsed, batch_size = 50L)

  expect_length(batches, 3L)
  expect_identical(unname(vapply(batches, function(b) length(b$doi), integer(1))),
                   c(50L, 50L, 20L))
  # other clauses are held constant across every batch
  expect_true(all(vapply(batches,
                         function(b) identical(b$type, "journal-article"),
                         logical(1))))
  # no DOIs lost or duplicated
  expect_setequal(unlist(lapply(batches, function(b) b$doi)), dois)
})

test_that("G2: short filters yield a single batch", {
  parsed <- .parse_openalex_filter("doi:10.1/a|10.1/b")
  expect_length(.batch_openalex_filter(parsed, batch_size = 50L), 1L)
  expect_identical(.batch_openalex_filter(NULL), list(NULL))
})

# ---- G3: bibliometrix engine on field-sparse bib ----------------------------

test_that("G3: native engine parses a field-sparse @article", {
  path <- system.file("extdata", "example_sparse.bib", package = "scimapR")
  corpus <- sm_read_bib(path, engine = "native", verbose = FALSE)
  expect_true(is_sm_corpus(corpus))
  expect_equal(nrow(corpus$works), 2L)
  expect_true(all(c("work_id", "title", "year") %in% names(corpus$works)))
  # missing fields are typed NA, not errors
  expect_true(is.na(corpus$works$doi[1]))
  expect_identical(corpus$works$doi[2], "10.1234/minimal.2021")
})

test_that("G3: bibliometrix engine degrades gracefully on sparse fields", {
  skip_if_not_installed("bibliometrix")
  path <- system.file("extdata", "example_sparse.bib", package = "scimapR")
  # Must not throw "undefined columns selected"; falls back to native parser.
  corpus <- suppressWarnings(
    sm_read_bib(path, engine = "bibliometrix", verbose = FALSE)
  )
  expect_true(is_sm_corpus(corpus))
  expect_equal(nrow(corpus$works), 2L)
})

# ---- G4: native parser correctness (perf rewrite) ---------------------------

test_that("G4: native parser handles multiline values and whitespace", {
  bib <- paste0(
    "@article{a,\n",
    "  title = {The\n   Multiline    Title},\n",
    "  author = {Doe, Jane and Roe, Richard},\n",
    "  year = {2020},\n",
    "  doi = {10.1/X},\n",
    "  keywords = {alpha; beta}\n",
    "}\n"
  )
  f <- withr::local_tempfile(fileext = ".bib")
  writeLines(bib, f)
  corpus <- sm_read_bib(f, engine = "native", verbose = FALSE)
  expect_identical(corpus$works$title, "The Multiline Title")
  expect_identical(corpus$works$doi, "10.1/x")
  expect_equal(nrow(corpus$authorships), 2L)
  expect_setequal(corpus$authors$display_name, c("Jane Doe", "Richard Roe"))
})

test_that("G4: native parser is type-stable on empty input", {
  f <- withr::local_tempfile(fileext = ".bib")
  writeLines("% just a comment, no entries\n", f)
  corpus <- sm_read_bib(f, engine = "native", verbose = FALSE)
  expect_true(is_sm_corpus(corpus))
  expect_equal(nrow(corpus$works), 0L)
  expect_identical(names(corpus$works), names(.empty_works()))
})

test_that("G4: native parser scales to a few thousand entries", {
  skip_on_cran()
  one <- paste0(
    "@article{key%d, title={Title %d}, author={Smith, John and Doe, Jane}, ",
    "year={2020}, doi={10.1/%d}}\n"
  )
  big <- paste0(vapply(1:3000, function(i) sprintf(one, i, i, i), character(1)),
                collapse = "\n")
  f <- withr::local_tempfile(fileext = ".bib")
  writeLines(big, f)
  elapsed <- system.time(
    corpus <- sm_read_bib(f, engine = "native", verbose = FALSE)
  )[["elapsed"]]
  expect_equal(nrow(corpus$works), 3000L)
  # Generous ceiling: guards against reintroducing the O(n^2) regression.
  expect_lt(elapsed, 30)
})

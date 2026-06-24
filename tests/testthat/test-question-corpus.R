# Tests for sm_corpus_for_question() and its internal converters/dedup,
# which live in R/question-build.R. All network calls are mocked; nothing
# in this file ever touches the network.

make_q <- function() {
  sm_question(
    text = "Does immunotherapy improve survival in melanoma?",
    framework = "PICO",
    population = "melanoma",
    intervention = "immunotherapy",
    outcome = "survival"
  )
}

# A minimal works tibble matching .empty_works() schema with n rows.
fake_works <- function(dois, titles = NULL) {
  n <- length(dois)
  w <- scimapR:::.empty_works()
  if (n == 0L) return(w)
  tibble::tibble(
    work_id = rep(NA_character_, n),
    doi = dois,
    title = titles %||% paste0("Title ", seq_len(n)),
    abstract = NA_character_,
    year = rep(2020L, n),
    type = "journal-article",
    source_id = NA_character_,
    cited_by_count = 1L,
    oa_status = NA_character_,
    language = NA_character_,
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = paste0("https://openalex.org/W", seq_len(n)),
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

test_that("sm_corpus_for_question validates the question argument", {
  expect_error(
    sm_corpus_for_question("not a question"),
    class = "rlang_error"
  )
  expect_error(sm_corpus_for_question(list(id = "x")))
})

test_that("sm_corpus_for_question validates n_max", {
  q <- make_q()
  expect_error(
    sm_corpus_for_question(q, n_max = -5, verbose = FALSE)
  )
})

test_that("sm_corpus_for_question builds a corpus from one mocked source", {
  q <- make_q()
  testthat::local_mocked_bindings(
    .fetch_from_source = function(source, query_strings, n_max, languages, call) {
      list(works = fake_works(c("10.1/a", "10.1/b")), n_fetched = 2L)
    }
  )
  corpus <- sm_corpus_for_question(q, sources = "openalex", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)
  expect_equal(corpus$metadata$question_id, q$id)
  # work IDs are assigned with the W######### pattern
  expect_true(all(grepl("^W[0-9]{9}$", corpus$works$work_id)))
  expect_equal(nrow(corpus$provenance), 2L)
  expect_true(all(corpus$provenance$source == "openalex"))
})

test_that("sm_corpus_for_question deduplicates on DOI across sources", {
  q <- make_q()
  testthat::local_mocked_bindings(
    .fetch_from_source = function(source, query_strings, n_max, languages, call) {
      if (source == "pubmed") {
        list(works = fake_works(c("10.1/shared", "10.1/pubmed-only")),
             n_fetched = 2L)
      } else {
        list(works = fake_works(c("10.1/shared", "10.1/openalex-only")),
             n_fetched = 2L)
      }
    }
  )
  corpus <- sm_corpus_for_question(
    q, sources = c("pubmed", "openalex"), verbose = FALSE
  )
  # 4 fetched, 1 duplicate DOI removed -> 3 unique
  expect_equal(nrow(corpus$works), 3L)
  expect_equal(sum(duplicated(corpus$works$doi)), 0L)
})

test_that("sm_corpus_for_question enforces n_max after dedup", {
  q <- make_q()
  testthat::local_mocked_bindings(
    .fetch_from_source = function(source, query_strings, n_max, languages, call) {
      list(works = fake_works(paste0("10.1/d", 1:6)), n_fetched = 6L)
    }
  )
  corpus <- sm_corpus_for_question(
    q, sources = "openalex", n_max = 3L, verbose = FALSE
  )
  expect_equal(nrow(corpus$works), 3L)
  expect_equal(nrow(corpus$provenance), 3L)
})

test_that("sm_corpus_for_question returns empty corpus when no works found", {
  q <- make_q()
  testthat::local_mocked_bindings(
    .fetch_from_source = function(source, query_strings, n_max, languages, call) {
      list(works = scimapR:::.empty_works(), n_fetched = 0L)
    }
  )
  corpus <- sm_corpus_for_question(q, sources = "openalex", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
  expect_equal(corpus$metadata$question_id, q$id)
})

test_that("sm_corpus_for_question tolerates a source that errors", {
  q <- make_q()
  testthat::local_mocked_bindings(
    .fetch_from_source = function(source, query_strings, n_max, languages, call) {
      if (source == "pubmed") stop("network boom")
      list(works = fake_works("10.1/ok"), n_fetched = 1L)
    }
  )
  expect_message(
    corpus <- sm_corpus_for_question(
      q, sources = c("pubmed", "openalex"), verbose = TRUE
    ),
    "Failed to fetch"
  )
  expect_equal(nrow(corpus$works), 1L)
})

test_that("sm_corpus_for_question emits progress when verbose = TRUE", {
  q <- make_q()
  testthat::local_mocked_bindings(
    .fetch_from_source = function(source, query_strings, n_max, languages, call) {
      list(works = fake_works("10.1/v"), n_fetched = 1L)
    }
  )
  expect_message(
    sm_corpus_for_question(q, sources = "openalex", verbose = TRUE),
    "Building corpus"
  )
})

# ---- internal converters -------------------------------------------------

test_that(".openalex_to_works handles NULL/empty and populated results", {
  expect_equal(nrow(scimapR:::.openalex_to_works(NULL, 10L)), 0L)
  res <- tibble::tibble(
    doi = c("https://doi.org/10.1/A", NA),
    display_name = c("Paper A", "Paper B"),
    ab = c("abs a", NA),
    publication_year = c(2021, 2019),
    type = c("article", "article"),
    cited_by_count = c(5, 0),
    oa_status = c("gold", "closed"),
    language = c("en", "en"),
    id = c("https://openalex.org/W1", "https://openalex.org/W2"),
    is_retracted = c(FALSE, FALSE)
  )
  w <- scimapR:::.openalex_to_works(res, 10L)
  expect_equal(nrow(w), 2L)
  expect_equal(w$title, c("Paper A", "Paper B"))
  expect_equal(w$year, c(2021L, 2019L))
  expect_equal(w$doi[1], "10.1/a")
  # n_max truncation
  expect_equal(nrow(scimapR:::.openalex_to_works(res, 1L)), 1L)
})

test_that(".crossref_to_works handles NULL/empty and populated data", {
  expect_equal(nrow(scimapR:::.crossref_to_works(NULL)), 0L)
  data <- tibble::tibble(
    doi = c("10.5/X", "10.5/Y"),
    title = c("CR A", "CR B"),
    published.print = c("2018", "2017"),
    issued = c("2018", "2017"),
    type = c("journal-article", "journal-article"),
    is.referenced.by.count = c("12", "3"),
    language = c("en", NA)
  )
  w <- scimapR:::.crossref_to_works(data)
  expect_equal(nrow(w), 2L)
  expect_equal(w$cited_by_count, c(12L, 3L))
  expect_equal(w$year, c(2018L, 2017L))
  expect_equal(w$doi, c("10.5/x", "10.5/y"))
})

test_that(".deduplicate_works keeps first per DOI and all DOI-less rows", {
  expect_equal(nrow(scimapR:::.deduplicate_works(scimapR:::.empty_works())), 0L)
  works <- fake_works(c("10.1/a", "10.1/a", NA, ""))
  works$work_id <- paste0("W", 1:4)
  dd <- scimapR:::.deduplicate_works(works)
  # one of the two 10.1/a kept, plus the NA and the "" (both DOI-less)
  expect_equal(nrow(dd), 3L)
  expect_equal(sum(dd$doi == "10.1/a", na.rm = TRUE), 1L)
})

test_that(".fetch_from_source aborts on unknown source", {
  expect_error(
    scimapR:::.fetch_from_source(
      source = "bogus",
      query_strings = list(generic = "x"),
      n_max = 5L,
      languages = NULL
    ),
    "Unknown source"
  )
})

test_that(".pubmed_ids_to_works returns empty for no ids / failed summary", {
  expect_equal(nrow(scimapR:::.pubmed_ids_to_works(character(0))), 0L)
})

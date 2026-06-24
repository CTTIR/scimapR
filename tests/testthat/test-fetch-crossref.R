# Tests for sm_fetch_crossref() -- NO NETWORK.

.crossref_item <- function(doi = "10.1234/abc") {
  list(
    DOI = doi,
    title = list("A Crossref Work"),
    abstract = "<jats:p>Some <b>abstract</b> text.</jats:p>",
    `published-print` = list(`date-parts` = list(list(2021L, 5L, 1L))),
    type = "journal-article",
    ISSN = list("1111-2222"),
    `is-referenced-by-count` = 42L,
    language = "en",
    publisher = "Test Publisher",
    `container-title` = list("Crossref Journal"),
    author = list(
      list(given = "Ada", family = "Lovelace", sequence = "first",
           ORCID = "https://orcid.org/0000-0002-0000-0001",
           affiliation = list(list(name = "Analytical Engine Inst"))),
      list(given = "Charles", family = "Babbage", sequence = "additional")
    ),
    reference = list(
      list(DOI = "10.9999/ref1", unstructured = "Ref one raw"),
      list(unstructured = "Ref two raw, no doi")
    )
  )
}

.crossref_body <- function(items, total = NULL) {
  list(message = list(
    items = items,
    `total-results` = total %||% length(items)
  ))
}

test_that("sm_fetch_crossref requires query or filter", {
  expect_error(sm_fetch_crossref(), "query.*filter|filter.*query")
})

test_that("sm_fetch_crossref validates n_max and engine", {
  expect_error(sm_fetch_crossref(query = "x", n_max = 0), "positive integer")
  expect_error(sm_fetch_crossref(query = "x", engine = "bogus"))
})

test_that("sm_fetch_crossref native parses items into an sm_corpus", {
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      page <<- page + 1L
      if (page == 1L) .crossref_body(list(.crossref_item()), total = 1L)
      else .crossref_body(list())
    },
    .package = "httr2"
  )

  corpus <- sm_fetch_crossref(query = "bibliometrics", n_max = 10,
                              mailto = "", engine = "native", verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title[[1]], "A Crossref Work")
  expect_equal(corpus$works$doi[[1]], "10.1234/abc")
  expect_equal(corpus$works$year[[1]], 2021L)
  expect_equal(corpus$works$cited_by_count[[1]], 42L)
  expect_equal(corpus$works$type[[1]], "journal-article")
  # abstract HTML stripped
  expect_false(grepl("<", corpus$works$abstract[[1]]))
  # authors + ORCID normalised (prefix removed)
  expect_true("0000-0002-0000-0001" %in% corpus$authors$orcid)
  # sources
  expect_true("Crossref Journal" %in% corpus$sources$display_name)
  # references
  expect_equal(nrow(corpus$references), 2L)
  expect_true("10.9999/ref1" %in% corpus$references$cited_doi)
  # provenance
  expect_true(all(corpus$provenance$source == "crossref"))
})

test_that("sm_fetch_crossref accepts filter-only and a mailto polite-pool arg", {
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      page <<- page + 1L
      if (page == 1L) .crossref_body(list(.crossref_item()), total = 1L)
      else .crossref_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_crossref(
    filter = "from-pub-date:2020,type:journal-article",
    n_max = 5, mailto = "me@example.com", engine = "native", verbose = FALSE
  )
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
})

test_that("sm_fetch_crossref verbose prints progress", {
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      page <<- page + 1L
      if (page == 1L) .crossref_body(list(.crossref_item()), total = 1L)
      else .crossref_body(list())
    },
    .package = "httr2"
  )
  expect_message(
    sm_fetch_crossref(query = "x", n_max = 5, mailto = "",
                      engine = "native", verbose = TRUE),
    "Crossref"
  )
})

test_that("sm_fetch_crossref returns empty corpus when no items", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .crossref_body(list()),
    .package = "httr2"
  )
  corpus <- sm_fetch_crossref(query = "nope", n_max = 5, mailto = "",
                              engine = "native", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_crossref aborts on request failure", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_crossref(query = "x", n_max = 5, mailto = "",
                      engine = "native", verbose = FALSE),
    "Crossref API request failed"
  )
})

test_that("sm_fetch_crossref engine='auto' uses native when rcrossref absent", {
  page <- 0L
  local_mocked_bindings(is_installed = function(pkg, ...) FALSE, .package = "rlang")
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      page <<- page + 1L
      if (page == 1L) .crossref_body(list(.crossref_item()), total = 1L)
      else .crossref_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_crossref(query = "x", n_max = 5, mailto = "",
                              engine = "auto", verbose = FALSE)
  expect_true(all(corpus$provenance$engine == "native"))
})

test_that("sm_fetch_crossref engine='rcrossref' errors when rcrossref not installed", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) cli::cli_abort("need rcrossref"),
    .package = "rlang"
  )
  expect_error(
    sm_fetch_crossref(query = "x", engine = "rcrossref", verbose = FALSE),
    "rcrossref"
  )
})

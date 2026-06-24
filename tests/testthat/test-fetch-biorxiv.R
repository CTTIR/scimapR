# Tests for sm_fetch_biorxiv() -- NO NETWORK.

.biorxiv_item <- function(title = "A bioRxiv Preprint",
                          abstract = "An abstract about genomics.",
                          doi = "10.1101/2024.01.01.123456") {
  list(
    doi = doi,
    title = title,
    abstract = abstract,
    date = "2024-01-03",
    category = "genomics",
    authors = "Rosalind Franklin; James Watson"
  )
}

.biorxiv_body <- function(items, total = NULL) {
  list(
    messages = list(list(total = as.character(total %||% length(items)))),
    collection = items
  )
}

test_that("sm_fetch_biorxiv validates server and n_max", {
  expect_error(sm_fetch_biorxiv(server = "bogus"))
  expect_error(sm_fetch_biorxiv(n_max = 0), "positive integer")
})

test_that("sm_fetch_biorxiv parses preprints into an sm_corpus", {
  call_n <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .biorxiv_body(list(.biorxiv_item()), total = 1L)
      else .biorxiv_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_biorxiv(server = "biorxiv", from_date = "2024-01-01",
                             to_date = "2024-01-07", n_max = 10, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title[[1]], "A bioRxiv Preprint")
  expect_equal(corpus$works$doi[[1]], "10.1101/2024.01.01.123456")
  expect_equal(corpus$works$year[[1]], 2024L)
  expect_equal(corpus$works$type[[1]], "preprint")
  expect_equal(corpus$works$oa_status[[1]], "gold")
  # authors split on semicolons
  expect_true("Rosalind Franklin" %in% corpus$authors$display_name)
  expect_true("James Watson" %in% corpus$authors$display_name)
  # category -> concept
  expect_true("genomics" %in% corpus$concepts$concept_name)
  expect_true(all(corpus$concepts$vocabulary == "biorxiv"))
  # provenance uses server name as source
  expect_true(all(corpus$provenance$source == "biorxiv"))
})

test_that("sm_fetch_biorxiv default date range works (NULL dates)", {
  call_n <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .biorxiv_body(list(.biorxiv_item()), total = 1L)
      else .biorxiv_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_biorxiv(server = "medrxiv", n_max = 5, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
})

test_that("sm_fetch_biorxiv local query filter keeps only matching items", {
  call_n <- 0L
  items <- list(
    .biorxiv_item(title = "Cancer immunotherapy study",
                  abstract = "about tumors", doi = "10.1101/a"),
    .biorxiv_item(title = "Plant biology paper",
                  abstract = "about leaves", doi = "10.1101/b")
  )
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .biorxiv_body(items, total = 2L)
      else .biorxiv_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_biorxiv(query = "cancer", server = "biorxiv",
                             from_date = "2024-01-01", to_date = "2024-01-07",
                             n_max = 10, verbose = FALSE)
  expect_equal(nrow(corpus$works), 1L)
  expect_match(corpus$works$title[[1]], "Cancer")
})

test_that("sm_fetch_biorxiv returns empty corpus when query matches nothing", {
  call_n <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .biorxiv_body(list(.biorxiv_item()), total = 1L)
      else .biorxiv_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_biorxiv(query = "zzzznomatch", server = "biorxiv",
                             from_date = "2024-01-01", to_date = "2024-01-07",
                             n_max = 10, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_biorxiv verbose prints progress", {
  call_n <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .biorxiv_body(list(.biorxiv_item()), total = 1L)
      else .biorxiv_body(list())
    },
    .package = "httr2"
  )
  expect_message(
    sm_fetch_biorxiv(server = "biorxiv", from_date = "2024-01-01",
                     to_date = "2024-01-07", n_max = 5, verbose = TRUE),
    "biorxiv"
  )
})

test_that("sm_fetch_biorxiv returns empty corpus when API has no collection", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .biorxiv_body(list()),
    .package = "httr2"
  )
  corpus <- sm_fetch_biorxiv(server = "biorxiv", from_date = "2024-01-01",
                             to_date = "2024-01-07", n_max = 5, verbose = FALSE)
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_biorxiv aborts on request failure", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_biorxiv(server = "biorxiv", from_date = "2024-01-01",
                     to_date = "2024-01-07", n_max = 5, verbose = FALSE),
    "API request failed"
  )
})

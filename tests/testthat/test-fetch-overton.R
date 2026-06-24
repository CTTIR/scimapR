# Tests for sm_fetch_overton() -- NO NETWORK.

.overton_item <- function(id = "ov1", doi = "10.1234/policy") {
  list(
    id = id,
    doi = doi,
    title = "A Policy Document",
    abstract = "Policy abstract.",
    year = 2023L,
    type = "policy-document",
    source = "World Health Org",
    policy_citation_count = 12L,
    authors = list(
      list(name = "Jane Policy"),
      list(name = "John Maker")
    )
  )
}

.overton_body <- function(items, total = NULL) {
  list(results = items, total = as.character(total %||% length(items)))
}

test_that("sm_fetch_overton validates query and n_max", {
  expect_error(sm_fetch_overton(query = "", api_key = "k"), "non-empty")
  expect_error(sm_fetch_overton(query = "x", api_key = "k", n_max = 0),
               "positive integer")
})

test_that("sm_fetch_overton requires an API key", {
  expect_error(
    sm_fetch_overton(query = "climate", api_key = "", verbose = FALSE),
    "API key is required"
  )
})

test_that("sm_fetch_overton parses results into an sm_corpus", {
  call_n <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .overton_body(list(.overton_item()), total = 1L)
      else .overton_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_overton(query = "climate change policy",
                             api_key = "SECRET", n_max = 10, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title[[1]], "A Policy Document")
  expect_equal(corpus$works$doi[[1]], "10.1234/policy")
  expect_equal(corpus$works$year[[1]], 2023L)
  expect_equal(corpus$works$type[[1]], "policy-document")
  expect_equal(corpus$works$cited_by_count[[1]], 12L)
  # authors (list-of-named-list form)
  expect_true("Jane Policy" %in% corpus$authors$display_name)
  expect_true("John Maker" %in% corpus$authors$display_name)
  # provenance
  expect_true(all(corpus$provenance$source == "overton"))
  expect_true("ov1" %in% corpus$provenance$source_id_external)
})

test_that("sm_fetch_overton parses authors given as a single string", {
  call_n <- 0L
  item <- .overton_item()
  item$authors <- "Alice One; Bob Two"
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .overton_body(list(item), total = 1L)
      else .overton_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_overton(query = "x", api_key = "K", n_max = 5,
                             verbose = FALSE)
  expect_true("Alice One" %in% corpus$authors$display_name)
  expect_true("Bob Two" %in% corpus$authors$display_name)
})

test_that("sm_fetch_overton verbose prints progress", {
  call_n <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      call_n <<- call_n + 1L
      if (call_n == 1L) .overton_body(list(.overton_item()), total = 1L)
      else .overton_body(list())
    },
    .package = "httr2"
  )
  expect_message(
    sm_fetch_overton(query = "x", api_key = "K", n_max = 5, verbose = TRUE),
    "Overton"
  )
})

test_that("sm_fetch_overton returns empty corpus when no results", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .overton_body(list()),
    .package = "httr2"
  )
  corpus <- sm_fetch_overton(query = "nope", api_key = "K", n_max = 5,
                             verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_overton aborts on request failure", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_overton(query = "x", api_key = "K", n_max = 5, verbose = FALSE),
    "Overton API request failed"
  )
})

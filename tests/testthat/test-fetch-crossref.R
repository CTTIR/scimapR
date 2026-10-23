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
  local_http_env()
  expect_error(sm_fetch_crossref(), "query.*filter|filter.*query")
})

test_that("sm_fetch_crossref validates n_max and engine", {
  local_http_env()
  expect_error(sm_fetch_crossref(query = "x", n_max = 0), "positive integer")
  expect_error(sm_fetch_crossref(query = "x", engine = "bogus"))
})

test_that("sm_fetch_crossref native parses items into an sm_corpus", {
  local_http_env()
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
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
  local_http_env()
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
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
  local_http_env()
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
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
  local_http_env()
  local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
    resp_body_json = function(resp, ...) .crossref_body(list()),
    .package = "httr2"
  )
  corpus <- sm_fetch_crossref(query = "nope", n_max = 5, mailto = "",
                              engine = "native", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_crossref aborts on request failure", {
  local_http_env()
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
  local_http_env()
  page <- 0L
  local_mocked_bindings(is_installed = function(pkg, ...) FALSE, .package = "rlang")
  local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
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
  local_http_env()
  local_mocked_bindings(
    check_installed = function(pkg, ...) cli::cli_abort("need rcrossref"),
    .package = "rlang"
  )
  expect_error(
    sm_fetch_crossref(query = "x", engine = "rcrossref", verbose = FALSE),
    "rcrossref"
  )
})

test_that("sm_fetch_crossref records the corresponding author as unknown", {
  local_http_env()
  # Crossref's sequence = "first" marks the first author, not the
  # corresponding one, which the record does not name
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      http_response()
    },
    resp_body_json = function(resp, ...) {
      page <<- page + 1L
      if (page == 1L) .crossref_body(list(.crossref_item()), total = 1L)
      else .crossref_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_crossref(query = "bibliometrics", n_max = 10,
                              mailto = "", engine = "native", verbose = FALSE)
  a <- corpus$authorships
  expect_identical(a$position, 1:2)
  expect_identical(a$is_corresponding, c(NA, NA))
})

test_that("sm_fetch_crossref records its request for a rebuild", {
  local_http_env()
  page <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      http_response()
    },
    resp_body_json = function(resp, ...) {
      page <<- page + 1L
      if (page == 1L) .crossref_body(list(.crossref_item()), total = 1L)
      else .crossref_body(list())
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_crossref(filter = "from-pub-date:2020", n_max = 5,
                              mailto = "", engine = "native", verbose = FALSE)
  prov <- corpus$provenance
  expect_identical(prov$kind, "api_query")
  expect_identical(prov$filter, "from-pub-date:2020")
  expect_identical(prov$n_max, 5L)
  expect_identical(prov$query, NA_character_)
})


test_that("Crossref fetches link a reference DOI to another fetched work", {
  local_http_env()
  a <- .crossref_item("10.9999/link.a")
  b <- .crossref_item("10.9999/link.b")
  a$reference <- list()
  b$reference <- list(list(DOI = "10.9999/LINK.A"))
  local_mocked_bindings(
    req_perform = function(...) http_response(),
    resp_body_json = function(...) .crossref_body(list(a, b)),
    .package = "httr2"
  )
  x <- suppressMessages(sm_fetch_crossref(query = "invented links", n_max = 2,
                                          engine = "native", verbose = FALSE))
  expect_identical(x$references$cited_work_id, x$works$work_id[1])
})

test_that("Crossref uses cursors and preserves pages after exhausted retries", {
  local_http_env()
  seen <- list()
  local_mocked_bindings(.sm_sleep = function(seconds) NULL)
  local_mocked_bindings(req_perform = function(req, ...) {
    q <- httr2::url_parse(req$url)$query
    seen[[length(seen) + 1L]] <<- q
    if (length(seen) > 1L) return(http_response(status = 503L))
    body <- .crossref_body(list(.crossref_item("10.9999/partial")), total = 4L)
    body$message[["next-cursor"]] <- "cursor2"
    http_response(body)
  }, .package = "httr2")
  err <- expect_error(sm_fetch_crossref(query = "invented", n_max = 4,
                                        mailto = "", verbose = FALSE),
                      class = "scimapR_fetch_incomplete")
  expect_s3_class(err, "scimapR_http_error")
  expect_identical(length(seen), 4L)
  expect_identical(seen[[1]]$cursor, "*")
  expect_identical(seen[[2]]$cursor, "cursor2")
  expect_true(all(vapply(seen, function(q) is.null(q$offset), logical(1))))
  expect_identical(err$n_fetched, 1L)
  expect_identical(err$partial$works$doi, "10.9999/partial")
  expect_identical(err$partial$metadata$fetch_incomplete$n_expected, 4L)
  expect_match(conditionMessage(err), "rlang::last_error()$partial",
               fixed = TRUE)
})

test_that("Crossref dates skip null parts and preserve organisation authors", {
  local_http_env()
  item <- .crossref_item("10.9999/null-date")
  item[["published-print"]] <- list(`date-parts` = list(list(NULL)))
  item[["published-online"]] <- list(`date-parts` = list(list(NULL)))
  item$issued <- list(`date-parts` = list(list(NULL)))
  item$author <- list(list(name = "Invented Study Group"), list(), list())
  out <- .parse_crossref_results(list(item), NULL, FALSE, rlang::current_env())
  expect_identical(out$works$year, NA_integer_)
  expect_true("Invented Study Group" %in% out$authors$display_name)
  expect_false(anyNA(out$authorships$author_id))
  expect_identical(length(unique(out$authorships$author_id)), 3L)
  item$issued <- list(`date-parts` = list(list(2024L)))
  out <- .parse_crossref_results(list(item), NULL, FALSE, rlang::current_env())
  expect_identical(out$works$year, 2024L)
})

test_that("Crossref retries transient failures and reports malformed pages", {
  local_http_env()
  calls <- 0L
  local_mocked_bindings(.sm_sleep = function(seconds) NULL)
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    if (calls == 1L) return(http_response(status = 503L))
    http_response(.crossref_body(list(.crossref_item("10.9999/transient"))))
  }, .package = "httr2")
  out <- sm_fetch_crossref(query = "invented", n_max = 1, mailto = "",
                           verbose = FALSE)
  expect_identical(calls, 2L)
  expect_identical(out$works$doi, "10.9999/transient")
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    if (calls > 1L) return(http_response(status = 400L))
    body <- .crossref_body(list(list(title = list(list(bad = "type")))),
                           total = 2L)
    body$message[["next-cursor"]] <- "cursor2"
    http_response(body)
  }, .package = "httr2")
  calls <- 0L
  err <- expect_error(sm_fetch_crossref(query = "invented", n_max = 2,
                                        mailto = "", verbose = FALSE),
                      class = "scimapR_fetch_incomplete")
  expect_null(err$partial)
  expect_match(conditionMessage(err), "could not be parsed", fixed = TRUE)
})

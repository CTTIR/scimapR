# Tests for sm_fetch_semantic_scholar() -- NO NETWORK.

.s2_paper <- function(id = "PAPER1", with_embedding = FALSE) {
  p <- list(
    paperId = id,
    externalIds = list(DOI = "10.1234/s2", PubMed = "33333333", ArXiv = "2001.00001"),
    title = "A Semantic Scholar Paper",
    abstract = "S2 abstract text.",
    year = 2022L,
    citationCount = 7L,
    isOpenAccess = TRUE,
    publicationVenue = list(
      id = "VENUE1", name = "S2 Venue", issn = "3333-4444",
      type = "journal", alternate_issns = list("5555-6666")
    ),
    authors = list(
      list(authorId = "AUTH1", name = "Grace Hopper"),
      list(authorId = "AUTH2", name = "Alan Turing")
    ),
    references = list(
      list(externalIds = list(DOI = "10.1/refdoi"), title = "A reference title")
    )
  )
  if (with_embedding) {
    p$embedding <- list(model = "specter", vector = as.list(c(0.1, 0.2, 0.3)))
  }
  p
}

.s2_search_body <- function(papers, total = NULL, has_next = FALSE) {
  body <- list(data = papers, total = total %||% length(papers))
  if (has_next) body$`next` <- 1L
  body
}

test_that("sm_fetch_semantic_scholar requires query or paper_ids", {
  expect_error(sm_fetch_semantic_scholar(), "query.*paper_ids|paper_ids.*query")
})

test_that("sm_fetch_semantic_scholar validates n_max", {
  expect_error(sm_fetch_semantic_scholar(query = "x", n_max = 0), "positive integer")
})

test_that("sm_fetch_semantic_scholar search parses papers into an sm_corpus", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .s2_search_body(list(.s2_paper())),
    .package = "httr2"
  )
  corpus <- sm_fetch_semantic_scholar(query = "bibliometrics", n_max = 10,
                                      api_key = "", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title[[1]], "A Semantic Scholar Paper")
  expect_equal(corpus$works$doi[[1]], "10.1234/s2")
  expect_equal(corpus$works$pmid[[1]], "33333333")
  expect_equal(corpus$works$arxiv_id[[1]], "2001.00001")
  expect_equal(corpus$works$year[[1]], 2022L)
  expect_equal(corpus$works$cited_by_count[[1]], 7L)
  expect_equal(corpus$works$oa_status[[1]], "open")
  # authors
  expect_true("Grace Hopper" %in% corpus$authors$display_name)
  # sources
  expect_true("S2 Venue" %in% corpus$sources$display_name)
  # references
  expect_equal(nrow(corpus$references), 1L)
  expect_true("10.1/refdoi" %in% corpus$references$cited_doi)
  # provenance
  expect_true(all(corpus$provenance$source == "semantic_scholar"))
})

test_that("sm_fetch_semantic_scholar honours an API key header path", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .s2_search_body(list(.s2_paper())),
    .package = "httr2"
  )
  corpus <- sm_fetch_semantic_scholar(query = "x", n_max = 5,
                                      api_key = "MYKEY", verbose = FALSE)
  expect_equal(nrow(corpus$works), 1L)
})

test_that("sm_fetch_semantic_scholar attaches embeddings when requested", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      .s2_search_body(list(.s2_paper(with_embedding = TRUE)))
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_semantic_scholar(query = "x", n_max = 5, api_key = "",
                                      include_embeddings = TRUE, verbose = FALSE)
  expect_true(is.matrix(corpus$embeddings))
  expect_equal(ncol(corpus$embeddings), 3L)
  expect_equal(nrow(corpus$embeddings), 1L)
})

test_that("sm_fetch_semantic_scholar verbose prints progress", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .s2_search_body(list(.s2_paper())),
    .package = "httr2"
  )
  expect_message(
    sm_fetch_semantic_scholar(query = "x", n_max = 5, api_key = "",
                              verbose = TRUE),
    "Semantic Scholar"
  )
})

test_that("sm_fetch_semantic_scholar returns empty corpus on no data", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .s2_search_body(list()),
    .package = "httr2"
  )
  corpus <- sm_fetch_semantic_scholar(query = "nope", n_max = 5, api_key = "",
                                      verbose = FALSE)
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_semantic_scholar aborts on search request failure", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_semantic_scholar(query = "x", n_max = 5, api_key = "",
                              verbose = FALSE),
    "Semantic Scholar API request failed"
  )
})

test_that("sm_fetch_semantic_scholar batch (paper_ids) parses an sm_corpus", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    # batch endpoint returns a bare list of papers (no $data wrapper)
    resp_body_json = function(resp, ...) list(.s2_paper("P1"), .s2_paper("P2")),
    .package = "httr2"
  )
  corpus <- sm_fetch_semantic_scholar(
    paper_ids = c("DOI:10.1234/s2", "ARXIV:2001.00001"),
    api_key = "", verbose = FALSE
  )
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)
})

test_that("sm_fetch_semantic_scholar batch returns empty corpus when none found", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) list(),
    .package = "httr2"
  )
  corpus <- sm_fetch_semantic_scholar(paper_ids = c("DOI:10.0/x"),
                                      api_key = "", verbose = FALSE)
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_semantic_scholar batch aborts on request failure", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_semantic_scholar(paper_ids = c("DOI:10.0/x"), api_key = "",
                              verbose = FALSE),
    "Semantic Scholar batch request failed"
  )
})

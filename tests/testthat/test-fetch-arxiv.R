# Tests for sm_fetch_arxiv() -- NO NETWORK.

# Canned arXiv Atom feed with one entry (+ totalResults for pagination break).
.arxiv_xml <- function(n_entries = 1L, total = 1L) {
  entry <- paste0(
    '<entry>',
    '<id>http://arxiv.org/abs/2001.01234v1</id>',
    '<title>An  Arxiv\n  Preprint</title>',
    '<summary>  A summary with   extra   spaces. </summary>',
    '<published>2020-01-15T00:00:00Z</published>',
    '<author><name>Marie Curie</name>',
    '<arxiv:affiliation>Radium Institute</arxiv:affiliation></author>',
    '<author><name>Pierre Curie</name></author>',
    '<arxiv:doi>10.1234/arxiv.doi</arxiv:doi>',
    '<category term="physics.gen-ph"/>',
    '<category term="math.PR"/>',
    '</entry>'
  )
  entries <- paste(rep(entry, n_entries), collapse = "")
  paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<feed xmlns="http://www.w3.org/2005/Atom" ',
    'xmlns:arxiv="http://arxiv.org/schemas/atom" ',
    'xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">',
    '<opensearch:totalResults>', total, '</opensearch:totalResults>',
    entries,
    '</feed>'
  )
}

.arxiv_empty_xml <- function() {
  paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<feed xmlns="http://www.w3.org/2005/Atom" ',
    'xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">',
    '<opensearch:totalResults>0</opensearch:totalResults>',
    '</feed>'
  )
}

test_that("sm_fetch_arxiv validates query and n_max", {
  expect_error(sm_fetch_arxiv(query = ""), "non-empty")
  expect_error(sm_fetch_arxiv(query = 1L), "single string")
  expect_error(sm_fetch_arxiv(query = "x", n_max = 0), "positive integer")
})

test_that("sm_fetch_arxiv parses an Atom feed into an sm_corpus", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_string = function(resp, ...) .arxiv_xml(),
    .package = "httr2"
  )
  corpus <- sm_fetch_arxiv(query = "all:bibliometrics", n_max = 10,
                           verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
  # whitespace collapsed in title
  expect_equal(corpus$works$title[[1]], "An Arxiv Preprint")
  expect_equal(corpus$works$abstract[[1]], "A summary with extra spaces.")
  expect_equal(corpus$works$year[[1]], 2020L)
  expect_equal(corpus$works$type[[1]], "preprint")
  expect_equal(corpus$works$oa_status[[1]], "gold")
  expect_equal(corpus$works$arxiv_id[[1]], "2001.01234v1")
  expect_equal(corpus$works$doi[[1]], "10.1234/arxiv.doi")
  # authors + affiliation
  expect_true("Marie Curie" %in% corpus$authors$display_name)
  expect_true("Radium Institute" %in% corpus$authorships$raw_affiliation)
  # categories -> concepts
  expect_true(all(c("physics.gen-ph", "math.PR") %in% corpus$concepts$concept_id))
  expect_true(all(corpus$concepts$vocabulary == "arxiv"))
  # provenance
  expect_true(all(corpus$provenance$source == "arxiv"))
})

test_that("sm_fetch_arxiv verbose prints progress", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_string = function(resp, ...) .arxiv_xml(),
    .package = "httr2"
  )
  expect_message(
    sm_fetch_arxiv(query = "all:x", n_max = 5, verbose = TRUE),
    "arXiv"
  )
})

test_that("sm_fetch_arxiv returns an empty corpus when feed has no entries", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_string = function(resp, ...) .arxiv_empty_xml(),
    .package = "httr2"
  )
  corpus <- sm_fetch_arxiv(query = "nope", n_max = 5, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_arxiv aborts on request failure", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_arxiv(query = "x", n_max = 5, verbose = FALSE),
    "arXiv API request failed"
  )
})

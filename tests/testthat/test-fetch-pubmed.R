# Tests for sm_fetch_pubmed() -- NO NETWORK.
# All HTTP is stubbed via local_mocked_bindings() on httr2 functions.

# A canned PubMed efetch XML document with two articles.
.pubmed_xml <- function() {
  paste0(
    '<?xml version="1.0"?>',
    '<PubmedArticleSet>',
    '<PubmedArticle>',
    '<MedlineCitation>',
    '<PMID>11111111</PMID>',
    '<Article>',
    '<Journal><ISSN>1234-5678</ISSN><Title>Journal of Tests</Title></Journal>',
    '<ArticleTitle>First test article</ArticleTitle>',
    '<Abstract><AbstractText>Abstract one part A.</AbstractText>',
    '<AbstractText>Abstract one part B.</AbstractText></Abstract>',
    '<AuthorList>',
    '<Author><LastName>Smith</LastName><ForeName>Jane</ForeName>',
    '<Identifier Source="ORCID">0000-0001-2345-6789</Identifier>',
    '<AffiliationInfo><Affiliation>Test University</Affiliation></AffiliationInfo>',
    '</Author>',
    '<Author><LastName>Doe</LastName><ForeName>John</ForeName></Author>',
    '</AuthorList>',
    '<Language>eng</Language>',
    '</Article>',
    '<MedlineJournalInfo><Country>United States</Country>',
    '<ISSNLinking>1234-5678</ISSNLinking></MedlineJournalInfo>',
    '<MeshHeadingList><MeshHeading>',
    '<DescriptorName UI="D000001">Bibliometrics</DescriptorName>',
    '</MeshHeading></MeshHeadingList>',
    '<PubDate><Year>2020</Year></PubDate>',
    '<ArticleIdList><ArticleId IdType="doi">10.1234/first</ArticleId></ArticleIdList>',
    '</MedlineCitation>',
    '</PubmedArticle>',
    '<PubmedArticle>',
    '<MedlineCitation>',
    '<PMID>22222222</PMID>',
    '<Article>',
    '<ArticleTitle>Second test article</ArticleTitle>',
    '<PubDate><MedlineDate>2019 Spring</MedlineDate></PubDate>',
    '</Article>',
    '</MedlineCitation>',
    '</PubmedArticle>',
    '</PubmedArticleSet>'
  )
}

# esearch JSON body (parsed-list form) with two PMIDs.
.pubmed_esearch_body <- function(ids = c("11111111", "22222222")) {
  list(esearchresult = list(
    count = as.character(length(ids)),
    webenv = "WEBENV_TOKEN",
    querykey = "1",
    idlist = as.list(ids)
  ))
}

test_that("sm_fetch_pubmed validates query and n_max", {
  expect_error(sm_fetch_pubmed(query = ""), "non-empty")
  expect_error(sm_fetch_pubmed(query = 123), "single string")
  expect_error(sm_fetch_pubmed(query = "x", n_max = 0), "positive integer")
  expect_error(sm_fetch_pubmed(query = "x", n_max = -3), "positive integer")
})

test_that("sm_fetch_pubmed rejects an unknown engine", {
  expect_error(sm_fetch_pubmed(query = "x", engine = "nope"))
})

test_that("sm_fetch_pubmed native parses esearch+efetch into an sm_corpus", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .pubmed_esearch_body(),
    resp_body_string = function(resp, ...) .pubmed_xml(),
    .package = "httr2"
  )

  corpus <- sm_fetch_pubmed(
    query = "bibliometrics", n_max = 10,
    api_key = "", engine = "native", verbose = FALSE
  )

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)
  expect_true(all(c("work_id", "doi", "title", "pmid") %in% names(corpus$works)))
  expect_equal(corpus$works$title[[1]], "First test article")
  expect_equal(corpus$works$doi[[1]], "10.1234/first")
  expect_equal(corpus$works$pmid[[1]], "11111111")
  expect_equal(corpus$works$year[[1]], 2020L)
  # MedlineDate fallback parses the leading 4 digits as the year
  expect_equal(corpus$works$year[[2]], 2019L)
  # authors + ORCID extraction
  expect_true(nrow(corpus$authors) >= 2L)
  expect_true("0000-0001-2345-6789" %in% corpus$authors$orcid)
  # MeSH concepts
  expect_true("Bibliometrics" %in% corpus$concepts$concept_name)
  # sources (journal via ISSNLinking)
  expect_true("Journal of Tests" %in% corpus$sources$display_name)
  # provenance
  expect_equal(nrow(corpus$provenance), 2L)
  expect_true(all(corpus$provenance$source == "pubmed"))
})

test_that("sm_fetch_pubmed native honours an API key path (higher rate)", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .pubmed_esearch_body("11111111"),
    resp_body_string = function(resp, ...) .pubmed_xml(),
    .package = "httr2"
  )
  corpus <- sm_fetch_pubmed(
    query = "x", n_max = 5, api_key = "SECRETKEY",
    engine = "native", verbose = FALSE
  )
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)
})

test_that("sm_fetch_pubmed verbose prints progress", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .pubmed_esearch_body(),
    resp_body_string = function(resp, ...) .pubmed_xml(),
    .package = "httr2"
  )
  expect_message(
    sm_fetch_pubmed(query = "x", n_max = 5, api_key = "",
                    engine = "native", verbose = TRUE),
    "Searching PubMed"
  )
})

test_that("sm_fetch_pubmed returns an empty corpus when esearch finds nothing", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .pubmed_esearch_body(character()),
    .package = "httr2"
  )
  corpus <- sm_fetch_pubmed(query = "noresults", api_key = "",
                            engine = "native", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_pubmed aborts when the esearch request fails", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("network down"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_pubmed(query = "x", api_key = "", engine = "native",
                    verbose = FALSE),
    "esearch request failed"
  )
})

test_that("sm_fetch_pubmed aborts when the efetch request fails", {
  calls <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      calls <<- calls + 1L
      if (calls == 1L) structure(list(), class = "httr2_response")
      else stop("efetch broke")
    },
    resp_body_json = function(resp, ...) .pubmed_esearch_body(),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_pubmed(query = "x", api_key = "", engine = "native",
                    verbose = FALSE),
    "efetch request failed"
  )
})

test_that("sm_fetch_pubmed engine='auto' falls back to native when rentrez absent", {
  local_mocked_bindings(
    is_installed = function(pkg, ...) FALSE,
    .package = "rlang"
  )
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .pubmed_esearch_body("11111111"),
    resp_body_string = function(resp, ...) .pubmed_xml(),
    .package = "httr2"
  )
  corpus <- sm_fetch_pubmed(query = "x", api_key = "", engine = "auto",
                            verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  # provenance engine recorded as native
  expect_true(all(corpus$provenance$engine == "native"))
})

test_that("sm_fetch_pubmed engine='rentrez' errors when rentrez not installed", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      cli::cli_abort("The package {.pkg rentrez} is required.")
    },
    .package = "rlang"
  )
  expect_error(
    sm_fetch_pubmed(query = "x", engine = "rentrez", verbose = FALSE),
    "rentrez"
  )
})

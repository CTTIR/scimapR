.extdata <- function(file) {
  path <- system.file("extdata", file, package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", file)
  }
  path
}

test_that(".detect_format resolves unambiguous extensions", {
  ce <- rlang::current_env()
  expect_equal(scimapR:::.detect_format("x.bib", "bib", "UTF-8", ce), "bibtex")
  expect_equal(scimapR:::.detect_format("x.ris", "ris", "UTF-8", ce), "ris")
  expect_equal(scimapR:::.detect_format("x.json", "json", "UTF-8", ce),
               "openalex-json")
  expect_equal(scimapR:::.detect_format("x.jsonl", "jsonl", "UTF-8", ce),
               "openalex-json")
  expect_equal(scimapR:::.detect_format("x.nbib", "nbib", "UTF-8", ce),
               "pubmed-xml")
  expect_equal(scimapR:::.detect_format("x.enw", "enw", "UTF-8", ce), "ris")
})

test_that(".detect_format distinguishes CSV exports by header signature", {
  ce <- rlang::current_env()
  expect_equal(
    scimapR:::.detect_format(.extdata("example_lens.csv"), "csv", "UTF-8", ce),
    "lens"
  )
  expect_equal(
    scimapR:::.detect_format(.extdata("example_dimensions.csv"), "csv",
                             "UTF-8", ce),
    "dimensions"
  )
  expect_equal(
    scimapR:::.detect_format(.extdata("example_scopus.csv"), "csv",
                             "UTF-8", ce),
    "scopus"
  )
})

test_that(".detect_format returns 'unknown' for unrecognised CSV", {
  ce <- rlang::current_env()
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("colA,colB", "1,2"), path)
  expect_equal(scimapR:::.detect_format(path, "csv", "UTF-8", ce), "unknown")
})

test_that(".detect_format identifies WoS and RIS content in plain text", {
  ce <- rlang::current_env()

  wos <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("FN Clarivate Analytics Web of Science", "PT J"), wos)
  expect_equal(scimapR:::.detect_format(wos, "txt", "UTF-8", ce), "wos")

  ris <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("TY  - JOUR", "TI  - A title", "ER  -"), ris)
  expect_equal(scimapR:::.detect_format(ris, "txt", "UTF-8", ce), "ris")
})

test_that(".detect_xml_format distinguishes PubMed from EndNote", {
  expect_equal(
    scimapR:::.detect_xml_format(.extdata("example_pubmed.xml"), "UTF-8"),
    "pubmed-xml"
  )

  endnote <- withr::local_tempfile(fileext = ".xml")
  writeLines(c('<?xml version="1.0"?>', "<xml><records>",
               "<record><rec-number>1</rec-number></record>",
               "</records></xml>"), endnote)
  expect_equal(scimapR:::.detect_xml_format(endnote, "UTF-8"), "endnote-xml")
})

test_that("sm_read_auto dispatches .bib files to the BibTeX reader", {
  corpus <- sm_read_auto(.extdata("example.bib"), verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_gt(nrow(corpus$works), 0L)
})

test_that("sm_read_auto dispatches .ris files to the RIS reader", {
  corpus <- sm_read_auto(.extdata("example.ris"), verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_gt(nrow(corpus$works), 0L)
})

test_that("sm_read_auto dispatches Lens CSV to sm_read_lens", {
  corpus <- sm_read_auto(.extdata("example_lens.csv"), verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(corpus$metadata$reader, "sm_read_lens")
  expect_equal(nrow(corpus$works), 3L)
})

test_that("sm_read_auto dispatches Dimensions CSV to sm_read_dimensions", {
  corpus <- sm_read_auto(.extdata("example_dimensions.csv"), verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(corpus$metadata$reader, "sm_read_dimensions")
  expect_equal(nrow(corpus$works), 3L)
})

test_that("sm_read_auto dispatches PubMed XML to sm_read_pubmed_xml", {
  corpus <- sm_read_auto(.extdata("example_pubmed.xml"), verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(corpus$metadata$reader, "sm_read_pubmed_xml")
  expect_equal(nrow(corpus$works), 3L)
})

test_that("sm_read_auto routes .json to the OpenAlex reader", {
  # Use a temp JSON the OpenAlex reader can parse (plain abstract field).
  path <- withr::local_tempfile(fileext = ".json")
  writeLines('[{"id":"W1","title":"T","type":"article","abstract":"x"}]', path)

  corpus <- sm_read_auto(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(corpus$metadata$reader, "sm_read_openalex_json")
})

test_that("sm_read_auto errors on an undetectable format", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("colA,colB", "1,2"), path)

  expect_error(
    sm_read_auto(path, verbose = FALSE),
    "Cannot detect bibliographic file format"
  )
})

test_that("sm_read_auto errors on a missing file", {
  expect_error(
    sm_read_auto(tempfile(fileext = ".bib"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_auto rejects an unknown engine value", {
  expect_error(
    sm_read_auto(.extdata("example.bib"), engine = "bogus", verbose = FALSE)
  )
})

test_that("sm_read_auto reports the detected format when verbose", {
  expect_message(
    sm_read_auto(.extdata("example_lens.csv"), verbose = TRUE),
    "Detected format"
  )
})

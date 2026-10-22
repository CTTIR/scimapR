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


test_that("XML roots distinguish EndNote records containing PubMed text", {
  path <- withr::local_tempfile(fileext = ".xml")
  record <- paste0("<record><titles><title>An invented study</title></titles>",
                   "<remote-database-name>PubMed</remote-database-name>",
                   "<urls><related-urls><url>",
                   "https://www.ncbi.nlm.nih.gov/pubmed/99999901",
                   "</url></related-urls></urls></record>")
  writeLines(paste0("<xml><records>", record, record, "</records></xml>"), path)
  expect_identical(.detect_xml_format(path, "UTF-8"), "endnote-xml")
  x <- sm_read_auto(path, verbose = FALSE)
  expect_equal(nrow(x$works), 2L)
  expect_identical(x$metadata$reader, "sm_read_endnote")
  writeLines("<catalog><item/></catalog>", path)
  expect_error(sm_read_auto(path, verbose = FALSE),
               class = "scimapR_unsupported_format")
  writeLines("<xml><records>", path)
  expect_error(sm_read_auto(path, verbose = FALSE),
               class = "scimapR_unreadable_file")
})

test_that("MEDLINE and Refer text get explicit unsupported-format errors", {
  for (ext in c(".nbib", ".txt")) {
    path <- withr::local_tempfile(fileext = ext)
    writeLines(c("PMID- 99999901", "TI  - An invented study"), path)
    expect_error(sm_read_auto(path, verbose = FALSE), "MEDLINE",
                 class = "scimapR_unsupported_format")
  }
  path <- withr::local_tempfile(fileext = ".enw")
  writeLines(c("%A Brandt, K", "%T An invented study"), path)
  expect_error(sm_read_auto(path, verbose = FALSE), "Refer",
               class = "scimapR_unsupported_format")
  for (ext in c(".nbib", ".enw")) {
    path <- withr::local_tempfile(fileext = ext)
    writeLines(c("TY  - JOUR", "TI  - An invented study", "ER  -"), path)
    x <- sm_read_auto(path, verbose = FALSE)
    expect_identical(x$metadata$reader, "sm_read_ris")
    expect_equal(nrow(x$works), 1L)
  }
})

test_that("WoS tab headers are detected across text extensions and BOMs", {
  source <- test_path("fixtures", "wos-tabdelim.txt")
  lines <- readLines(source, warn = FALSE)
  for (ext in c("txt", "tsv", "tab", "")) {
    suffix <- if (nzchar(ext)) paste0(".", ext) else ""
    path <- withr::local_tempfile(fileext = suffix)
    writeLines(c(paste0("\ufeff", lines[1]), lines[-1]), path, useBytes = TRUE)
    expect_identical(.detect_format(path, ext, "UTF-8", rlang::current_env()),
                     "wos")
    expect_equal(nrow(sm_read_auto(path, verbose = FALSE)$works), 3L)
  }
})

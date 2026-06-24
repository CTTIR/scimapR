.endnote_xml_fixture <- function() {
  c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    "<xml><records>",
    '<record ref-type="17">',
    "  <titles><title><style>Deep Learning for Spatial Omics</style></title>",
    "    <secondary-title><style>Nature Methods</style></secondary-title></titles>",
    "  <contributors><authors>",
    "    <author><style>Chen, Wei</style></author>",
    "    <author><style>Smith, Sarah</style></author>",
    "  </authors></contributors>",
    "  <dates><year><style>2023</style></year></dates>",
    "  <periodical><full-title><style>Nature Methods</style></full-title></periodical>",
    "  <electronic-resource-num><style>10.1038/S41592-023-00001</style></electronic-resource-num>",
    "  <abstract><style>An abstract about spatial omics.</style></abstract>",
    "  <language><style>eng</style></language>",
    "  <keywords><keyword><style>deep learning</style></keyword>",
    "    <keyword><style>omics</style></keyword></keywords>",
    "  <accession-num><style>ACC123</style></accession-num>",
    "</record>",
    '<record ref-type="2">',
    "  <titles><title><style>A Book on Methods</style></title></titles>",
    "  <contributors><authors>",
    "    <author><style>Doe, Jane</style></author>",
    "  </authors></contributors>",
    "  <dates><year><style>2020</style></year></dates>",
    "  <accession-num><style>ACC999</style></accession-num>",
    "</record>",
    "</records></xml>"
  )
}

test_that("sm_read_endnote parses a valid EndNote XML file", {
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(.endnote_xml_fixture(), path)

  corpus <- sm_read_endnote(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)

  expect_equal(corpus$works$title[1], "Deep Learning for Spatial Omics")
  expect_equal(corpus$works$title[2], "A Book on Methods")

  # DOI normalized to lowercase
  expect_equal(corpus$works$doi[1], "10.1038/s41592-023-00001")
  expect_true(is.na(corpus$works$doi[2]))

  # ref-type code mapped: 17 -> journal-article, 2 -> book
  expect_equal(corpus$works$type, c("journal-article", "book"))

  expect_identical(corpus$works$year, c(2023L, 2020L))
  expect_equal(corpus$works$language[1], "eng")
})

test_that("sm_read_endnote normalizes author names and tracks accession nums", {
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(.endnote_xml_fixture(), path)

  corpus <- sm_read_endnote(path, verbose = FALSE)

  # "Chen, Wei" -> "Wei Chen"
  expect_true("Wei Chen" %in% corpus$authors$display_name)
  expect_true("Jane Doe" %in% corpus$authors$display_name)
  expect_equal(nrow(corpus$authorships), 3L)

  expect_equal(corpus$provenance$source_id_external,
               c("ACC123", "ACC999"))
  expect_equal(corpus$provenance$source[1], "endnote")
})

test_that("sm_read_endnote extracts journals and keywords", {
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(.endnote_xml_fixture(), path)

  corpus <- sm_read_endnote(path, verbose = FALSE)

  expect_true("Nature Methods" %in% corpus$sources$display_name)
  expect_true("deep learning" %in% corpus$concepts$concept_name)
  expect_true(all(corpus$concepts$vocabulary == "author-keywords"))
  expect_equal(corpus$metadata$reader, "sm_read_endnote")
})

test_that("sm_read_endnote emits a message when verbose = TRUE", {
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(.endnote_xml_fixture(), path)

  expect_message(sm_read_endnote(path, verbose = TRUE), "Parsed")
  expect_silent(suppressMessages(sm_read_endnote(path, verbose = TRUE)))
})

test_that("sm_read_endnote returns an empty corpus with no records", {
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(c('<?xml version="1.0"?>', "<xml><records></records></xml>"), path)

  corpus <- sm_read_endnote(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_read_endnote errors on missing file", {
  expect_error(
    sm_read_endnote(tempfile(fileext = ".xml"), verbose = FALSE),
    "File not found"
  )
})

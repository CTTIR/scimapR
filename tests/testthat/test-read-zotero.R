.zotero_csv_fixture <- function() {
  c(
    paste(
      "Key,Title,Author,Publication Year,DOI,Publication Title,",
      "Abstract Note,Item Type,ISSN,Language,Manual Tags,Automatic Tags",
      sep = ""
    ),
    paste0(
      'ABC123,Spatial omics methods,"Chen, Wei; Smith, Sarah",2023,',
      '10.1038/S41592-023-00001,Nature Methods,',
      'An abstract.,journalArticle,1548-7091,eng,',
      '"tag one; tag two","auto one"'
    ),
    paste0(
      'DEF456,A Zotero Book,"Doe, Jane",2020,,',
      'Some Publisher,,book,,en,,'
    )
  )
}

test_that("sm_read_zotero parses a valid Zotero CSV export", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(.zotero_csv_fixture(), path)

  corpus <- sm_read_zotero(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)

  expect_equal(corpus$works$title, c("Spatial omics methods", "A Zotero Book"))
  expect_equal(corpus$works$doi[1], "10.1038/s41592-023-00001")
  expect_true(is.na(corpus$works$doi[2]))
  expect_identical(corpus$works$year, c(2023L, 2020L))
  expect_equal(corpus$works$type, c("journalArticle", "book"))
  expect_equal(corpus$works$language, c("eng", "en"))
})

test_that("sm_read_zotero splits semicolon authors and normalizes names", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(.zotero_csv_fixture(), path)

  corpus <- sm_read_zotero(path, verbose = FALSE)

  # "Chen, Wei" -> "Wei Chen"
  expect_true("Wei Chen" %in% corpus$authors$display_name)
  expect_true("Sarah Smith" %in% corpus$authors$display_name)
  expect_true("Jane Doe" %in% corpus$authors$display_name)
  expect_equal(nrow(corpus$authorships), 3L)
})

test_that("sm_read_zotero builds concepts from manual and automatic tags", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(.zotero_csv_fixture(), path)

  corpus <- sm_read_zotero(path, verbose = FALSE)

  expect_true("tag one" %in% corpus$concepts$concept_name)
  expect_true("auto one" %in% corpus$concepts$concept_name)
  expect_true("manual-tags" %in% corpus$concepts$vocabulary)
  expect_true("automatic-tags" %in% corpus$concepts$vocabulary)

  expect_true("Nature Methods" %in% corpus$sources$display_name)
  expect_equal(corpus$provenance$source[1], "zotero")
  expect_equal(corpus$provenance$source_id_external[1], "ABC123")
  expect_equal(corpus$metadata$reader, "sm_read_zotero")
})

test_that("sm_read_zotero emits a message when verbose = TRUE", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(.zotero_csv_fixture(), path)

  expect_message(sm_read_zotero(path, verbose = TRUE), "Parsed")
})

test_that("sm_read_zotero errors on missing file", {
  expect_error(
    sm_read_zotero(tempfile(fileext = ".csv"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_zotero returns empty corpus on header-only file", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines("Key,Title,Author,Publication Year,DOI", path)

  corpus <- sm_read_zotero(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

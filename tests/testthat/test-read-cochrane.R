test_that("sm_read_cochrane parses a CSV export", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Record Number,Authors,Title,Source,Year,DOI,Abstract,Type",
    paste0(
      '1,"Chen, Wei; Smith, Sarah",A Cochrane review,',
      'Cochrane Database Syst Rev,2023,10.1002/14651858.CD001,',
      'An abstract.,Systematic Review'
    ),
    paste0(
      '2,"Doe, Jane",Another review,',
      'Cochrane Database Syst Rev,2021,10.1002/14651858.CD002,,Review'
    )
  ), path)

  corpus <- sm_read_cochrane(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)
  expect_equal(corpus$works$title, c("A Cochrane review", "Another review"))
  expect_equal(corpus$works$doi[1], "10.1002/14651858.cd001")
  expect_identical(corpus$works$year, c(2023L, 2021L))
  expect_equal(corpus$works$type, c("Systematic Review", "Review"))

  expect_true("Wei Chen" %in% corpus$authors$display_name)
  expect_equal(corpus$provenance$source[1], "cochrane")
  expect_equal(corpus$provenance$source_id_external[1], "1")
  expect_equal(corpus$metadata$reader, "sm_read_cochrane")
})

test_that("sm_read_cochrane parses a TSV export", {
  path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(c(
    "Record Number\tAuthors\tTitle\tSource\tYear\tDOI",
    "5\tRoe, Richard\tA TSV review\tCochrane\t2019\t10.1002/14651858.CD009"
  ), path)

  corpus <- sm_read_cochrane(path, verbose = FALSE)
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title[1], "A TSV review")
  # A single "Last, First" with no semicolon is split on the comma-before-capital
  # rule, yielding two separate author tokens.
  expect_true(all(c("Roe", "Richard") %in% corpus$authors$display_name))
  expect_equal(corpus$provenance$source_id_external[1], "5")
})

test_that("sm_read_cochrane delegates RIS-format files to the RIS parser", {
  path <- withr::local_tempfile(fileext = ".ris")
  writeLines(c(
    "TY  - JOUR",
    "AU  - Chen, Wei",
    "TI  - A Cochrane RIS record",
    "JO  - Cochrane Database Syst Rev",
    "PY  - 2022",
    "DO  - 10.1002/14651858.CD555",
    "ER  -"
  ), path)

  corpus <- sm_read_cochrane(path, verbose = FALSE)

  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title[1], "A Cochrane RIS record")
  expect_equal(corpus$works$doi[1], "10.1002/14651858.cd555")
  # Delegation re-labels provenance source and reader as cochrane
  expect_equal(corpus$provenance$source[1], "cochrane")
  expect_equal(corpus$metadata$reader, "sm_read_cochrane")
})

test_that("sm_read_cochrane detects RIS content even with a .txt extension", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "TY  - JOUR",
    "AU  - Doe, Jane",
    "TI  - RIS in a txt file",
    "PY  - 2020",
    "ER  -"
  ), path)

  corpus <- sm_read_cochrane(path, verbose = FALSE)
  expect_equal(corpus$works$title[1], "RIS in a txt file")
  expect_equal(corpus$provenance$source[1], "cochrane")
})

test_that("sm_read_cochrane emits a message when verbose = TRUE", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Record Number,Authors,Title,Year,DOI",
    '1,"Doe, Jane",A Title,2020,10.1/AB'
  ), path)

  expect_message(sm_read_cochrane(path, verbose = TRUE), "Parsed")
})

test_that("sm_read_cochrane errors on missing file", {
  expect_error(
    sm_read_cochrane(tempfile(fileext = ".csv"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_cochrane returns empty corpus on header-only CSV", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines("Record Number,Authors,Title,Year,DOI", path)

  corpus <- sm_read_cochrane(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_read_cochrane validates the engine argument", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Record Number,Title", "1,Foo"), path)
  expect_error(sm_read_cochrane(path, engine = "invalid", verbose = FALSE))
})

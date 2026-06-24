test_that("sm_read_ris parses the bundled example.ris fixture", {
  path <- system.file("extdata", "example.ris", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example.ris")
  }
  expect_true(file.exists(path))

  corpus <- sm_read_ris(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 3L)

  # Titles parsed correctly (in order)
  expect_match(corpus$works$title[1],
               "Spatial transcriptomics reveals tumor microenvironment")
  expect_match(corpus$works$title[3], "Atlas of Spatial Omics")

  # DOI normalized to lowercase
  expect_equal(corpus$works$doi[1], "10.1038/s41591-023-02345-6")

  # Year coerced to integer
  expect_identical(corpus$works$year, c(2023L, 2022L, 2024L))

  # Types preserved from TY tag
  expect_equal(corpus$works$type, c("JOUR", "CONF", "BOOK"))

  # Abstract captured
  expect_match(corpus$works$abstract[1], "Spatial transcriptomics enables")
})

test_that("sm_read_ris builds authors with Last, First normalization", {
  path <- system.file("extdata", "example.ris", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example.ris")
  }
  corpus <- sm_read_ris(path, verbose = FALSE)

  # 9 authorship rows (3 per record)
  expect_equal(nrow(corpus$authorships), 9L)
  # "Chen, Wei" -> "Wei Chen"
  expect_true("Wei Chen" %in% corpus$authors$display_name)
  expect_true("Sarah Smith" %in% corpus$authors$display_name)

  # First author flagged corresponding
  first_ws <- corpus$authorships[corpus$authorships$work_id ==
                                   corpus$works$work_id[1], ]
  first_ws <- first_ws[order(first_ws$position), ]
  expect_true(first_ws$is_corresponding[1])
  expect_false(first_ws$is_corresponding[2])
})

test_that("sm_read_ris extracts journals as sources", {
  path <- system.file("extdata", "example.ris", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example.ris")
  }
  corpus <- sm_read_ris(path, verbose = FALSE)

  expect_true("Nature Medicine" %in% corpus$sources$display_name)
  expect_equal(corpus$provenance$source[1], "ris")
  expect_equal(corpus$metadata$reader, "sm_read_ris")
})

test_that("sm_read_ris emits messages when verbose = TRUE", {
  path <- withr::local_tempfile(fileext = ".ris")
  writeLines(c(
    "TY  - JOUR",
    "AU  - Doe, Jane",
    "TI  - A Verbose Test Title",
    "PY  - 2020",
    "KW  - testing",
    "KW  - parsers",
    "DO  - 10.1000/XYZ",
    "ER  -"
  ), path)

  expect_message(sm_read_ris(path, verbose = TRUE), "Parsed")
  expect_silent(suppressMessages(sm_read_ris(path, verbose = TRUE)))
})

test_that("sm_read_ris parses keywords into concepts and normalizes DOI case", {
  path <- withr::local_tempfile(fileext = ".ris")
  writeLines(c(
    "TY  - JOUR",
    "AU  - Doe, Jane",
    "TI  - Keyword Title",
    "PY  - 2020",
    "KW  - alpha",
    "KW  - beta",
    "DO  - 10.1000/XYZ",
    "ER  -"
  ), path)

  corpus <- sm_read_ris(path, verbose = FALSE)
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$doi[1], "10.1000/xyz")
  expect_setequal(corpus$concepts$concept_name, c("alpha", "beta"))
  expect_true(all(corpus$concepts$vocabulary == "author-keywords"))
})

test_that("sm_read_ris errors on missing file", {
  expect_error(
    sm_read_ris(tempfile(fileext = ".ris"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_ris returns empty corpus when no TY records present", {
  path <- withr::local_tempfile(fileext = ".ris")
  writeLines(c("Some random text", "not a RIS file at all"), path)

  corpus <- sm_read_ris(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_read_ris validates the engine argument", {
  path <- system.file("extdata", "example.ris", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example.ris")
  }
  expect_error(sm_read_ris(path, engine = "not_an_engine", verbose = FALSE))
})

test_that("sm_read_wos parses the bundled example_wos.txt fixture", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  expect_true(file.exists(path))

  corpus <- sm_read_wos(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 3L)

  expect_match(corpus$works$title[1],
               "Spatial transcriptomics reveals tumor microenvironment")
  expect_equal(corpus$works$doi[1], "10.1038/s41591-023-02345-6")
  expect_identical(corpus$works$year, c(2023L, 2022L, 2024L))
  expect_equal(corpus$works$type, c("Article", "Article", "Review"))
  expect_identical(corpus$works$cited_by_count, c(42L, 18L, 7L))
})

test_that("sm_read_wos handles AU continuation lines and name normalization", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  corpus <- sm_read_wos(path, verbose = FALSE)

  # Three authors per record via continuation lines
  expect_equal(nrow(corpus$authorships), 9L)
  # "Chen, W" -> "W Chen"
  expect_true("W Chen" %in% corpus$authors$display_name)
  expect_true("S Smith" %in% corpus$authors$display_name)
})

test_that("sm_read_wos captures sources, UT identifier, and provenance", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  corpus <- sm_read_wos(path, verbose = FALSE)

  expect_true("NATURE MEDICINE" %in% corpus$sources$display_name)
  expect_equal(corpus$provenance$source[1], "wos")
  expect_equal(corpus$provenance$source_id_external[1], "WOS:000912345600001")
  expect_equal(corpus$metadata$reader, "sm_read_wos")
})

test_that("sm_read_wos parses keywords, keywords-plus and subject categories", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "PT J",
    "AU Smith, J",
    "TI WoS Concept Title",
    "SO SOME JOURNAL",
    "DE keyword one; keyword two",
    "ID PLUS ONE; PLUS TWO",
    "SC Oncology; Genetics",
    "DI 10.1/ABC",
    "PY 2021",
    "TC 3",
    "UT WOS:000000000000001",
    "ER",
    "",
    "EF"
  ), path)

  corpus <- sm_read_wos(path, verbose = FALSE)
  expect_equal(nrow(corpus$works), 1L)
  expect_true("keyword one" %in% corpus$concepts$concept_name)
  expect_true("author-keywords" %in% corpus$concepts$vocabulary)
  expect_true("keywords-plus" %in% corpus$concepts$vocabulary)
  expect_true("wos-subject-category" %in% corpus$concepts$vocabulary)
})

test_that("sm_read_wos extracts cited references with DOIs", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "PT J",
    "AU Smith, J",
    "TI A Title With References",
    "SO SOME JOURNAL",
    "DI 10.1/MAIN",
    "PY 2021",
    "CR Doe J, 2010, J TEST, V1, P1, DOI 10.9/REF1",
    "   Roe R, 2011, J TEST, V2, P2, DOI 10.9/REF2",
    "UT WOS:000000000000002",
    "ER",
    "",
    "EF"
  ), path)

  corpus <- sm_read_wos(path, verbose = FALSE)
  expect_equal(nrow(corpus$references), 2L)
  expect_true("10.9/ref1" %in% corpus$references$cited_doi)
})

test_that("sm_read_wos emits a message when verbose = TRUE", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  expect_message(sm_read_wos(path, verbose = TRUE), "Parsed")
})

test_that("sm_read_wos errors on missing file", {
  expect_error(
    sm_read_wos(tempfile(fileext = ".txt"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_wos returns empty corpus when no PT records present", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("FN Clarivate", "VR 1.0", "EF"), path)

  corpus <- sm_read_wos(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_read_wos validates the engine argument", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  expect_error(sm_read_wos(path, engine = "nope", verbose = FALSE))
})

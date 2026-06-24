test_that("sm_read_scopus parses the bundled example_scopus.csv fixture", {
  path <- system.file("extdata", "example_scopus.csv", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_scopus.csv")
  }
  expect_true(file.exists(path))

  corpus <- sm_read_scopus(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 3L)

  expect_match(corpus$works$title[1],
               "Spatial transcriptomics reveals tumor microenvironment")
  expect_equal(corpus$works$doi[1], "10.1038/s41591-023-02345-6")
  expect_identical(corpus$works$year, c(2023L, 2022L, 2024L))
  expect_equal(corpus$works$type, c("Article", "Conference Paper", "Review"))
  expect_identical(corpus$works$cited_by_count, c(42L, 18L, 7L))
  expect_equal(corpus$works$language, c("English", "English", "English"))
})

test_that("sm_read_scopus parses 'Last A.B.' author strings", {
  path <- system.file("extdata", "example_scopus.csv", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_scopus.csv")
  }
  corpus <- sm_read_scopus(path, verbose = FALSE)

  # "Chen W., Smith S., Tanaka Y." -> three authors
  expect_equal(nrow(corpus$authorships), 9L)
  expect_true("Chen W." %in% corpus$authors$display_name)
  expect_true("Smith S." %in% corpus$authors$display_name)
})

test_that("sm_read_scopus extracts author keywords as concepts", {
  path <- system.file("extdata", "example_scopus.csv", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_scopus.csv")
  }
  corpus <- sm_read_scopus(path, verbose = FALSE)

  expect_true("colorectal cancer" %in% corpus$concepts$concept_name)
  expect_true(all(corpus$concepts$vocabulary %in%
                    c("author-keywords", "index-keywords")))
  expect_true("Nature Medicine" %in% corpus$sources$display_name)
  expect_equal(corpus$provenance$source[1], "scopus")
})

test_that("sm_read_scopus emits a message when verbose = TRUE", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Authors,Title,Year,Source title,DOI,Cited by",
    '"Doe J.",A Scopus Title,2021,Some Journal,10.1/AB,5'
  ), path)

  expect_message(sm_read_scopus(path, verbose = TRUE), "Parsed")
})

test_that("sm_read_scopus handles semicolon-separated authors and DOI case", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Authors,Title,Year,DOI,Author Keywords,Index Keywords",
    '"Doe, Jane; Roe, Richard",Semicolon Authors,2019,10.5/XYZ,kw1; kw2,ik1'
  ), path)

  corpus <- sm_read_scopus(path, verbose = FALSE)
  expect_equal(corpus$works$doi[1], "10.5/xyz")
  # Semicolon-separated names are kept verbatim (no Last, First normalization)
  expect_true("Doe, Jane" %in% corpus$authors$display_name)
  expect_true("Roe, Richard" %in% corpus$authors$display_name)
  expect_equal(nrow(corpus$authorships), 2L)
  expect_true(any(corpus$concepts$vocabulary == "index-keywords"))
})

test_that("sm_read_scopus errors on missing file", {
  expect_error(
    sm_read_scopus(tempfile(fileext = ".csv"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_scopus returns empty corpus on header-only file", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines("Authors,Title,Year,DOI", path)

  corpus <- sm_read_scopus(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_read_scopus validates the engine argument", {
  path <- system.file("extdata", "example_scopus.csv", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_scopus.csv")
  }
  expect_error(sm_read_scopus(path, engine = "bogus", verbose = FALSE))
})

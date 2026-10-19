.dimensions_fixture <- function() {
  path <- system.file("extdata", "example_dimensions.csv", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_dimensions.csv")
  }
  path
}

test_that("sm_read_dimensions parses the bundled example_dimensions.csv", {
  path <- .dimensions_fixture()
  expect_true(file.exists(path))

  corpus <- sm_read_dimensions(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 3L)

  expect_match(corpus$works$title[1],
               "Spatial transcriptomics reveals tumor microenvironment")
  expect_equal(corpus$works$doi[1], "10.1038/s41591-023-02345-6")
  expect_identical(corpus$works$year, c(2023L, 2022L, 2024L))
  expect_identical(corpus$works$cited_by_count, c(42L, 18L, 7L))
  expect_equal(corpus$works$type, c("Article", "Article", "Review"))
})

test_that("sm_read_dimensions parses 'Last, First' author strings", {
  path <- .dimensions_fixture()
  corpus <- sm_read_dimensions(path, verbose = FALSE)

  # 3 authors x 3 works
  expect_equal(nrow(corpus$authorships), 9L)
  expect_true("Chen, Wei" %in% corpus$authors$display_name)
  expect_true("Garcia, Maria" %in% corpus$authors$display_name)
})

test_that("sm_read_dimensions records sources and provenance", {
  path <- .dimensions_fixture()
  corpus <- sm_read_dimensions(path, verbose = FALSE)

  expect_true("Nature Medicine" %in% corpus$sources$display_name)
  expect_true("Genome Biology" %in% corpus$sources$display_name)
  expect_false(any(is.na(corpus$works$source_id)))
  expect_equal(unique(corpus$provenance$source), "dimensions")
})

test_that("sm_read_dimensions skips preamble lines before the header", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Dimensions export information",
    "Generated 2024",
    paste0("Title,DOI,Authors,Source title,PubYear,Times cited,",
           "Document Type,Abstract,MeSH terms,Author Keywords,",
           "Dimensions ID,ISSN"),
    paste0('My Paper,10.1/x,"Doe, Jane; Roe, Sam",J Sci,2021,10,Article,',
           'An abstract.,Neoplasms; Genes,spatial; cancer,pub.123,9999-8888')
  ), path)

  corpus <- sm_read_dimensions(path, verbose = FALSE)

  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title, "My Paper")
  expect_equal(corpus$works$year, 2021L)
  expect_equal(corpus$works$cited_by_count, 10L)
  expect_setequal(corpus$authors$display_name, c("Doe, Jane", "Roe, Sam"))
  expect_equal(corpus$sources$issn_l[1], "9999-8888")
  expect_equal(corpus$provenance$source_id_external[1], "pub.123")
})

test_that("sm_read_dimensions extracts keyword + MeSH concepts", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    paste0("Title,DOI,Authors,Source title,PubYear,Times cited,",
           "Document Type,Abstract,MeSH terms,Author Keywords,",
           "Dimensions ID,ISSN"),
    paste0('My Paper,10.1/x,"Doe, Jane",J Sci,2021,10,Article,',
           'An abstract.,Neoplasms; Genes,spatial; cancer,pub.123,9999-8888')
  ), path)

  corpus <- sm_read_dimensions(path, verbose = FALSE)

  expect_setequal(corpus$concepts$concept_name,
                  c("spatial", "cancer", "Neoplasms", "Genes"))
  expect_setequal(unique(corpus$concepts$vocabulary),
                  c("author-keywords", "mesh"))
  expect_true(all(corpus$concepts$vocabulary %in% sm_concept_vocabularies()))
})

test_that("sm_read_dimensions returns an empty corpus for header-only files", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines("Title,DOI,Authors", path)

  corpus <- sm_read_dimensions(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
  expect_equal(corpus$metadata$reader, "sm_read_dimensions")
})

test_that("sm_read_dimensions errors on a missing file", {
  expect_error(
    sm_read_dimensions(tempfile(fileext = ".csv"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_dimensions rejects an unknown engine value", {
  path <- .dimensions_fixture()
  expect_error(sm_read_dimensions(path, engine = "bogus", verbose = FALSE))
})

test_that("sm_read_dimensions emits a progress message only when verbose", {
  path <- .dimensions_fixture()
  expect_message(sm_read_dimensions(path, verbose = TRUE), "Dimensions")
  expect_silent(sm_read_dimensions(path, verbose = FALSE))
})

test_that("sm_read_dimensions reads the Corresponding Authors column", {
  # the bundled file has no such column: every author is unknown (NA)
  a <- sm_read_dimensions(.dimensions_fixture(), verbose = FALSE)$authorships
  expect_true(all(is.na(a$is_corresponding)))

  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Title,DOI,Authors,Corresponding Authors,PubYear",
    paste0("First,10.9999/dim.1,\"Chen, Wei; Smith, Sarah; Tanaka, Yuki\",",
           "\"Sarah Smith (Univ of Westhaven)\",2023"),
    "Second,10.9999/dim.2,\"Patel, Priya; Mueller, Anna\",,2022",
    "Third,10.9999/dim.3,\"Zhang, Wei; Johnson, James\",\"Doe, Jane\",2024",
    paste0("Fourth,10.9999/dim.4,\"Wang, Yan; Li, Xin; Wang, Yu\",",
           "\"Wang, Yu\",2024"),
    paste0("Fifth,10.9999/dim.5,\"Wang, Yan; Li, Xin; Wang, Yu\",",
           "\"Wang, Y\",2024")
  ), path)
  corpus <- sm_read_dimensions(path, verbose = FALSE)
  a <- corpus$authorships
  w <- match(a$work_id, corpus$works$work_id)
  expect_identical(a$is_corresponding[w == 1L], c(FALSE, TRUE, FALSE))
  # no corresponding author, or one who is not an author of the record
  expect_identical(a$is_corresponding[w %in% 2:3], rep(NA, 4))
  # a full name tells namesakes apart; "Wang, Y" does not, so the work
  # stays unknown instead of flagging the first Wang
  expect_identical(a$is_corresponding[w == 4L], c(FALSE, FALSE, TRUE))
  expect_identical(a$is_corresponding[w == 5L], rep(NA, 3))
})

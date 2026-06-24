.lens_fixture <- function() {
  path <- system.file("extdata", "example_lens.csv", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_lens.csv")
  }
  path
}

test_that("sm_read_lens parses the bundled example_lens.csv fixture", {
  path <- .lens_fixture()
  expect_true(file.exists(path))

  corpus <- sm_read_lens(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 3L)

  expect_match(corpus$works$title[1],
               "Spatial transcriptomics reveals tumor microenvironment")
  expect_equal(corpus$works$doi[1], "10.1038/s41591-023-02345-6")
  expect_identical(corpus$works$year, c(2023L, 2022L, 2024L))
  expect_identical(corpus$works$cited_by_count, c(42L, 18L, 7L))
  expect_equal(corpus$works$type,
               c("Journal Article", "Journal Article", "Review"))
})

test_that("sm_read_lens builds authors from semicolon-separated strings", {
  path <- .lens_fixture()
  corpus <- sm_read_lens(path, verbose = FALSE)

  # 3 authors x 3 works = 9 authorships, all distinct names here
  expect_equal(nrow(corpus$authorships), 9L)
  expect_equal(nrow(corpus$authors), 9L)
  expect_true("Chen Wei" %in% corpus$authors$display_name)
  expect_true("Tanaka Yuki" %in% corpus$authors$display_name)

  # First author of each work is flagged corresponding
  first_pos <- corpus$authorships[corpus$authorships$position == 1L, ]
  expect_true(all(first_pos$is_corresponding))
})

test_that("sm_read_lens records sources and provenance", {
  path <- .lens_fixture()
  corpus <- sm_read_lens(path, verbose = FALSE)

  expect_true("Nature Medicine" %in% corpus$sources$display_name)
  expect_true("Bioinformatics" %in% corpus$sources$display_name)
  # every work has a source_id assigned
  expect_false(any(is.na(corpus$works$source_id)))

  expect_equal(unique(corpus$provenance$source), "lens")
  expect_equal(corpus$provenance$source_id_external[1], "012-345-678-901-234")
})

test_that("sm_read_lens extracts MeSH and keyword concepts with vocabularies", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    paste0("Lens ID,Title,Year Published,DOI,Source Title,Authors,Abstract,",
           "Scholarly Citations Count,Publication Type,MeSH Terms,Keywords,",
           "Source ISSN,Language,PMID"),
    paste0('111-222,My Lens Paper,2020,10.5/y,J Lens,Aa Bb; Cc Dd,Abstr.,5,',
           'Journal Article,TermA; TermB,kw1; kw2,1111-2222,en,55555')
  ), path)

  corpus <- sm_read_lens(path, verbose = FALSE)

  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$language, "en")
  expect_equal(corpus$works$pmid, "55555")
  expect_equal(corpus$works$cited_by_count, 5L)
  expect_equal(corpus$works$type, "Journal Article")
  expect_equal(corpus$sources$issn_l[1], "1111-2222")

  expect_setequal(corpus$concepts$concept_name,
                  c("TermA", "TermB", "kw1", "kw2"))
  expect_setequal(unique(corpus$concepts$vocabulary),
                  c("mesh", "author-keywords"))
})

test_that("sm_read_lens returns an empty corpus for header-only files", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines("Lens ID,Title,DOI", path)

  corpus <- sm_read_lens(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
  expect_equal(corpus$metadata$reader, "sm_read_lens")
})

test_that("sm_read_lens errors on a missing file", {
  expect_error(
    sm_read_lens(tempfile(fileext = ".csv"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_lens rejects an unknown engine value", {
  path <- .lens_fixture()
  expect_error(sm_read_lens(path, engine = "bogus", verbose = FALSE))
})

test_that("sm_read_lens emits a progress message only when verbose", {
  path <- .lens_fixture()
  expect_message(sm_read_lens(path, verbose = TRUE), "Lens")
  expect_silent(sm_read_lens(path, verbose = FALSE))
})

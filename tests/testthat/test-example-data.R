test_that("sm_example_corpus returns a valid corpus with defaults", {
  corpus <- sm_example_corpus()

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 200L)
  expect_equal(nrow(corpus$authors), 80L)
  expect_true(!is.null(corpus$embeddings))
  expect_equal(ncol(corpus$embeddings), 64L)
})

test_that("sm_example_corpus respects custom arguments", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              year_range = c(2020L, 2023L),
                              n_clusters = 3L,
                              with_embeddings = FALSE,
                              seed = 99)

  expect_equal(nrow(corpus$works), 30L)
  expect_equal(nrow(corpus$authors), 10L)
  expect_null(corpus$embeddings)
  expect_true(all(corpus$works$year >= 2020L & corpus$works$year <= 2023L))
})

test_that("sm_example_corpus is reproducible with same seed", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 123)
  c2 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 123)

  expect_identical(c1$works$doi, c2$works$doi)
  expect_identical(c1$works$title, c2$works$title)
})

test_that("sm_example_corpus includes screening when requested", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_screening = TRUE,
                              with_embeddings = FALSE, seed = 1)

  expect_gt(nrow(corpus$screening), 0L)
  expect_true(all(c("work_id", "stage", "decision") %in%
                    names(corpus$screening)))
})

test_that("sm_example_corpus validates successfully", {
  corpus <- sm_example_corpus(n_works = 50, seed = 7)
  expect_no_error(validate_sm_corpus(corpus))
})

test_that("sm_example_files lists available files", {
  # This will only work when the package is installed or extdata is present
  skip_if_not(
    nzchar(system.file("extdata", package = "scimapR")),
    message = "Package not installed; extdata not accessible"
  )

  files <- sm_example_files()
  expect_type(files, "character")
  expect_gt(length(files), 0L)
})

test_that("sm_example_files returns a path for a known file", {
  skip_if_not(
    nzchar(system.file("extdata", package = "scimapR")),
    message = "Package not installed; extdata not accessible"
  )

  path <- sm_example_files("example.bib")
  expect_true(file.exists(path))
})

test_that("sm_example_files errors for unknown file", {
  skip_if_not(
    nzchar(system.file("extdata", package = "scimapR")),
    message = "Package not installed; extdata not accessible"
  )

  expect_error(sm_example_files("nonexistent_file.xyz"), "not found")
})

# Tests for R/export-zip.R (sm_export_zip).

test_that("sm_export_zip rejects a non-corpus input", {
  expect_error(sm_export_zip(list(), tempfile(fileext = ".zip")),
               class = "rlang_error")
})

test_that("sm_export_zip builds a zip with rds and certificate", {
  skip_if_not_installed("yaml")
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  path <- withr::local_tempfile(fileext = ".zip")

  ret <- sm_export_zip(corpus, path, include = c("rds", "certificate"))
  expect_equal(ret, path)
  expect_true(file.exists(path))
  expect_gt(file.size(path), 0)

  contents <- utils::unzip(path, list = TRUE)$Name
  expect_true("corpus.rds" %in% contents)
  expect_true("certificate.yaml" %in% contents)
  expect_true("README.md" %in% contents)
})

test_that("sm_export_zip can include xlsx tables", {
  skip_if_not_installed("openxlsx2")
  skip_if_not_installed("yaml")
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 2)
  path <- withr::local_tempfile(fileext = ".zip")

  sm_export_zip(corpus, path,
                include = c("rds", "certificate", "tables"))
  contents <- utils::unzip(path, list = TRUE)$Name
  # The "-j" flag flattens paths, so tables land at the top level.
  expect_true("works.xlsx" %in% contents)
  expect_true("authors.xlsx" %in% contents)
})

test_that("sm_export_zip README reports work and author counts", {
  skip_if_not_installed("yaml")
  corpus <- sm_example_corpus(n_works = 7, n_authors = 5,
                              with_embeddings = FALSE, seed = 3)
  path <- withr::local_tempfile(fileext = ".zip")
  sm_export_zip(corpus, path, include = c("rds"))

  exdir <- withr::local_tempdir()
  utils::unzip(path, files = "README.md", exdir = exdir)
  readme <- paste(readLines(file.path(exdir, "README.md")), collapse = "\n")
  expect_match(readme, "Works: 7")
  expect_match(readme, "Authors: 5")
  expect_match(readme, "scimapR Corpus Bundle")
})

test_that("sm_export_zip errors early when openxlsx2 is unavailable for tables", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  path <- withr::local_tempfile(fileext = ".zip")
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      rlang::abort(paste0("The package `", pkg, "` is required."))
    },
    .package = "rlang"
  )
  expect_error(
    sm_export_zip(corpus, path, include = c("tables")),
    "openxlsx2"
  )
})

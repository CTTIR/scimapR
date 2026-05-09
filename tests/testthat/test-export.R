test_that("sm_export_figure writes a PNG file", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  p <- sm_plot_production(corpus)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "test_fig.png")

  result <- sm_export_figure(p, path, multi_dpi = FALSE)

  expect_true(file.exists(path))
  expect_type(result, "character")
})

test_that("sm_export_figure writes PDF (vector format)", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  p <- sm_plot_production(corpus)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "test_fig.pdf")

  result <- sm_export_figure(p, path, format = "pdf")

  expect_true(file.exists(path))
})

test_that("sm_export_figure multi_dpi creates multiple files", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  p <- sm_plot_production(corpus)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "test_fig.png")

  result <- sm_export_figure(p, path, multi_dpi = TRUE)

  expect_length(result, 2L)
  expect_true(all(file.exists(result)))
})

test_that("sm_export_table writes an XLSX file", {
  dat <- data.frame(Author = "Smith J", Works = 10L, Citations = 150L)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "test_table.xlsx")

  result <- sm_export_table(dat, path)

  expect_true(file.exists(path))
  expect_equal(result, path)
})

test_that("sm_export_table writes a CSV file", {
  dat <- data.frame(Author = "Smith J", Works = 10L, Citations = 150L)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "test_table.csv")

  result <- sm_export_table(dat, path, format = "csv")

  expect_true(file.exists(path))
  # Read back and check
  read_back <- readr::read_csv(path, show_col_types = FALSE)
  expect_equal(nrow(read_back), 1L)
  expect_equal(read_back$Author, "Smith J")
})

test_that("sm_export_rds writes and is readable", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "test_corpus.rds")

  result <- sm_export_rds(corpus, path)

  expect_true(file.exists(path))
  expect_equal(result, path)

  # Read it back
  loaded <- readRDS(path)
  expect_s3_class(loaded, "sm_corpus")
  expect_equal(nrow(loaded$works), 10L)
})

test_that("sm_export_csv writes corpus tables to directory", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)

  tmpdir <- withr::local_tempdir()
  outdir <- file.path(tmpdir, "csv_export")

  result <- sm_export_csv(corpus, outdir)

  expect_true(dir.exists(outdir))
  expect_true(file.exists(file.path(outdir, "works.csv")))
  expect_true(file.exists(file.path(outdir, "authors.csv")))
  expect_equal(result, outdir)
})

test_that("sm_export_rds rejects non-corpus input", {
  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "bad.rds")
  expect_error(sm_export_rds("not_a_corpus", path), "sm_corpus")
})

test_that("sm_export_csv rejects non-corpus input", {
  tmpdir <- withr::local_tempdir()
  expect_error(sm_export_csv("not_a_corpus", tmpdir), "sm_corpus")
})

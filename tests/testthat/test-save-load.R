test_that("sm_save_corpus and sm_load_corpus round-trip", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 8,
                              with_embeddings = TRUE, seed = 1)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "test_corpus.rds")

  result_path <- sm_save_corpus(corpus, path)

  expect_true(file.exists(path))
  expect_equal(result_path, path)

  loaded <- sm_load_corpus(path)

  expect_s3_class(loaded, "sm_corpus")
  expect_equal(nrow(loaded$works), nrow(corpus$works))
  expect_equal(nrow(loaded$authors), nrow(corpus$authors))
  expect_identical(loaded$works$doi, corpus$works$doi)
  expect_identical(loaded$works$title, corpus$works$title)
})

test_that("sm_save_corpus preserves embeddings", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = TRUE, seed = 1)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "emb_corpus.rds")

  sm_save_corpus(corpus, path)
  loaded <- sm_load_corpus(path)

  expect_true(!is.null(loaded$embeddings))
  expect_equal(dim(loaded$embeddings), dim(corpus$embeddings))
})

test_that("sm_load_corpus validates the loaded corpus", {
  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "invalid.rds")

  # Save a non-corpus object as RDS
  saveRDS(list(x = 1), path)

  expect_error(sm_load_corpus(path), "sm_corpus")
})

test_that("sm_load_corpus errors for missing file", {
  expect_error(sm_load_corpus("nonexistent_file_12345.rds"),
               "not found")
})

test_that("sm_save_corpus rejects non-corpus input", {
  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "bad.rds")
  expect_error(sm_save_corpus("not_a_corpus", path), "sm_corpus")
})

test_that("sm_save_corpus rejects non-string path", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_save_corpus(corpus, 42), "single string")
})

test_that("round-trip preserves screening and provenance", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE,
                              with_screening = TRUE, seed = 1)

  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "screening_corpus.rds")

  sm_save_corpus(corpus, path)
  loaded <- sm_load_corpus(path)

  expect_equal(nrow(loaded$provenance), nrow(corpus$provenance))
  expect_equal(nrow(loaded$screening), nrow(corpus$screening))
})

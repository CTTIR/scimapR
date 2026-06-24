# Tests for R/snapshot.R (sm_snapshot / sm_snapshot_load).

test_that("sm_snapshot rejects a non-corpus input", {
  expect_error(sm_snapshot(list(), path = tempfile()),
               class = "rlang_error")
})

test_that("sm_snapshot validates compress argument", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  # match.arg() raises a base error, not an rlang condition.
  expect_error(
    sm_snapshot(corpus, path = tempfile(fileext = ".rds"),
                compress = "lz4"),
    "should be one of"
  )
})

# KNOWN BUG: `compress = "none"` is accepted by match.arg() but then passed
# straight to saveRDS(), which rejects the string "none" (it expects a logical
# or one of "gzip"/"bzip2"/"xz"). So the documented "none" option errors.
test_that("sm_snapshot compress = 'none' currently errors (known bug)", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 11)
  path <- withr::local_tempfile(fileext = ".rds")
  expect_error(
    suppressMessages(sm_snapshot(corpus, path = path, compress = "none")),
    "compress"
  )
})

test_that("sm_snapshot errors when the parent directory is missing", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  bad <- file.path(tempfile(), "nope", "x.rds")
  expect_error(
    sm_snapshot(corpus, path = bad),
    "Directory does not exist"
  )
})

test_that("sm_snapshot writes a file and round-trips via sm_snapshot_load", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 3)
  path <- withr::local_tempfile(fileext = ".rds")

  ret <- suppressMessages(sm_snapshot(corpus, path = path, compress = "gzip"))
  expect_equal(ret, path)
  expect_true(file.exists(path))

  loaded <- suppressMessages(sm_snapshot_load(path))
  expect_s3_class(loaded, "sm_corpus")
  expect_identical(nrow(loaded$works), nrow(corpus$works))
  expect_identical(nrow(loaded$authors), nrow(corpus$authors))
  # Hash was stored in metadata on save.
  expect_false(is.na(loaded$metadata$corpus_hash))
})

test_that("sm_snapshot generates a default filename when path is NULL", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)

  path <- suppressMessages(sm_snapshot(corpus, path = NULL))
  expect_true(file.exists(path))
  expect_match(basename(path), "^scimapR_corpus_\\d{8}_[0-9a-f]{8}\\.rds$")
})

test_that("sm_snapshot_load errors on a non-string path", {
  expect_error(sm_snapshot_load(123), class = "rlang_error")
})

test_that("sm_snapshot_load errors when the file does not exist", {
  expect_error(
    sm_snapshot_load(file.path(tempfile(), "missing.rds")),
    class = "rlang_error"
  )
})

test_that("sm_snapshot_load rejects a file that is not an sm_corpus", {
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(list(a = 1), path)
  expect_error(
    sm_snapshot_load(path),
    "valid"
  )
})

test_that("sm_snapshot_load warns on a tampered (hash-mismatched) snapshot", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 5)
  path <- withr::local_tempfile(fileext = ".rds")
  suppressMessages(sm_snapshot(corpus, path = path, compress = "gzip"))

  # Tamper: read back, mutate works but keep the old stored hash.
  obj <- readRDS(path)
  obj$works$title[1] <- "TAMPERED TITLE"
  saveRDS(obj, path)

  expect_warning(
    suppressMessages(sm_snapshot_load(path)),
    "hash mismatch"
  )
})

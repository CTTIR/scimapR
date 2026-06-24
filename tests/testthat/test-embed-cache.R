test_that("sm_embed_save rejects non-corpus input", {
  expect_error(sm_embed_save(list(a = 1), "x.rds"), "sm_corpus")
})

test_that("sm_embed_save validates path", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = TRUE, seed = 1)
  expect_error(sm_embed_save(corpus, 123), "string")
  expect_error(sm_embed_save(corpus, ""), "non-empty")
})

test_that("sm_embed_save errors when corpus has no embeddings", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 2)
  path <- withr::local_tempfile(fileext = ".rds")
  expect_error(sm_embed_save(corpus, path), "No embeddings")
})

test_that("sm_embed_save writes an RDS cache and returns corpus invisibly", {
  corpus <- sm_example_corpus(n_works = 15, with_embeddings = TRUE, seed = 3)
  path <- withr::local_tempfile(fileext = ".rds")
  ret <- withVisible(suppressMessages(sm_embed_save(corpus, path)))
  expect_false(ret$visible)
  expect_identical(ret$value, corpus)
  expect_true(file.exists(path))
  cache <- readRDS(path)
  expect_true(all(c("embeddings", "work_ids", "timestamp",
                    "n_works", "n_dims") %in% names(cache)))
  expect_equal(cache$n_works, nrow(corpus$embeddings))
  expect_equal(cache$n_dims, ncol(corpus$embeddings))
  expect_equal(cache$work_ids, rownames(corpus$embeddings))
})

test_that("sm_embed_save creates parent directories", {
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = TRUE, seed = 4)
  base <- withr::local_tempdir()
  path <- file.path(base, "nested", "deep", "emb.rds")
  suppressMessages(sm_embed_save(corpus, path))
  expect_true(file.exists(path))
})

test_that("sm_embed_load rejects non-corpus and validates path", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = TRUE, seed = 5)
  expect_error(sm_embed_load(list(a = 1), "x.rds"), "sm_corpus")
  expect_error(sm_embed_load(corpus, 123), "string")
})

test_that("sm_embed_load errors when file does not exist", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = TRUE, seed = 6)
  expect_error(
    sm_embed_load(corpus, file.path(withr::local_tempdir(), "missing.rds")),
    "not found"
  )
})

test_that("sm_embed save/load round-trips embeddings", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = TRUE, seed = 7)
  original <- corpus$embeddings
  path <- withr::local_tempfile(fileext = ".rds")
  suppressMessages(sm_embed_save(corpus, path))

  # Load into a corpus that currently has no embeddings.
  target <- corpus
  target$embeddings <- NULL
  out <- suppressMessages(sm_embed_load(target, path))
  expect_s3_class(out, "sm_corpus")
  expect_true(is.matrix(out$embeddings))
  expect_equal(nrow(out$embeddings), nrow(original))
  # Round-trip preserves values for matching work IDs
  expect_equal(out$embeddings[rownames(original), ], original)
})

test_that("sm_embed_load supports a raw matrix cache format", {
  corpus <- sm_example_corpus(n_works = 12, with_embeddings = TRUE, seed = 8)
  mat <- corpus$embeddings
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(mat, path)
  out <- suppressMessages(sm_embed_load(corpus, path))
  expect_equal(out$embeddings[rownames(mat), ], mat)
})

test_that("sm_embed_load errors on invalid cache contents", {
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = TRUE, seed = 9)
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS("not a cache", path)
  expect_error(sm_embed_load(corpus, path), "valid embeddings cache")
})

test_that("sm_embed_load errors when cached matrix is non-numeric", {
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = TRUE, seed = 10)
  path <- withr::local_tempfile(fileext = ".rds")
  mat <- matrix("a", nrow = 5, ncol = 3)
  rownames(mat) <- corpus$works$work_id
  saveRDS(list(embeddings = mat), path)
  expect_error(sm_embed_load(corpus, path), "numeric matrix")
})

test_that("sm_embed_load assigns rownames when cache lacks them", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = TRUE, seed = 11)
  mat <- corpus$embeddings
  rownames(mat) <- NULL
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(list(embeddings = mat), path)
  out <- suppressMessages(sm_embed_load(corpus, path))
  expect_equal(rownames(out$embeddings), corpus$works$work_id)
})

test_that("sm_embed_load errors when no-rowname cache has wrong row count", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = TRUE, seed = 12)
  mat <- corpus$embeddings[1:5, ]
  rownames(mat) <- NULL
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(list(embeddings = mat), path)
  expect_error(sm_embed_load(corpus, path), "rows but corpus has")
})

test_that("sm_embed_load warns about works lacking cached embeddings", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = TRUE, seed = 13)
  # Cache only a subset of works
  mat <- corpus$embeddings[1:10, , drop = FALSE]
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(list(embeddings = mat), path)
  expect_message(sm_embed_load(corpus, path), "lack cached embeddings")
  out <- suppressMessages(sm_embed_load(corpus, path))
  expect_equal(nrow(out$embeddings), 10L)
})

test_that("sm_embed_load errors when no work IDs overlap", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = TRUE, seed = 14)
  mat <- corpus$embeddings
  rownames(mat) <- paste0("ZZZ", seq_len(nrow(mat)))
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(list(embeddings = mat), path)
  expect_error(sm_embed_load(corpus, path), "No overlap")
})

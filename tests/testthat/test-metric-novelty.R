# Tests for R/metric-novelty.R -- pure logic, no network.

test_that("sm_metric_novelty rejects a non-corpus input", {
  expect_error(sm_metric_novelty(list()), class = "rlang_error")
})

test_that("novelty returns one row per work with work_id and novelty", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = FALSE, seed = 2)
  res <- sm_metric_novelty(corpus)
  expect_s3_class(res, "tbl_df")
  expect_equal(names(res), c("work_id", "novelty"))
  expect_equal(nrow(res), nrow(corpus$works))
  expect_setequal(res$work_id, corpus$works$work_id)
  expect_type(res$novelty, "double")
  # at least some works should get a real novelty score
  expect_true(any(!is.na(res$novelty)))
})

test_that("empty corpus returns typed empty tibble", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  res <- sm_metric_novelty(empty)
  expect_equal(nrow(res), 0L)
  expect_equal(names(res), c("work_id", "novelty"))
})

test_that("corpus with no references warns and returns all-NA", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 3)
  corpus$references <- corpus$references[0, ]
  expect_warning(res <- sm_metric_novelty(corpus),
                 "No reference network")
  expect_equal(nrow(res), nrow(corpus$works))
  expect_true(all(is.na(res$novelty)))
})

test_that("references present but unlinked warns and returns NA", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 4)
  corpus$references$cited_work_id <- NA_character_
  expect_warning(res <- sm_metric_novelty(corpus),
                 "none are linked")
  expect_true(all(is.na(res$novelty)))
})

test_that("works missing source_id yields all-NA without error", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 5)
  corpus$works$source_id <- NULL
  res <- sm_metric_novelty(corpus)
  expect_equal(nrow(res), nrow(corpus$works))
  expect_true(all(is.na(res$novelty)))
})

test_that("novelty values are finite numbers where computed", {
  corpus <- sm_example_corpus(n_works = 100, n_authors = 30,
                              with_embeddings = FALSE, seed = 6)
  res <- sm_metric_novelty(corpus)
  vals <- res$novelty[!is.na(res$novelty)]
  expect_true(all(is.finite(vals)))
})

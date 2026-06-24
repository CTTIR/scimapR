# Tests for R/metric-collab.R -- pure logic, no network.

test_that("sm_metric_collab_index rejects a non-corpus input", {
  expect_error(sm_metric_collab_index(list()), class = "rlang_error")
})

test_that("collab index returns one row per work with expected columns", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 2)
  res <- sm_metric_collab_index(corpus)
  expect_s3_class(res, "tbl_df")
  expect_equal(names(res),
               c("work_id", "n_authors", "n_countries", "n_institutions",
                 "is_international", "is_multi_authored"))
  expect_equal(nrow(res), nrow(corpus$works))
  expect_setequal(res$work_id, corpus$works$work_id)
})

test_that("collab metrics are internally consistent", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 5)
  res <- sm_metric_collab_index(corpus)
  have <- res[!is.na(res$n_authors), ]
  expect_true(all(have$n_authors >= 1L))
  expect_true(all(have$n_countries >= 0L))
  expect_equal(have$is_multi_authored, have$n_authors > 1L)
  expect_equal(have$is_international, have$n_countries > 1L)
})

test_that("empty corpus returns typed empty tibble", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  res <- sm_metric_collab_index(empty)
  expect_equal(nrow(res), 0L)
  expect_equal(names(res),
               c("work_id", "n_authors", "n_countries", "n_institutions",
                 "is_international", "is_multi_authored"))
  expect_type(res$is_international, "logical")
})

test_that("corpus with works but no authorships yields NA metrics", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 6)
  corpus$authorships <- corpus$authorships[0, ]
  res <- sm_metric_collab_index(corpus)
  expect_equal(nrow(res), nrow(corpus$works))
  expect_true(all(is.na(res$n_authors)))
  expect_true(all(is.na(res$is_international)))
})

test_that("aggregate collaboration index is a positive mean", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 18,
                              with_embeddings = FALSE, seed = 7)
  res <- sm_metric_collab_index(corpus)
  ci <- mean(res$n_authors, na.rm = TRUE)
  expect_gt(ci, 0)
})

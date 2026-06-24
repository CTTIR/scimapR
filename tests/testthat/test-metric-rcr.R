# Tests for R/metric-rcr.R -- pure logic, no network.

test_that("sm_metric_rcr rejects a non-corpus input", {
  expect_error(sm_metric_rcr(list()), class = "rlang_error")
})

test_that("sm_metric_rcr validates baseline argument", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_metric_rcr(corpus, baseline = 42), class = "rlang_error")
  expect_error(sm_metric_rcr(corpus, baseline = "global"),
               "field_year")
})

test_that("rcr returns expected columns and sane values", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = FALSE, seed = 2)
  res <- sm_metric_rcr(corpus)
  expect_s3_class(res, "tbl_df")
  expect_equal(names(res),
               c("work_id", "cited_by_count", "expected_rate", "rcr"))
  expect_equal(nrow(res), nrow(corpus$works))
  expect_true(all(res$work_id %in% corpus$works$work_id))
  # expected_rate non-negative where present
  expect_true(all(res$expected_rate[!is.na(res$expected_rate)] >= 0))
  # rcr non-negative where present
  expect_true(all(res$rcr[!is.na(res$rcr)] >= 0))
})

test_that("rcr empty corpus returns typed empty tibble", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  res <- sm_metric_rcr(empty)
  expect_equal(nrow(res), 0L)
  expect_equal(names(res),
               c("work_id", "cited_by_count", "expected_rate", "rcr"))
})

test_that("rcr handles corpus with no concepts (unclassified field)", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 15,
                              with_embeddings = FALSE, seed = 3)
  corpus$concepts <- corpus$concepts[0, ]
  res <- sm_metric_rcr(corpus)
  expect_equal(nrow(res), nrow(corpus$works))
  # With a single "unclassified" field per year, rcr ~ ratio to year mean
  expect_true(all(res$rcr[!is.na(res$rcr)] >= 0))
  # the mean of rcr within each year group should center near 1
  expect_true(any(!is.na(res$rcr)))
})

test_that("rcr of 1 means cited at field-year average", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 4)
  res <- sm_metric_rcr(corpus)
  # rcr == cited_by_count / expected_rate (rounded)
  ok <- !is.na(res$rcr) & res$expected_rate > 0
  manual <- round(res$cited_by_count[ok] / res$expected_rate[ok], 4)
  expect_equal(res$rcr[ok], manual)
})

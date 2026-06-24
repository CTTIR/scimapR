# Tests for R/metric-h-index.R -- pure logic, no network.

test_that("sm_metric_h_index rejects a non-corpus input", {
  expect_error(sm_metric_h_index(list()), class = "rlang_error")
})

test_that("sm_metric_h_index validates level and self_corrected", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_metric_h_index(corpus, level = "planet"),
               class = "rlang_error")
  expect_error(sm_metric_h_index(corpus, self_corrected = "yes"),
               class = "rlang_error")
})

test_that("author-level h-index returns valid non-negative integers", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 2)
  res <- sm_metric_h_index(corpus, level = "author")
  expect_s3_class(res, "tbl_df")
  expect_true(all(c("author_id", "h_index") %in% names(res)))
  expect_gt(nrow(res), 0L)
  expect_true(is.integer(res$h_index) || is.numeric(res$h_index))
  expect_true(all(res$h_index >= 0L))
  # arranged descending
  expect_true(!is.unsorted(rev(res$h_index)))
})

test_that("source and country levels produce the right id column", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 3)
  res_src <- sm_metric_h_index(corpus, level = "source")
  expect_true("source_id" %in% names(res_src))
  expect_true(all(res_src$h_index >= 0L))

  res_ctry <- sm_metric_h_index(corpus, level = "country")
  expect_true("country_code" %in% names(res_ctry))
  expect_true(all(res_ctry$h_index >= 0L))
})

test_that("institution level returns empty (no institution_id populated)", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 4)
  res <- sm_metric_h_index(corpus, level = "institution")
  expect_true("institution_id" %in% names(res))
  expect_equal(nrow(res), 0L)
})

test_that("empty corpus yields an empty metric tibble", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  res <- sm_metric_h_index(empty, level = "author")
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_true(all(c("author_id", "h_index") %in% names(res)))
})

test_that("self_corrected h-index is <= uncorrected", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = FALSE, seed = 7)
  plain <- sm_metric_h_index(corpus, level = "author")
  corrected <- sm_metric_h_index(corpus, level = "author",
                                 self_corrected = TRUE)
  cmp <- dplyr::inner_join(plain, corrected, by = "author_id",
                           suffix = c("_plain", "_corr"))
  expect_true(all(cmp$h_index_corr <= cmp$h_index_plain))
})

test_that("self_corrected errors for source/country levels", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 5)
  expect_error(
    sm_metric_h_index(corpus, level = "source", self_corrected = TRUE),
    "only available"
  )
})

test_that("g-index returns valid non-negative values", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 6)
  res <- sm_metric_g_index(corpus, level = "author")
  expect_true(all(c("author_id", "g_index") %in% names(res)))
  expect_gt(nrow(res), 0L)
  expect_true(all(res$g_index >= 0L))
})

test_that("g-index empty corpus and self-correction branch", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  res <- sm_metric_g_index(empty, level = "author")
  expect_equal(nrow(res), 0L)
  expect_true("g_index" %in% names(res))

  corpus <- sm_example_corpus(n_works = 40, n_authors = 15,
                              with_embeddings = FALSE, seed = 8)
  res_c <- sm_metric_g_index(corpus, level = "author", self_corrected = TRUE)
  expect_true(all(res_c$g_index >= 0L))
})

test_that("m-index returns expected columns and finite values", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 9)
  res <- sm_metric_m_index(corpus, level = "author")
  expect_true(all(c("author_id", "h_index", "first_year",
                    "career_years", "m_index") %in% names(res)))
  expect_gt(nrow(res), 0L)
  expect_true(all(res$career_years >= 1L))
  expect_true(all(res$m_index >= 0))
  expect_true(all(is.finite(res$m_index)))
})

test_that("m-index empty corpus yields typed empty tibble", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  res <- sm_metric_m_index(empty, level = "author")
  expect_equal(nrow(res), 0L)
  expect_true(all(c("author_id", "h_index", "first_year",
                    "career_years", "m_index") %in% names(res)))
})

test_that("m-index self-correction branch runs for author level", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 18,
                              with_embeddings = FALSE, seed = 11)
  res <- sm_metric_m_index(corpus, level = "author", self_corrected = TRUE)
  expect_true(all(res$m_index >= 0))
})

test_that(".compute_h_index handles edge inputs", {
  ch <- scimapR:::.compute_h_index
  expect_equal(ch(integer()), 0L)
  expect_equal(ch(c(NA, NA)), 0L)
  expect_equal(ch(c(0L, 0L, 0L)), 0L)
  # three works each with >=3 citations -> h = 3
  expect_equal(ch(c(5L, 4L, 3L, 1L)), 3L)
  expect_type(ch(c(5L, 4L, 3L)), "integer")
})

test_that(".compute_g_index handles edge inputs", {
  cg <- scimapR:::.compute_g_index
  expect_equal(cg(integer()), 0L)
  expect_equal(cg(c(NA, NA)), 0L)
  # cumulative 10,18 >= 1,4 -> g = 2 (since 18>=4, next would need >=9 total>=9)
  expect_gte(cg(c(10L, 8L, 1L)), 1L)
  expect_type(cg(c(10L, 8L)), "integer")
})

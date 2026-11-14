test_that("unknown publication years do not imply a one-year career", {
  corpus <- sm_example_corpus(n_works = 12, n_authors = 4,
                              with_embeddings = FALSE, seed = 42)
  corpus$works$year <- NA_integer_
  expect_no_warning(out <- sm_metric_m_index(corpus))
  expected_h <- sm_metric_h_index(corpus)
  expect_equal(out$h_index, expected_h$h_index[match(out$author_id,
                                                   expected_h$author_id)])
  expect_true(all(is.na(out$first_year)))
  expect_true(all(is.na(out$career_years)))
  expect_true(all(is.na(out$m_index)))
  expect_no_warning(corrected <- sm_metric_m_index(corpus, self_corrected = TRUE))
  expect_true(all(is.na(corrected$m_index)))

  # A known year still determines the result; unrelated missing years do not.
  corpus$works$year <- rep(c(2000L, NA_integer_), 6L)
  out <- sm_metric_m_index(corpus)
  current_year <- as.integer(format(Sys.Date(), "%Y"))
  for (i in seq_len(nrow(out))) {
    works <- corpus$authorships$work_id[
      corpus$authorships$author_id == out$author_id[i]]
    has_year <- any(corpus$works$work_id %in% works &
                     !is.na(corpus$works$year))
    if (has_year) {
      expect_equal(out$first_year[i], 2000L)
      expect_equal(out$career_years[i], max(current_year - 2000L, 1L))
      expect_equal(out$m_index[i], out$h_index[i] / out$career_years[i])
    } else {
      expect_true(is.na(out$m_index[i]))
    }
  }
})

test_that("g-index citation accumulation does not overflow integer totals", {
  expect_no_warning(value <- .compute_g_index(c(1500000000L, 1500000000L)))
  expect_identical(value, 2L)
  expect_identical(.compute_g_index(c(8L, 1L, 0L, NA_integer_)), 3L)
  expect_identical(.compute_g_index(c(5L, 1L, 0L)), 2L)
})

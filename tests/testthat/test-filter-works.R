test_that("sm_filter_works filters by year_range", {
  corpus <- sm_example_corpus(n_works = 100, n_authors = 20,
                              year_range = c(2015L, 2024L),
                              with_embeddings = FALSE, seed = 1)

  filtered <- sm_filter_works(corpus, year_range = c(2020, 2022))

  expect_s3_class(filtered, "sm_corpus")
  expect_true(all(filtered$works$year >= 2020L & filtered$works$year <= 2022L))
  expect_lte(nrow(filtered$works), nrow(corpus$works))
})

test_that("sm_filter_works filters by type", {
  corpus <- sm_example_corpus(n_works = 100, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)

  filtered <- sm_filter_works(corpus, types = "journal-article")

  expect_s3_class(filtered, "sm_corpus")
  expect_true(all(filtered$works$type == "journal-article"))
})

test_that("sm_filter_works filters by oa_only", {
  corpus <- sm_example_corpus(n_works = 100, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)

  filtered <- sm_filter_works(corpus, oa_only = TRUE)

  expect_s3_class(filtered, "sm_corpus")
  oa_statuses <- c("gold", "green", "hybrid", "bronze")
  expect_true(all(filtered$works$oa_status %in% oa_statuses))
})

test_that("sm_filter_works combines multiple filters", {
  corpus <- sm_example_corpus(n_works = 200, n_authors = 50,
                              with_embeddings = FALSE, seed = 1)

  filtered <- sm_filter_works(corpus,
                              year_range = c(2020, 2024),
                              types = "journal-article",
                              oa_only = TRUE)

  expect_s3_class(filtered, "sm_corpus")
  expect_true(all(filtered$works$year >= 2020L))
  expect_true(all(filtered$works$type == "journal-article"))
  expect_true(all(filtered$works$oa_status %in%
                    c("gold", "green", "hybrid", "bronze")))
})

test_that("sm_filter_works supports custom dplyr expressions", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 10,
                              with_embeddings = FALSE, seed = 1)

  filtered <- sm_filter_works(corpus, cited_by_count > 10)

  expect_s3_class(filtered, "sm_corpus")
  expect_true(all(filtered$works$cited_by_count > 10L))
})

test_that("sm_filter_works keeps authorships consistent", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)

  filtered <- sm_filter_works(corpus, year_range = c(2020, 2022))

  # All authorship work_ids should be in filtered works
  expect_true(all(filtered$authorships$work_id %in% filtered$works$work_id))
})

test_that("sm_filter_works rejects non-corpus input", {
  expect_error(sm_filter_works("not_a_corpus"), "sm_corpus")
})

test_that("sm_filter_works returns empty corpus when no matches", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 10,
                              year_range = c(2015L, 2020L),
                              with_embeddings = FALSE, seed = 1)

  filtered <- sm_filter_works(corpus, year_range = c(2030, 2040))
  expect_equal(nrow(filtered$works), 0L)
})

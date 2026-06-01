# Tests for Parts D & E: citation maturity, counting, robust summaries.

# ---- D1: sm_citation_maturity -----------------------------------------------

test_that("sm_citation_maturity flags recent years based on as-of date", {
  corpus <- sm_example_corpus(n_works = 40, year_range = c(2015L, 2024L),
                              seed = 1)
  # force the as-of date to the max publication year
  corpus$metadata$last_refresh <- NA
  corpus <- sm_citation_maturity(corpus, lag = 2)
  expect_true(all(c("citation_mature", "cnci_provisional") %in%
                    names(corpus$works)))
  # max year 2024, lag 2 -> cutoff 2022 -> 2023/2024 provisional
  prov_years <- unique(corpus$works$year[corpus$works$cnci_provisional])
  expect_setequal(prov_years, c(2023L, 2024L))
  expect_identical(corpus$works$cnci_provisional,
                   !corpus$works$citation_mature)
})

test_that("sm_citation_maturity uses metadata last_refresh when present", {
  corpus <- sm_example_corpus(n_works = 20, year_range = c(2015L, 2024L),
                              seed = 1)
  corpus$metadata$last_refresh <- as.Date("2030-01-01")
  corpus <- sm_citation_maturity(corpus, lag = 2)
  # as-of 2030, cutoff 2028 -> every year mature
  expect_true(all(corpus$works$citation_mature))
})

test_that("sm_citation_maturity is type-stable on empty corpus", {
  corpus <- sm_corpus(works = .empty_works())
  out <- sm_citation_maturity(corpus)
  expect_true(is_sm_corpus(out))
  expect_equal(nrow(out$works), 0L)
  expect_true(all(c("citation_mature", "cnci_provisional") %in%
                    names(out$works)))
})

# ---- D2: sm_count -----------------------------------------------------------

test_that("sm_count fractional credit sums to the number of works", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  fr <- sm_count(corpus, method = "fractional", level = "author")
  n_works_with_authors <- dplyr::n_distinct(corpus$authorships$work_id)
  expect_equal(round(sum(fr$credit)), n_works_with_authors)
})

test_that("sm_count full credit equals n_works per entity", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  full <- sm_count(corpus, method = "full", level = "author")
  expect_equal(full$credit, as.double(full$n_works))
  expect_named(full, c("entity_id", "entity_name", "n_works", "credit",
                       "weighted_citations"))
})

test_that("sm_count source counting is identical for full and fractional", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  f <- sm_count(corpus, "full", "source")
  fr <- sm_count(corpus, "fractional", "source")
  expect_equal(sort(f$credit), sort(fr$credit))
})

test_that("sm_count is type-stable when level data is absent", {
  corpus <- sm_corpus(works = tibble::tibble(work_id = "W1", title = "x",
                                             year = 2020L))
  out <- sm_count(corpus, level = "author")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("entity_id", "entity_name", "n_works", "credit",
                      "weighted_citations"))
})

# ---- E1: sm_metric_summary --------------------------------------------------

test_that("sm_metric_summary robust reports median CI and pp_top10", {
  corpus <- sm_example_corpus(n_works = 100, seed = 1)
  s <- sm_metric_summary(corpus, metric = "citations", seed = 1, n_boot = 300)
  expect_named(s, c("metric", "n", "mean", "median", "median_ci_low",
                    "median_ci_high", "pp_top10", "n_boot"))
  expect_equal(s$n, 100L)
  expect_true(s$median_ci_low <= s$median)
  expect_true(s$median <= s$median_ci_high)
  expect_true(s$pp_top10 >= 0 && s$pp_top10 <= 1)
})

test_that("sm_metric_summary is reproducible with a seed", {
  corpus <- sm_example_corpus(n_works = 80, seed = 1)
  s1 <- sm_metric_summary(corpus, "citations", seed = 42, n_boot = 300)
  s2 <- sm_metric_summary(corpus, "citations", seed = 42, n_boot = 300)
  expect_equal(s1$median_ci_low, s2$median_ci_low)
  expect_equal(s1$median_ci_high, s2$median_ci_high)
})

test_that("sm_metric_summary seed does not disturb the global RNG", {
  corpus <- sm_example_corpus(n_works = 40, seed = 1)
  set.seed(123)
  before <- .Random.seed
  invisible(sm_metric_summary(corpus, "citations", seed = 7, n_boot = 100))
  expect_identical(.Random.seed, before)
})

test_that("sm_metric_summary non-robust omits CI columns", {
  corpus <- sm_example_corpus(n_works = 40, seed = 1)
  s <- sm_metric_summary(corpus, "citations", robust = FALSE)
  expect_named(s, c("metric", "n", "mean", "median"))
})

test_that("sm_metric_summary is type-stable on empty corpus", {
  corpus <- sm_corpus(works = .empty_works())
  s <- sm_metric_summary(corpus, "citations")
  expect_equal(s$n, 0L)
  expect_true(is.na(s$median))
})

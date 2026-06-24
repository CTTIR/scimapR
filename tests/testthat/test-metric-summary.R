# Tests for R/metric-summary.R and R/metric-summary-robust.R

# --- sm_summary_works ---------------------------------------------------

test_that("sm_summary_works rejects a non-corpus", {
  expect_error(sm_summary_works(list()), class = "rlang_error")
})

test_that("sm_summary_works returns a typed empty row for empty works", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  out <- sm_summary_works(empty)
  expect_equal(nrow(out), 1L)
  expect_equal(out$n_works, 0L)
  expect_true(is.na(out$year_min))
  expect_equal(out$total_citations, 0L)
})

test_that("sm_summary_works computes correct aggregates", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 15,
                              year_range = c(2015L, 2020L), seed = 4)
  out <- sm_summary_works(corpus)
  expect_equal(out$n_works, 50L)
  expect_equal(out$year_min, min(corpus$works$year))
  expect_equal(out$year_max, max(corpus$works$year))
  expect_equal(out$year_span, out$year_max - out$year_min + 1L)
  expect_equal(out$total_citations, sum(corpus$works$cited_by_count, na.rm = TRUE))
  expect_equal(out$mean_citations,
               round(mean(corpus$works$cited_by_count, na.rm = TRUE), 2))
  expect_true(out$pct_oa >= 0 && out$pct_oa <= 100)
  expect_true(out$n_languages >= 1L)
})

# --- sm_summary_authors -------------------------------------------------

test_that("sm_summary_authors returns a typed empty row for no authors", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  out <- sm_summary_authors(empty)
  expect_equal(out$n_authors, 0L)
  expect_true(is.na(out$pct_orcid))
})

test_that("sm_summary_authors computes ORCID and collaboration metrics", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 20, seed = 3)
  out <- sm_summary_authors(corpus)
  expect_equal(out$n_authors, 20L)
  n_orcid <- sum(!is.na(corpus$authors$orcid) & nzchar(corpus$authors$orcid))
  expect_equal(out$n_with_orcid, n_orcid)
  expect_equal(out$pct_orcid, round(n_orcid / 20 * 100, 1))
  expect_true(out$max_works_per_author >= 1L)
  expect_true(out$mean_authors_per_work >= 1)
  expect_true(out$single_author_pct >= 0 && out$single_author_pct <= 100)
})

# --- sm_summary_sources -------------------------------------------------

test_that("sm_summary_sources returns a typed empty row for no sources", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  out <- sm_summary_sources(empty)
  expect_equal(out$n_sources, 0L)
  expect_true(is.na(out$top_source))
})

test_that("sm_summary_sources identifies the top source", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 15, seed = 7)
  out <- sm_summary_sources(corpus)
  expect_true(out$n_sources >= 1L)
  expect_true(out$top_source_n >= 1L)
  expect_false(is.na(out$top_source))
  # top_source_n should equal the max per-source work count
  src_counts <- sort(table(corpus$works$source_id), decreasing = TRUE)
  expect_equal(out$top_source_n, as.integer(src_counts[1]))
})

# --- sm_summary_period --------------------------------------------------

test_that("sm_summary_period returns empty for a corpus with no years", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  out <- sm_summary_period(empty)
  expect_equal(nrow(out), 0L)
  expect_named(out, c("year", "n_works", "mean_citations", "median_citations",
                      "total_citations", "n_oa", "pct_oa", "n_authors",
                      "mean_authors_per_work"))
})

test_that("sm_summary_period produces one row per year", {
  corpus <- sm_example_corpus(n_works = 80, n_authors = 20,
                              year_range = c(2016L, 2020L), seed = 5)
  out <- sm_summary_period(corpus)
  yrs <- sort(unique(corpus$works$year))
  expect_equal(out$year, yrs)
  expect_equal(sum(out$n_works), nrow(corpus$works))
  expect_true(all(out$n_authors >= 1L))
  expect_true(all(out$mean_authors_per_work >= 1))
  # years are sorted ascending
  expect_equal(out$year, sort(out$year))
})

test_that("sm_summary_period falls back when there are no authorships", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 2)
  corpus$authorships <- scimapR:::.empty_authorships()
  out <- sm_summary_period(corpus)
  expect_true(all(is.na(out$n_authors)))
  expect_true(all(is.na(out$mean_authors_per_work)))
})

# --- sm_metric_summary --------------------------------------------------

test_that("sm_metric_summary rejects a non-corpus", {
  expect_error(sm_metric_summary(list()), class = "rlang_error")
})

test_that("sm_metric_summary rejects an unknown metric", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_metric_summary(corpus, metric = "nonsense"),
    class = "rlang_error"
  )
})

test_that("sm_metric_summary rejects a non-flag robust argument", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_metric_summary(corpus, robust = "yes"),
    class = "rlang_error"
  )
})

test_that("sm_metric_summary returns a typed empty row for empty works", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  out <- sm_metric_summary(empty, metric = "citations")
  expect_equal(out$n, 0L)
  expect_true(is.na(out$mean))
  expect_true("median_ci_low" %in% names(out))
})

test_that("sm_metric_summary non-robust returns only basic columns", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 12,
                              with_embeddings = FALSE, seed = 3)
  out <- sm_metric_summary(corpus, metric = "citations", robust = FALSE)
  expect_named(out, c("metric", "n", "mean", "median"))
  expect_equal(out$n, 40L)
  expect_equal(out$mean,
               round(mean(corpus$works$cited_by_count, na.rm = TRUE), 4))
})

test_that("sm_metric_summary robust reports a bootstrap CI and pp_top10", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 15,
                              with_embeddings = FALSE, seed = 1)
  out <- sm_metric_summary(corpus, metric = "citations",
                           n_boot = 200L, seed = 1)
  expect_named(out, c("metric", "n", "mean", "median",
                      "median_ci_low", "median_ci_high",
                      "pp_top10", "n_boot"))
  expect_equal(out$n_boot, 200L)
  expect_true(out$median_ci_low <= out$median)
  expect_true(out$median_ci_high >= out$median)
  expect_true(out$pp_top10 >= 0 && out$pp_top10 <= 1)
})

test_that("sm_metric_summary bootstrap is reproducible with a seed", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 12,
                              with_embeddings = FALSE, seed = 2)
  o1 <- sm_metric_summary(corpus, metric = "citations",
                          n_boot = 300L, seed = 99)
  o2 <- sm_metric_summary(corpus, metric = "citations",
                          n_boot = 300L, seed = 99)
  expect_identical(o1$median_ci_low, o2$median_ci_low)
  expect_identical(o1$median_ci_high, o2$median_ci_high)
})

test_that("sm_metric_summary bootstrap seed does not leak into global RNG", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 4)
  set.seed(12345)
  before <- .Random.seed
  invisible(sm_metric_summary(corpus, metric = "citations",
                              n_boot = 100L, seed = 7))
  after <- .Random.seed
  expect_identical(before, after)
})

# --- internal bootstrap helper -----------------------------------------

test_that(".bootstrap_median_ci returns NA for fewer than two values", {
  f <- scimapR:::.bootstrap_median_ci
  expect_equal(f(numeric(0)), c(NA_real_, NA_real_))
  expect_equal(f(5), c(NA_real_, NA_real_))
})

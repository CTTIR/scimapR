test_that("sm_audit_oa rejects non-corpus input", {
  expect_error(sm_audit_oa(list(a = 1)), "sm_corpus")
})

test_that("sm_audit_oa returns empty result for empty corpus", {
  corpus <- make_empty_corpus()
  res <- sm_audit_oa(corpus)
  expect_s3_class(res, "sm_audit_oa")
  expect_equal(res$n_works, 0L)
  expect_equal(res$pct_open, 0.0)
  expect_equal(res$coverage, 0.0)
  expect_equal(nrow(res$distribution), 0L)
})

test_that("sm_audit_oa computes distribution and pct_open", {
  corpus <- sm_example_corpus(n_works = 50, with_embeddings = FALSE, seed = 1)
  res <- sm_audit_oa(corpus)
  expect_s3_class(res, "sm_audit_oa")
  expect_equal(res$n_works, 50L)
  expect_true(all(c("oa_status", "count", "pct") %in% names(res$distribution)))
  expect_equal(sum(res$distribution$count), 50L)
  expect_equal(sum(res$distribution$pct), 100, tolerance = 1)
  # Distribution sorted descending by count
  expect_true(all(diff(res$distribution$count) <= 0))
  # pct_open should equal share of gold/green/hybrid/bronze
  open_statuses <- c("gold", "green", "hybrid", "bronze")
  n_open <- sum(corpus$works$oa_status %in% open_statuses)
  expect_equal(res$pct_open, round(100 * n_open / 50, 1))
})

test_that("sm_audit_oa maps NA oa_status to 'unknown'", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = FALSE, seed = 2)
  corpus$works$oa_status[1:5] <- NA_character_
  res <- sm_audit_oa(corpus)
  expect_true("unknown" %in% res$distribution$oa_status)
  expect_equal(res$distribution$count[res$distribution$oa_status == "unknown"], 5L)
  # Coverage = proportion with non-NA status
  expect_equal(res$coverage, round(15 / 20, 3))
})

test_that("sm_audit_oa full coverage when all statuses known", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = FALSE, seed = 3)
  corpus$works$oa_status <- "gold"
  res <- sm_audit_oa(corpus)
  expect_equal(res$coverage, 1.0)
  expect_equal(res$pct_open, 100.0)
  expect_equal(nrow(res$distribution), 1L)
})

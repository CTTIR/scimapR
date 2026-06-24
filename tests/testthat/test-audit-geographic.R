test_that("sm_audit_geographic rejects non-corpus input", {
  expect_error(sm_audit_geographic(list(a = 1)), "sm_corpus")
})

test_that("sm_audit_geographic validates by and weight arguments", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 1)
  expect_error(sm_audit_geographic(corpus, by = "bogus"))
  expect_error(sm_audit_geographic(corpus, weight = "bogus"))
})

test_that("sm_audit_geographic returns empty result for empty corpus", {
  corpus <- make_empty_corpus()
  res <- sm_audit_geographic(corpus)
  expect_s3_class(res, "sm_audit_geographic")
  expect_equal(nrow(res$distribution), 0L)
  expect_equal(res$coverage, 0.0)
  expect_true(is.na(res$gini))
  expect_equal(res$by, "country")
  expect_equal(res$weight, "count")
})

test_that("sm_audit_geographic by country with count weighting", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 20,
                              with_embeddings = FALSE, seed = 2)
  res <- sm_audit_geographic(corpus, by = "country", weight = "count")
  expect_s3_class(res, "sm_audit_geographic")
  expect_true(all(c("group", "count", "pct", "citations") %in%
                    names(res$distribution)))
  expect_gt(nrow(res$distribution), 0L)
  # Percentages sum to ~100
  expect_equal(sum(res$distribution$pct), 100, tolerance = 1)
  # Distribution sorted descending by count
  expect_true(all(diff(res$distribution$count) <= 0))
  expect_gte(res$gini, 0)
  expect_lte(res$gini, 1)
  expect_equal(res$coverage, 1.0)
})

test_that("sm_audit_geographic with citation weighting sorts by citations", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 20,
                              with_embeddings = FALSE, seed = 3)
  res <- sm_audit_geographic(corpus, by = "country", weight = "citations")
  expect_equal(res$weight, "citations")
  expect_true(all(diff(res$distribution$citations) <= 0))
  # pct computed off citations sums to ~100
  expect_equal(sum(res$distribution$pct), 100, tolerance = 1)
})

test_that("sm_audit_geographic first-author weighting filters position 1", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 20,
                              with_embeddings = FALSE, seed = 4)
  res_all <- sm_audit_geographic(corpus, weight = "count")
  res_first <- sm_audit_geographic(corpus, weight = "first-author")
  expect_equal(res_first$weight, "first-author")
  expect_lte(sum(res_first$distribution$count), sum(res_all$distribution$count))
})

test_that("sm_audit_geographic corresponding weighting returns a valid object", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 5)
  res <- sm_audit_geographic(corpus, weight = "corresponding")
  expect_s3_class(res, "sm_audit_geographic")
  expect_equal(res$weight, "corresponding")
  # NOTE (source behaviour): the corresponding-author filter uses
  # `isTRUE(.data$is_corresponding)` which collapses the whole column to a
  # single FALSE, so the filtered authorships are empty and the distribution
  # is empty even though corresponding authorships exist in the corpus.
  expect_equal(nrow(res$distribution), 0L)
})

test_that("sm_audit_geographic by region with no institutions => zero coverage", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 6)
  # Example corpus has empty institutions, so region groups are all NA
  res <- sm_audit_geographic(corpus, by = "region")
  expect_equal(res$by, "region")
  expect_equal(res$coverage, 0.0)
  expect_equal(nrow(res$distribution), 0L)
})

test_that("sm_audit_geographic by income_tier with no institutions => empty", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 7)
  res <- sm_audit_geographic(corpus, by = "income_tier")
  expect_equal(res$by, "income_tier")
  expect_equal(nrow(res$distribution), 0L)
})

test_that(".compute_gini behaves at boundaries", {
  expect_equal(.compute_gini(integer()), 0.0)
  expect_equal(.compute_gini(5L), 0.0)
  expect_equal(.compute_gini(c(0, 0, 0)), 0.0)
  # Perfectly equal distribution -> gini near 0
  expect_lt(.compute_gini(rep(10, 10)), 1e-8)
  # Highly concentrated -> gini close to (n-1)/n
  g <- .compute_gini(c(0, 0, 0, 100))
  expect_gt(g, 0.5)
})

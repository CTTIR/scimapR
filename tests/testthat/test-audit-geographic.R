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
  # The filter keeps the rows flagged TRUE. It used isTRUE() on the whole
  # column before, which selected no row: the distribution was empty and
  # the coverage 0 although the corpus has corresponding authors.
  expect_gt(nrow(res$distribution), 0L)
  expect_gt(res$coverage, 0)
  a <- corpus$authorships
  eligible <- a[a$is_corresponding %in% TRUE & !is.na(a$country_code), ]
  expect_identical(sum(res$distribution$count),
                   nrow(unique(eligible[c("work_id", "country_code")])))
})

test_that("sm_audit_geographic leaves unknown corresponding authors out", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 5)
  corpus$authorships$is_corresponding[1:10] <- NA
  res <- sm_audit_geographic(corpus, weight = "corresponding")
  a <- corpus$authorships
  eligible <- a[a$is_corresponding %in% TRUE & !is.na(a$country_code), ]
  expect_identical(sum(res$distribution$count),
                   nrow(unique(eligible[c("work_id", "country_code")])))
  corpus$authorships$is_corresponding <- NA
  res <- sm_audit_geographic(corpus, weight = "corresponding")
  expect_identical(nrow(res$distribution), 0L)
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

test_that("geographic audits count distinct works in each group", {
  corpus <- sm_corpus(
    works = tibble::tibble(
      work_id = c("W1", "W2"), cited_by_count = c(10L, 10L)
    ),
    authorships = tibble::tibble(
      work_id = c(rep("W1", 9), "W2"), author_id = paste0("A", 1:10),
      country_code = c(rep("DE", 9), "US")
    )
  )
  for (weight in c("count", "citations")) {
    result <- sm_audit_geographic(corpus, weight = weight)
    expect_identical(result$distribution$count, c(1L, 1L))
    expect_equal(result$distribution$citations, c(10L, 10L))
    expect_equal(result$distribution$pct, c(50, 50))
    expect_equal(result$gini, 0)
  }
  corpus$authorships$author_id <- "A1"
  expect_identical(sm_audit_geographic(corpus)$distribution$count, c(1L, 1L))
})

test_that("fractional geography splits work and citation credit", {
  corpus <- sm_corpus(
    works = tibble::tibble(work_id = "W1", cited_by_count = 10L),
    authorships = tibble::tibble(
      work_id = "W1", author_id = "A1", country_code = c("DE", "DE", "US")
    )
  )
  full <- sm_audit_geographic(corpus)
  fractional <- sm_audit_geographic(corpus, method = "fractional")
  expect_identical(full$distribution$count, c(1L, 1L))
  expect_equal(full$distribution$credit, c(1, 1))
  expect_equal(fractional$distribution$credit, c(0.5, 0.5))
  expect_equal(fractional$distribution$weighted_citations, c(5, 5))
  expect_equal(sum(fractional$distribution$credit), 1)
  expect_equal(fractional$method, "fractional")
  expect_error(sm_audit_geographic(corpus, method = "invalid"))
  empty <- sm_audit_geographic(make_empty_corpus(), method = "fractional")
  expect_named(empty$distribution, c(
    "group", "count", "citations", "pct", "credit", "weighted_citations"
  ))
  expect_type(empty$distribution$credit, "double")
  expect_type(empty$distribution$weighted_citations, "double")
  expect_equal(empty$method, "fractional")
})

test_that("geographic coverage counts works and Gini uses the weight", {
  corpus <- sm_corpus(
    works = tibble::tibble(
      work_id = paste0("W", 1:3), cited_by_count = c(10L, 30L, 0L)
    ),
    authorships = tibble::tibble(
      work_id = c("W1", "W1", "W1", "W2", "W3"),
      author_id = paste0("A", 1:5),
      country_code = c("DE", "DE", "DE", "US", NA),
      position = c(1L, 2L, 3L, 1L, 1L)
    )
  )
  expect_equal(sm_audit_geographic(corpus)$coverage, round(2 / 3, 3))
  expect_equal(sm_audit_geographic(corpus)$gini, 0)
  expect_equal(sm_audit_geographic(corpus, weight = "citations")$gini,
               round(.compute_gini(c(10, 30)), 3))
  corpus$authorships$country_code[1] <- NA_character_
  expect_equal(sm_audit_geographic(corpus, weight = "first-author")$coverage,
               round(1 / 3, 3))
})

test_that("weighted citations use per-work credit before aggregation", {
  corpus <- sm_corpus(
    works = tibble::tibble(
      work_id = paste0("W", 1:3), cited_by_count = c(10L, 10L, 30L)
    ),
    authorships = tibble::tibble(
      work_id = paste0("W", 1:3), author_id = paste0("A", 1:3),
      country_code = c("DE", "DE", "US")
    )
  )
  result <- sm_audit_geographic(corpus, weight = "citations")$distribution
  expect_identical(result$group, c("US", "DE"))
  expect_equal(result$weighted_citations, result$citations)
  expect_equal(result$pct, c(60, 40))
})

test_that("regional groups and unknown geography retain work-based credit", {
  corpus <- sm_corpus(
    works = tibble::tibble(
      work_id = c("W1", "W2"), cited_by_count = c(12L, 0L)
    ),
    authorships = tibble::tibble(
      work_id = c("W1", "W1", "W1", "W2"), author_id = "A1",
      institution_id = c("I1", "I2", "I3", NA),
      country_code = c("DE", "US", "US", " ")
    ),
    institutions = tibble::tibble(
      institution_id = paste0("I", 1:3), region = c("North", "North", "South"),
      income_tier = c("High", "High", "Low")
    )
  )
  for (by in c("country", "region", "income_tier")) {
    result <- sm_audit_geographic(corpus, by = by, method = "fractional")
    expect_equal(result$coverage, 0.5)
    expect_equal(result$distribution$credit, c(0.5, 0.5))
    expect_equal(result$distribution$weighted_citations, c(6, 6))
    expect_type(result$distribution$citations, "integer")
  }
  corpus$works$cited_by_count <- 0L
  result <- sm_audit_geographic(corpus, weight = "citations")
  expect_equal(result$distribution$pct, c(0, 0))
  expect_equal(result$gini, 0)
})

test_that("rounded percentage ties sort by group deterministically", {
  corpus <- sm_corpus(
    works = tibble::tibble(
      work_id = c("W1", "W2"), cited_by_count = c(1000000L, 1000001L)
    ),
    authorships = tibble::tibble(
      work_id = c("W1", "W2"), author_id = c("A1", "A2"),
      country_code = c("DE", "US")
    )
  )
  result <- sm_audit_geographic(corpus, weight = "citations")$distribution
  expect_equal(result$pct, c(50, 50))
  expect_identical(result$group, c("DE", "US"))
})

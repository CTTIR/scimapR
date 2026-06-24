test_that("sm_audit_gender rejects non-corpus input", {
  expect_error(sm_audit_gender(list(a = 1)), "sm_corpus")
})

test_that("sm_audit_gender validates the method argument", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 1)
  expect_error(sm_audit_gender(corpus, method = "bogus"))
})

test_that("sm_audit_gender returns empty result for corpus with no authors", {
  corpus <- make_empty_corpus()
  res <- sm_audit_gender(corpus, method = "manual")
  expect_s3_class(res, "sm_audit_gender")
  expect_equal(nrow(res$distribution), 0L)
  expect_equal(res$coverage, 0.0)
  expect_equal(res$method, "manual")
  expect_true(is.na(res$confidence_summary$mean))
})

test_that("sm_audit_gender manual method uses existing columns", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 12,
                              with_embeddings = FALSE, seed = 2)
  # Inject manual gender labels
  n <- nrow(corpus$authors)
  corpus$authors$inferred_gender <- rep(c("female", "male", "unknown"),
                                        length.out = n)
  corpus$authors$gender_confidence <- rep(c(0.9, 0.8, NA), length.out = n)
  res <- sm_audit_gender(corpus, method = "manual")
  expect_s3_class(res, "sm_audit_gender")
  expect_equal(res$method, "manual")
  expect_true(all(c("inferred_gender", "count", "pct") %in%
                    names(res$distribution)))
  expect_equal(sum(res$distribution$count), n)
  # Coverage excludes "unknown" and NA
  expect_gt(res$coverage, 0)
  # Confidence summary computed from non-NA values
  expect_false(is.na(res$confidence_summary$mean))
  expect_equal(res$confidence_summary$max, 0.9)
})

test_that("sm_audit_gender by_position breakdown has expected columns", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 12,
                              with_embeddings = FALSE, seed = 3)
  corpus$authors$inferred_gender <- rep(c("female", "male"),
                                        length.out = nrow(corpus$authors))
  res <- sm_audit_gender(corpus, method = "manual")
  expect_true(all(c("position_type", "inferred_gender", "count", "pct") %in%
                    names(res$by_position)))
  expect_gt(nrow(res$by_position), 0L)
  expect_true(all(c("first") %in% res$by_position$position_type))
})

test_that("sm_audit_gender ssa method emits a limitation message and NA genders", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 10,
                              with_embeddings = FALSE, seed = 4)
  expect_message(sm_audit_gender(corpus, method = "ssa"), "US-centric")
  res <- suppressMessages(sm_audit_gender(corpus, method = "ssa"))
  expect_s3_class(res, "sm_audit_gender")
  expect_equal(res$method, "ssa")
  # SSA stub returns all NA gender -> zero coverage
  expect_equal(res$coverage, 0.0)
})

test_that("sm_audit_gender genderize uses cache and never hits network", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 8,
                              with_embeddings = FALSE, seed = 5)
  cache_dir <- withr::local_tempdir()
  # Pre-populate cache so no network query is attempted.
  first_names <- vapply(
    strsplit(corpus$authors$display_name, "\\s+"),
    function(p) tolower(p[1]), character(1)
  )
  cache <- list()
  for (nm in unique(first_names)) {
    cache[[nm]] <- list(gender = "female", confidence = 0.77)
  }
  saveRDS(cache, file.path(cache_dir, "genderize_cache.rds"))

  res <- sm_audit_gender(corpus, method = "genderize",
                         api_key = "", cache_dir = cache_dir)
  expect_s3_class(res, "sm_audit_gender")
  expect_equal(res$method, "genderize")
  expect_equal(res$coverage, 1.0)
  expect_equal(res$confidence_summary$mean, 0.77)
})

test_that("sm_audit_gender genderize errors are swallowed when cache miss", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 6)
  cache_dir <- withr::local_tempdir()
  # Stub the HTTP performer to error so genderize falls back to NA.
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("no network"),
    .package = "httr2"
  )
  res <- suppressMessages(
    sm_audit_gender(corpus, method = "genderize",
                    api_key = "", cache_dir = cache_dir)
  )
  expect_s3_class(res, "sm_audit_gender")
  expect_equal(res$coverage, 0.0)
})

test_that("sm_audit_gender rejects non-corpus input", {
  expect_error(sm_audit_gender(list(a = 1)), "sm_corpus")
})

test_that("filtered gender audits count and look up only retained authors", {
  x <- sm_example_corpus(n_works = 200, n_authors = 80,
                         with_embeddings = FALSE, seed = 1)
  x$authors$inferred_gender <- rep(c("female", "unknown"), 40L)
  sub <- sm_filter_works(x, year_range = c(2023, 2024))
  ids <- unique(sub$authorships$author_id)
  expect_lt(length(ids), nrow(x$authors))
  expected <- x$authors[x$authors$author_id %in% ids, ]
  audit <- sm_audit_gender(sub, method = "manual")
  expect_equal(sum(audit$distribution$count), length(ids))
  expect_equal(audit$coverage,
               round(mean(expected$inferred_gender == "female"), 3))
  seen <- NULL
  local_mocked_bindings(.infer_gender_genderize = function(first_names, ...) {
    seen <<- first_names
    list(gender = rep(NA_character_, length(first_names)),
         confidence = rep(NA_real_, length(first_names)))
  })
  sm_audit_gender(sub, method = "genderize")
  expect_identical(seen, vapply(strsplit(expected$display_name, "\\s+"),
                                function(x) x[1], character(1)))
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

test_that("sm_audit_gender counts corresponding authors who are not first", {
  # In the real-use fixture 60 of 150 works have their corresponding author
  # at position 2 or later. The breakdown used isTRUE() on the whole
  # column, which never gave "corresponding".
  fix <- realuse_corpus()
  fix$authors$inferred_gender <- rep(c("female", "male"),
                                     length.out = nrow(fix$authors))
  res <- sm_audit_gender(fix, method = "manual")
  bp <- res$by_position
  a <- unique(fix$authorships[, c("work_id", "author_id", "position",
                                  "is_corresponding")])
  expected <- sum(a$is_corresponding & a$position > 1L)
  expect_gt(expected, 0L)
  expect_identical(sum(bp$count[bp$position_type == "corresponding"]),
                   expected)
})

test_that("sm_audit_gender counts an author with two addresses once", {
  corpus <- sm_corpus(
    works = tibble::tibble(work_id = c("W1", "W2"), year = 2020L),
    authors = tibble::tibble(author_id = c("A1", "A2"), orcid = NA_character_,
                             display_name = c("Ann Roe", "Bo Doe"),
                             inferred_gender = c("female", "male"),
                             gender_confidence = NA_real_),
    authorships = tibble::tibble(
      work_id = c("W1", "W1", "W1", "W2"),
      author_id = c("A1", "A1", "A2", "A2"),
      position = c(1L, 1L, 2L, 1L),
      is_corresponding = c(FALSE, FALSE, TRUE, NA),
      institution_id = NA_character_,
      raw_affiliation = c("Univ A", "Inst B", "Univ C", NA),
      country_code = NA_character_
    )
  )
  bp <- sm_audit_gender(corpus, method = "manual")$by_position
  got <- stats::setNames(bp$count, paste(bp$position_type,
                                         bp$inferred_gender))
  expect_identical(got[order(names(got))],
                   c("corresponding male" = 1L, "first female" = 1L,
                     "first male" = 1L))
})

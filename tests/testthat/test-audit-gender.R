test_that("sm_audit_gender rejects non-corpus input", {
  local_http_env()
  expect_error(sm_audit_gender(list(a = 1)), "sm_corpus")
})

test_that("filtered gender audits count and look up only retained authors", {
  local_http_env()
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
  local_http_env()
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 1)
  expect_error(sm_audit_gender(corpus, method = "bogus"))
})

test_that("sm_audit_gender returns empty result for corpus with no authors", {
  local_http_env()
  corpus <- make_empty_corpus()
  res <- sm_audit_gender(corpus, method = "manual")
  expect_s3_class(res, "sm_audit_gender")
  expect_equal(nrow(res$distribution), 0L)
  expect_equal(res$coverage, 0.0)
  expect_equal(res$method, "manual")
  expect_true(is.na(res$confidence_summary$mean))
})

test_that("sm_audit_gender manual method uses existing columns", {
  local_http_env()
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
  local_http_env()
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
  local_http_env()
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
  local_http_env()
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

test_that("sm_audit_gender genderize errors warn and are not cached", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 6)
  cache_dir <- withr::local_tempdir()
  # Stub the HTTP performer to error so genderize falls back to NA.
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("no network"),
    .package = "httr2"
  )
  expect_warning(res <- suppressMessages(
    sm_audit_gender(corpus, method = "genderize",
                    api_key = "", cache_dir = cache_dir)
  ), class = "scimapR_gender_lookup_failed")
  expect_length(readRDS(file.path(cache_dir, "genderize_cache.rds")), 0L)
  expect_s3_class(res, "sm_audit_gender")
  expect_equal(res$coverage, 0.0)
})

test_that("sm_audit_gender counts corresponding authors who are not first", {
  local_http_env()
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
  local_http_env()
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

test_that("gender lookups cache shuffled answers and retry only failed names", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 30, n_authors = 25)
  corpus$authors$display_name <- paste0("Name", 1:25, " Invented")
  cache_dir <- withr::local_tempdir()
  seen <- list()
  limit <- TRUE
  local_mocked_bindings(req_perform = function(req, ...) {
    query <- httr2::url_parse(req$url)$query
    names <- unlist(query[names(query) == "name[]"], use.names = FALSE)
    seen[[length(seen) + 1L]] <<- names
    expect_lte(length(names), 10L)
    expect_identical(query$apikey, "TEST-GENDER-KEY")
    if (limit && length(seen) == 3L) {
      return(http_response(status = 429L,
                           headers = list(`X-Rate-Limit-Reset` = "3600")))
    }
    http_response(lapply(rev(names), function(name) {
      list(name = name, gender = if (name == "name1") "female" else "male",
           probability = 0.9, count = 40L)
    }))
  }, .package = "httr2")
  warn <- expect_warning(
    res <- sm_audit_gender(corpus, method = "genderize",
                           api_key = "TEST-GENDER-KEY", cache_dir = cache_dir),
    class = "scimapR_gender_lookup_failed"
  )
  expect_identical(res$n_names_failed, 5L)
  expect_length(seen, 3L)
  expect_false(grepl("TEST-GENDER-KEY", conditionMessage(warn), fixed = TRUE))
  saved <- readRDS(file.path(cache_dir, "genderize_cache.rds"))
  expect_length(saved, 20L)
  expect_identical(saved$name1$gender, "female")
  expect_identical(saved$name2$gender, "male")
  expect_equal(res$coverage, 0.8)
  limit <- FALSE
  seen <- list()
  res <- sm_audit_gender(corpus, method = "genderize",
                         api_key = "TEST-GENDER-KEY", cache_dir = cache_dir)
  expect_length(seen, 1L)
  expect_setequal(seen[[1]], paste0("name", 21:25))
  expect_equal(res$coverage, 1)
  expect_identical(res$n_names_failed, 0L)
  saved <- readRDS(file.path(cache_dir, "genderize_cache.rds"))
  expect_false(any(grepl("TEST-GENDER-KEY", unlist(saved), fixed = TRUE)))
})

test_that("gender retries legacy failures but keeps valid null answers", {
  local_http_env()
  cache_dir <- withr::local_tempdir()
  file <- file.path(cache_dir, "genderize_cache.rds")
  saveRDS(list(failed = list(gender = NA_character_, confidence = NA_real_),
               unknown = list(gender = NA_character_, confidence = 0)), file)
  queried <- NULL
  local_mocked_bindings(req_perform = function(req, ...) {
    query <- httr2::url_parse(req$url)$query
    queried <<- unlist(query[names(query) == "name[]"], use.names = FALSE)
    http_response(list(list(name = "failed", gender = NULL,
                            probability = 0, count = 0L)))
  }, .package = "httr2")
  out <- .infer_gender_genderize(c("Failed", "Unknown"), "", cache_dir,
                                 rlang::current_env())
  expect_identical(queried, "failed")
  expect_equal(out$confidence, c(0, 0))
  expect_identical(out$n_failed, 0L)
  expect_identical(readRDS(file)$failed$count, 0L)
})

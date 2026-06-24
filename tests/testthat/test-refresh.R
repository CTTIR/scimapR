# Tests for R/refresh.R (sm_refresh) plus sm_staleness / sm_lock / sm_unlock.
# Fetchers are mocked; lock/unlock/staleness are pure or file-free.

age_corpus <- function(corpus, days = 365) {
  corpus$works$last_refreshed <- Sys.time() - days * 24 * 3600
  corpus
}

# ---- sm_staleness ----------------------------------------------------------

test_that("sm_staleness rejects a non-corpus input", {
  expect_error(sm_staleness(list()), class = "rlang_error")
})

test_that("sm_staleness returns empty tibble for empty corpus", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  st <- suppressMessages(sm_staleness(empty))
  expect_s3_class(st, "tbl_df")
  expect_equal(nrow(st), 0L)
  expect_true(all(c("work_id", "last_refreshed", "age_days", "is_stale") %in%
                    names(st)))
})

test_that("sm_staleness flags old works as stale and fresh ones as not", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  corpus <- age_corpus(corpus, days = 100)
  st <- suppressMessages(sm_staleness(corpus, threshold_days = 30))
  expect_true(all(st$is_stale))
  expect_true(all(st$age_days > 30))

  fresh <- corpus
  fresh$works$last_refreshed <- Sys.time()
  st2 <- suppressMessages(sm_staleness(fresh, threshold_days = 30))
  expect_false(any(st2$is_stale))
})

test_that("sm_staleness treats NA last_refreshed as stale (Inf age)", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  corpus$works$last_refreshed[1] <- as.POSIXct(NA)
  st <- suppressMessages(sm_staleness(corpus, threshold_days = 30))
  expect_true(st$is_stale[1])
  expect_true(is.infinite(st$age_days[1]))
})

# ---- sm_lock / sm_unlock ---------------------------------------------------

test_that("sm_lock sets the lock flag and records a reason", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  locked <- suppressMessages(sm_lock(corpus, reason = "archival"))
  expect_true(locked$metadata$is_locked)
  expect_equal(locked$metadata$lock_reason, "archival")
})

test_that("sm_lock on an already-locked corpus is a no-op", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  locked <- suppressMessages(sm_lock(corpus))
  expect_message(again <- sm_lock(locked), "already locked")
  expect_true(again$metadata$is_locked)
})

test_that("sm_unlock without confirm aborts on a locked corpus", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 5)
  locked <- suppressMessages(sm_lock(corpus, reason = "review"))
  expect_error(sm_unlock(locked, confirm = FALSE), "confirm")
})

test_that("sm_unlock with confirm clears the lock", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  locked <- suppressMessages(sm_lock(corpus))
  unlocked <- suppressMessages(sm_unlock(locked, confirm = TRUE))
  expect_false(unlocked$metadata$is_locked)
})

test_that("sm_unlock on an unlocked corpus is a no-op", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 7)
  expect_message(out <- sm_unlock(corpus, confirm = TRUE), "not locked")
  expect_false(isTRUE(out$metadata$is_locked))
})

test_that("sm_unlock validates the confirm flag", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 8)
  expect_error(sm_unlock(corpus, confirm = "yes"),
               class = "rlang_error")
})

# ---- sm_refresh ------------------------------------------------------------

test_that("sm_refresh rejects a non-corpus input", {
  expect_error(sm_refresh(list()), class = "rlang_error")
})

test_that("sm_refresh refuses to operate on a locked corpus", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 9)
  locked <- suppressMessages(sm_lock(corpus))
  expect_error(sm_refresh(locked), "locked")
})

test_that("sm_refresh rejects unknown sources", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 10)
  # NOTE: source bug in refresh.R:51 -- the cli_abort string mixes a
  # pluralized `{?s}` (keyed to single-length `bad`) with a multi-length
  # `{valid_sources}` interpolation, so cli raises an internal
  # "Multiple quantities for pluralization" error instead of the intended
  # clean message. We assert only that an error is raised (the rejection
  # still happens), not on the message text. See task report.
  expect_error(sm_refresh(corpus, sources = "not_a_source"))
})

test_that("sm_refresh returns corpus unchanged when nothing is stale", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 11)
  corpus$works$last_refreshed <- Sys.time()
  expect_message(
    out <- sm_refresh(corpus, max_age_days = 30, verbose = TRUE),
    "up to date"
  )
  expect_equal(nrow(out$provenance), nrow(corpus$provenance))
})

test_that("sm_refresh with the generic source marks works and adds provenance", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 12)
  corpus <- age_corpus(corpus, days = 400)
  # Force a provenance source that is not openalex/crossref/pubmed so the
  # generic (no-API) branch runs -- never touches the network.
  corpus$provenance$source <- "synthetic"

  n_prov_before <- nrow(corpus$provenance)
  out <- suppressMessages(
    sm_refresh(corpus, max_age_days = 30, verbose = FALSE)
  )
  expect_s3_class(out, "sm_corpus")
  expect_gt(nrow(out$provenance), n_prov_before)
  expect_true(any(grepl("_refresh$", out$provenance$source)))
  # last_refreshed timestamps were bumped for stale works.
  expect_true(all(out$works$last_refreshed > corpus$works$last_refreshed))
})

test_that("sm_refresh openalex branch applies mocked oa_fetch updates", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 13)
  corpus <- age_corpus(corpus, days = 400)
  corpus$provenance$source <- "openalex"
  corpus$works$openalex_id <- paste0("W", seq_len(nrow(corpus$works)))

  testthat::local_mocked_bindings(
    is_installed = function(pkg, ...) pkg == "openalexR",
    .package = "rlang"
  )
  testthat::local_mocked_bindings(
    oa_fetch = function(entity, identifier, verbose = FALSE, ...) {
      tibble::tibble(cited_by_count = 4242L, oa_status = "gold")
    },
    .package = "openalexR"
  )

  out <- suppressMessages(
    sm_refresh(corpus, max_age_days = 30,
               what = c("citations", "oa_status"), verbose = FALSE)
  )
  expect_true(all(out$works$cited_by_count == 4242L))
  expect_true(all(out$works$oa_status == "gold"))
})

test_that("sm_refresh honours the sources filter", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 14)
  corpus <- age_corpus(corpus, days = 400)
  corpus$provenance$source <- "synthetic"
  # Requesting only "openalex" excludes the synthetic-sourced stale works.
  expect_message(
    out <- sm_refresh(corpus, max_age_days = 30,
                      sources = "openalex", verbose = TRUE),
    "No stale works match"
  )
  expect_equal(nrow(out$provenance), nrow(corpus$provenance))
})

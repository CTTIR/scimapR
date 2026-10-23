# Tests for R/refresh.R (sm_refresh) plus sm_staleness / sm_lock / sm_unlock.
# Fetchers are mocked; lock/unlock/staleness are pure or file-free.

age_corpus <- function(corpus, days = 365) {
  corpus$works$last_refreshed <- Sys.time() - days * 24 * 3600
  corpus
}

# ---- sm_staleness ----------------------------------------------------------

test_that("sm_staleness rejects a non-corpus input", {
  local_http_env()
  expect_error(sm_staleness(list()), class = "rlang_error")
})

test_that("sm_staleness returns empty tibble for empty corpus", {
  local_http_env()
  empty <- sm_corpus(works = scimapR:::.empty_works())
  st <- suppressMessages(sm_staleness(empty))
  expect_s3_class(st, "tbl_df")
  expect_equal(nrow(st), 0L)
  expect_true(all(c("work_id", "last_refreshed", "age_days", "is_stale") %in%
                    names(st)))
})

test_that("sm_staleness flags old works as stale and fresh ones as not", {
  local_http_env()
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
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  corpus$works$last_refreshed[1] <- as.POSIXct(NA)
  st <- suppressMessages(sm_staleness(corpus, threshold_days = 30))
  expect_true(st$is_stale[1])
  expect_true(is.infinite(st$age_days[1]))
})

# ---- sm_lock / sm_unlock ---------------------------------------------------

test_that("sm_lock sets the lock flag and records a reason", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  locked <- suppressMessages(sm_lock(corpus, reason = "archival"))
  expect_true(locked$metadata$is_locked)
  expect_equal(locked$metadata$lock_reason, "archival")
})

test_that("sm_lock on an already-locked corpus is a no-op", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  locked <- suppressMessages(sm_lock(corpus))
  expect_message(again <- sm_lock(locked), "already locked")
  expect_true(again$metadata$is_locked)
})

test_that("sm_unlock without confirm aborts on a locked corpus", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 5)
  locked <- suppressMessages(sm_lock(corpus, reason = "review"))
  expect_error(sm_unlock(locked, confirm = FALSE), "confirm")
})

test_that("sm_unlock with confirm clears the lock", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  locked <- suppressMessages(sm_lock(corpus))
  unlocked <- suppressMessages(sm_unlock(locked, confirm = TRUE))
  expect_false(unlocked$metadata$is_locked)
})

test_that("sm_unlock on an unlocked corpus is a no-op", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 7)
  expect_message(out <- sm_unlock(corpus, confirm = TRUE), "not locked")
  expect_false(isTRUE(out$metadata$is_locked))
})

test_that("sm_unlock validates the confirm flag", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 8)
  expect_error(sm_unlock(corpus, confirm = "yes"),
               class = "rlang_error")
})

# ---- sm_refresh ------------------------------------------------------------

test_that("sm_refresh rejects a non-corpus input", {
  local_http_env()
  expect_error(sm_refresh(list()), class = "rlang_error")
})

test_that("sm_refresh refuses to operate on a locked corpus", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 9)
  locked <- suppressMessages(sm_lock(corpus))
  expect_error(sm_refresh(locked), "locked")
})

test_that("sm_refresh rejects unknown sources", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 10)
  for (bad in list("not_a_source", c("not_a_source", "second_bad"))) {
    err <- expect_error(sm_refresh(corpus, sources = bad),
                        class = "scimapR_refresh_unknown_source")
    expect_match(conditionMessage(err), "Unknown source")
    expect_match(conditionMessage(err), "not_a_source", fixed = TRUE)
    expect_false(grepl("pluralization", conditionMessage(err)))
  }
})

test_that("sm_refresh returns corpus unchanged when nothing is stale", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 11)
  corpus$works$last_refreshed <- Sys.time()
  expect_message(
    out <- sm_refresh(corpus, max_age_days = 30, verbose = TRUE),
    "up to date"
  )
  expect_equal(nrow(out$provenance), nrow(corpus$provenance))
})

test_that("unsupported refresh sources leave works stale", {
  local_http_env()
  corpus <- age_corpus(sm_example_corpus(n_works = 6, n_authors = 3))
  corpus$provenance$source <- "synthetic"
  expect_warning(out <- sm_refresh(corpus, verbose = FALSE),
                 class = "scimapR_refresh_skipped")
  expect_identical(out, corpus)
})

test_that("refresh applies matched answers and preserves failed timestamps", {
  local_http_env()
  corpus <- age_corpus(sm_example_corpus(n_works = 3, n_authors = 3))
  corpus$provenance$source <- "openalex"
  corpus$works$openalex_id <- paste0("W", 1:3)
  local_mocked_bindings(.openalex_lookup = function(ids, ...) {
    list(
      records = list(list(id = "W2", cited_by_count = 4242L),
                     list(id = "W1", open_access = list(oa_status = "gold"))),
      failed = "W3", condition = NULL
  )
  })
  expect_warning(out <- sm_refresh(corpus, verbose = FALSE, api_key = ""),
                 class = "scimapR_refresh_failed")
  expect_equal(out$works$cited_by_count[2], 4242L)
  expect_equal(out$works$oa_status[1], "gold")
  expect_identical(out$works$cited_by_count[1], corpus$works$cited_by_count[1])
  expect_identical(out$works$last_refreshed[3], corpus$works$last_refreshed[3])
  expect_identical(out$metadata$last_refresh, corpus$metadata$last_refresh)
  added <- utils::tail(out$provenance, 2)
  expect_setequal(added$source_id_external, c("W1", "W2"))
  expect_true(all(added$kind == "refresh"))
  expect_setequal(added$query, c("sm_refresh(what=citations)",
                                 "sm_refresh(what=oa_status)"))
})

test_that("rate-limited refresh neither changes data nor stamps success", {
  local_http_env()
  corpus <- age_corpus(sm_example_corpus(n_works = 60, n_authors = 3))
  corpus$provenance$source <- "openalex"
  calls <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    http_response(status = 429L, headers = list(`Retry-After` = "3600"))
  }, .package = "httr2")
  warn <- expect_warning(out <- sm_refresh(corpus, verbose = FALSE,
                                           api_key = ""),
                         class = "scimapR_refresh_failed")
  expect_identical(calls, 1L)
  expect_identical(out, corpus)
  expect_length(warn$work_ids, 60L)
  expect_match(conditionMessage(warn), "OPENALEX_API_KEY", fixed = TRUE)
})

test_that("refresh strips suffixes and ignores enrichment provenance", {
  local_http_env()
  corpus <- age_corpus(sm_example_corpus(n_works = 3, n_authors = 3))
  corpus$provenance$source <- "crossref"
  corpus$provenance$kind <- "api_query"
  enrichment <- corpus$provenance
  enrichment$source <- "openalex"
  enrichment$query <- "enrich_concepts_openalex"
  enrichment$fetch_date <- enrichment$fetch_date - 100
  old <- corpus$provenance
  old$source <- "crossref_refresh_refresh"
  old$fetch_date <- old$fetch_date + 100
  corpus$provenance <- dplyr::bind_rows(enrichment, corpus$provenance, old)
  calls <- 0L
  local_mocked_bindings(.crossref_lookup = function(dois, ...) {
    calls <<- calls + 1L
    list(records = lapply(dois, function(doi) {
      list(DOI = doi,
           `is-referenced-by-count` = 9L)
    }),
    failed = character(), condition = NULL)
  })
  for (i in 1:3) {
    n_before <- nrow(corpus$provenance)
    corpus <- age_corpus(corpus)
    out <- sm_refresh(corpus, sources = "crossref", verbose = FALSE,
                      api_key = "", mailto = "")
    added <- utils::tail(out$provenance, 3)
    expect_identical(nrow(out$provenance), n_before + 3L)
    expect_identical(added$source, rep("crossref_refresh", 3))
    expect_true(all(added$query == "sm_refresh(what=citations)"))
    corpus <- out
  }
  expect_identical(calls, 3L)
})

test_that("unimplemented refresh aspects and missing records stay explicit", {
  local_http_env()
  corpus <- age_corpus(sm_example_corpus(n_works = 3, n_authors = 3))
  corpus$provenance$source <- "crossref"
  expect_error(sm_refresh(corpus, what = "new_refs"),
               class = "scimapR_refresh_aspect_unsupported")
  local_mocked_bindings(.crossref_lookup = function(...) {
    list(
      records = list(), failed = character(), condition = NULL
  )
  })
  expect_warning(out <- sm_refresh(corpus, what = "oa_status", verbose = FALSE),
                 class = "scimapR_refresh_skipped")
  expect_identical(out, corpus)
  expect_warning(out <- sm_refresh(corpus, what = "citations", verbose = FALSE),
                 class = "scimapR_refresh_skipped")
  expect_identical(out, corpus)
  expect_warning(suppressWarnings(sm_refresh(corpus,
                                             what = c("citations",
                                                      "new_refs"),
                                             verbose = FALSE)), NA)
})

test_that("sm_refresh honours the sources filter", {
  local_http_env()
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

test_that("refresh ignores enrichment origins and uses authenticated HTTP", {
  local_http_env()
  corpus <- age_corpus(sm_example_corpus(n_works = 2, n_authors = 3))
  corpus$works$openalex_id <- c("W1", "W2")
  corpus$provenance$source <- c("openalex", "wos")
  extra <- corpus$provenance
  extra$source <- c("openalex_refresh", "openalex")
  extra$query <- c("sm_refresh(what=citations)", "enrich_concepts_openalex")
  extra$fetch_date <- extra$fetch_date + 1
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, extra)
  calls <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    q <- httr2::url_parse(req$url)$query
    expect_identical(q$filter, "openalex:W1")
    headers <- httr2::req_get_headers(req, redacted = "reveal")
    expect_identical(headers$Authorization, "Bearer REFRESH-KEY")
    http_response(list(results = list(list(id = "https://openalex.org/W1",
                                           cited_by_count = 17L))))
  }, .package = "httr2")
  expect_warning(
    out <- sm_refresh(corpus, api_key = "REFRESH-KEY", verbose = FALSE),
    class = "scimapR_refresh_skipped"
  )
  expect_identical(calls, 1L)
  expect_identical(out$works$cited_by_count[1], 17L)
  expect_identical(out$works$last_refreshed[2], corpus$works$last_refreshed[2])
  expect_identical(utils::tail(out$provenance$source, 1), "openalex_refresh")
  expect_false(any(grepl("REFRESH-KEY", unlist(out$provenance), fixed = TRUE)))
  corpus$provenance <- corpus$provenance[0, ]
  expect_warning(out <- sm_refresh(corpus, verbose = FALSE),
                 class = "scimapR_refresh_skipped")
  expect_identical(out, corpus)
  expect_identical(calls, 1L)
})

test_that("Crossref missing records and unsupported aspects remain stale", {
  local_http_env()
  corpus <- age_corpus(sm_example_corpus(n_works = 3, n_authors = 3))
  corpus$provenance$source <- "crossref"
  corpus$works$doi[3] <- NA_character_
  local_mocked_bindings(req_perform = function(req, ...) {
    http_response(list(message = list(`total-results` = 1L, items = list(
      list(DOI = toupper(corpus$works$doi[1]), `is-referenced-by-count` = 19L)
    ))))
  }, .package = "httr2")
  warnings <- list()
  out <- withCallingHandlers(
    sm_refresh(corpus, what = c("citations", "new_refs"), verbose = FALSE),
    warning = function(cnd) {
      warnings[[length(warnings) + 1L]] <<- cnd
      invokeRestart("muffleWarning")
    }
  )
  expect_s3_class(warnings[[1]], "scimapR_refresh_aspect_unsupported")
  expect_s3_class(warnings[[2]], "scimapR_refresh_skipped")
  expect_identical(out$works$cited_by_count[1], 19L)
  expect_identical(out$works$last_refreshed[2:3],
                   corpus$works$last_refreshed[2:3])
  expect_identical(nrow(out$provenance), nrow(corpus$provenance) + 1L)
})

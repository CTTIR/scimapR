# Tests for R/question-screen.R
# LLM/network calls are stubbed with testthat::local_mocked_bindings.

# --- sm_screen_regex ----------------------------------------------------

test_that("sm_screen_regex rejects a non-corpus input", {
  expect_error(
    sm_screen_regex(list(), include_terms = "x"),
    class = "rlang_error"
  )
})

test_that("sm_screen_regex requires non-empty include_terms", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_screen_regex(corpus), "non-empty")
  expect_error(sm_screen_regex(corpus, include_terms = character()),
               "non-empty")
})

test_that("sm_screen_regex returns the corpus unchanged for empty works", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  out <- sm_screen_regex(empty, include_terms = "x")
  expect_equal(nrow(out$screening), 0L)
})

test_that("sm_screen_regex classifies includes and excludes deterministically", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 3)
  expect_message(
    out <- sm_screen_regex(corpus, include_terms = c("spatial", "transcriptom")),
    "Regex screening"
  )
  scr <- out$screening[out$screening$stage == "regex", ]
  expect_equal(nrow(scr), 30L)
  expect_true(all(scr$decision %in% c("include", "exclude")))
  expect_true(all(scr$confidence == 1.0))
  expect_true(all(scr$source == "regex"))

  # Deterministic: same inputs -> identical decisions
  out2 <- suppressMessages(
    sm_screen_regex(corpus, include_terms = c("spatial", "transcriptom"))
  )
  scr2 <- out2$screening[out2$screening$stage == "regex", ]
  expect_identical(scr$decision, scr2$decision)
})

test_that("sm_screen_regex exclude terms take precedence over include", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 6,
                              with_embeddings = FALSE, seed = 9)
  # Use a term that appears in nearly every abstract as an excluder
  out <- suppressMessages(
    sm_screen_regex(corpus, include_terms = c("cancer"),
                    exclude_terms = c("study"))
  )
  scr <- out$screening[out$screening$stage == "regex", ]
  # Anything that matched the exclude term must be excluded with that reason
  excl <- scr[scr$reason == "Matched exclude term", ]
  expect_true(all(excl$decision == "exclude"))
})

test_that("sm_screen_regex marks works matching no include term as exclude", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 5,
                              with_embeddings = FALSE, seed = 2)
  out <- suppressMessages(
    sm_screen_regex(corpus, include_terms = "zzzznotpresentzzzz")
  )
  scr <- out$screening[out$screening$stage == "regex", ]
  expect_true(all(scr$decision == "exclude"))
  expect_true(all(scr$reason == "No include term matched"))
})

# --- sm_screen_summary --------------------------------------------------

test_that("sm_screen_summary handles a corpus with no screening", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_message(out <- sm_screen_summary(corpus), "No screening")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("stage", "decision", "n", "pct"))
})

test_that("sm_screen_summary tallies decisions by stage with percentages", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 12,
                              with_embeddings = FALSE,
                              with_screening = TRUE, seed = 5)
  out <- suppressMessages(sm_screen_summary(corpus))
  expect_named(out, c("stage", "decision", "n", "pct"))
  expect_true(all(out$n > 0L))
  # Percentages within each stage sum to ~100
  by_stage <- split(out$pct, out$stage)
  for (p in by_stage) {
    expect_equal(sum(p), 100, tolerance = 0.5)
  }
  # n totals equal the number of screened works
  expect_equal(sum(out$n), nrow(corpus$screening))
})

# --- sm_merge_screening_decisions --------------------------------------

test_that("sm_merge_screening_decisions appends external decisions", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  ext <- tibble::tibble(
    work_id = corpus$works$work_id[1:3],
    stage = "title-abstract",
    decision = c("include", "exclude", "include"),
    reason = "manual",
    confidence = 1.0,
    source = "manual",
    decided_at = Sys.time()
  )
  out <- sm_merge_screening_decisions(corpus, ext)
  expect_s3_class(out, "sm_corpus")
  expect_equal(nrow(out$screening), 3L)
  expect_equal(out$screening$decision, c("include", "exclude", "include"))
})

test_that("sm_merge_screening_decisions rejects a non-corpus", {
  expect_error(
    sm_merge_screening_decisions(list(), tibble::tibble()),
    class = "rlang_error"
  )
})

# --- sm_screen_against_question (LLM mocked) ---------------------------

test_that("sm_screen_against_question rejects bad inputs", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  q <- sm_question(text = "q", framework = "free")
  expect_error(
    sm_screen_against_question(list(), q),
    class = "rlang_error"
  )
  expect_error(
    sm_screen_against_question(corpus, list()),
    "sm_question"
  )
})

test_that("sm_screen_against_question parses a mocked LLM JSON response", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  q <- sm_question(text = "spatial transcriptomics", framework = "free")
  fake_llm <- structure(list(), class = "fake_chat")

  # Return one decision object per work so all six parse cleanly
  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(provider, system_prompt, user_prompt, ...) {
      objs <- paste(
        rep('{"decision":"include","reason":"relevant","confidence":0.88}', 6),
        collapse = ","
      )
      paste0("[", objs, "]")
    }
  )

  out <- sm_screen_against_question(
    corpus, q, stages = "title-abstract",
    llm = fake_llm, batch_size = 10L, verbose = FALSE
  )
  scr <- out$screening[out$screening$stage == "title-abstract", ]
  expect_equal(nrow(scr), 6L)
  expect_true(all(scr$decision == "include"))
  expect_true(all(scr$source == "llm"))
  expect_true(all(scr$confidence == 0.88))
})

test_that("sm_screen_against_question marks works uncertain on LLM failure", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  q <- sm_question(text = "q", framework = "free")
  fake_llm <- structure(list(), class = "fake_chat")

  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(...) stop("simulated LLM outage")
  )

  out <- suppressMessages(sm_screen_against_question(
    corpus, q, stages = "title-abstract",
    llm = fake_llm, batch_size = 10L, verbose = FALSE
  ))
  scr <- out$screening[out$screening$stage == "title-abstract", ]
  expect_equal(nrow(scr), 4L)
  expect_true(all(scr$decision == "uncertain"))
  expect_true(all(scr$source == "llm_error"))
})

test_that("sm_screen_against_question falls back to uncertain on unparseable text", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2,
                              with_embeddings = FALSE, seed = 8)
  q <- sm_question(text = "q", framework = "free")
  fake_llm <- structure(list(), class = "fake_chat")

  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(...) "this is not JSON at all"
  )

  out <- sm_screen_against_question(
    corpus, q, stages = "title-abstract",
    llm = fake_llm, batch_size = 10L, verbose = FALSE
  )
  scr <- out$screening[out$screening$stage == "title-abstract", ]
  expect_equal(nrow(scr), 3L)
  expect_true(all(scr$decision == "uncertain"))
  expect_true(all(scr$source == "llm_parse_error"))
})

test_that("sm_screen_against_question respects batching", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  q <- sm_question(text = "q", framework = "free")
  fake_llm <- structure(list(), class = "fake_chat")

  n_calls <- 0L
  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(provider, system_prompt, user_prompt, ...) {
      n_calls <<- n_calls + 1L
      # one object per batch (batch_size = 2 => 3 batches)
      '[{"decision":"exclude","reason":"no","confidence":0.5}]'
    }
  )

  out <- sm_screen_against_question(
    corpus, q, stages = "title-abstract",
    llm = fake_llm, batch_size = 2L, verbose = FALSE
  )
  # 5 works / batch_size 2 => 3 batches => 3 LLM calls
  expect_equal(n_calls, 3L)
  scr <- out$screening[out$screening$stage == "title-abstract", ]
  expect_equal(nrow(scr), 5L)
})

# --- internal parser ----------------------------------------------------

test_that(".parse_screening_response normalizes invalid decisions to uncertain", {
  f <- scimapR:::.parse_screening_response
  resp <- '[{"decision":"maybe","reason":"hmm","confidence":0.3}]'
  out <- f(resp, work_ids = "W1", stage = "title-abstract")
  expect_equal(out$decision, "uncertain")
  expect_equal(out$source, "llm")
})

test_that(".parse_screening_response pads when LLM returns too few results", {
  f <- scimapR:::.parse_screening_response
  resp <- '[{"decision":"include","reason":"ok","confidence":0.9}]'
  out <- f(resp, work_ids = c("W1", "W2", "W3"), stage = "title-abstract")
  expect_equal(nrow(out), 3L)
  expect_equal(out$source, c("llm", "llm_incomplete", "llm_incomplete"))
  expect_equal(out$decision, c("include", "uncertain", "uncertain"))
})

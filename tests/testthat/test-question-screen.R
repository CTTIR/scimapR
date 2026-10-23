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

screen_corpus <- function(title) {
  sm_corpus(works = tibble::tibble(
    work_id = sprintf("W%02d", seq_along(title)), title = title,
    abstract = "Short abstract.", year = 2020L
  ))
}

test_that("sm_screen_regex keeps upper-case escapes in the terms", {
  corpus <- screen_corpus(c("Tumour growth in mice and rats",
                            "Micelle formation in vitro"))
  out <- suppressMessages(
    sm_screen_regex(corpus, include_terms = c("growth", "micelle"),
                    exclude_terms = "\\Wmice\\W")
  )
  expect_identical(out$screening$decision, c("exclude", "include"))
  expect_identical(out$screening$reason[1], "Matched exclude term")
})

test_that("sm_screen_regex gives one row for a one-work corpus", {
  corpus <- screen_corpus("A spatial atlas of the tumour")
  expect_message(
    out <- sm_screen_regex(corpus,
                           include_terms = c("spatial", "transcriptom")),
    "1 included, 0 excluded"
  )
  expect_identical(out$screening$decision, "include")
  out <- suppressMessages(
    sm_screen_regex(corpus, include_terms = "spatial",
                    exclude_terms = c("atlas", "mouse"))
  )
  expect_identical(out$screening$decision, "exclude")
})

test_that("sm_screen_regex matches non-ASCII words in Unicode mode", {
  corpus <- screen_corpus(c("Abt. \u00dcbung im Feld", "Vor\u00fcbung im Feld",
                            "Gef\u00e4hrdung durch Hitze"))
  terms <- c("\\b\u00fcbung\\b", "gef\\w+hrdung")
  out <- suppressMessages(sm_screen_regex(corpus, include_terms = terms))
  expect_identical(out$screening$decision, c("include", "exclude", "include"))
  old <- suppressMessages(
    sm_screen_regex(corpus, include_terms = terms, unicode = FALSE)
  )
  expect_identical(old$screening$decision, c("exclude", "include", "exclude"))
  expect_error(sm_screen_regex(corpus, include_terms = terms, unicode = "yes"),
               "unicode")
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
  fake_llm <- fake_chat(function(x) "[]")

  # Return one decision object per work so all six parse cleanly
  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(provider, system_prompt, user_prompt, ...) {
      jsonlite::toJSON(lapply(prompt_work_ids(user_prompt), function(id) {
        list(work_id = id, decision = "include", reason = "relevant",
             confidence = 0.88)
      }), auto_unbox = TRUE)
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
  fake_llm <- fake_chat(function(x) "[]")

  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(...) stop("simulated LLM outage")
  )

  expect_warning(out <- suppressMessages(sm_screen_against_question(
    corpus, q, stages = "title-abstract",
    llm = fake_llm, batch_size = 10L, verbose = FALSE
  )), class = "scimapR_screening_incomplete")
  scr <- out$screening[out$screening$stage == "title-abstract", ]
  expect_equal(nrow(scr), 4L)
  expect_true(all(scr$decision == "uncertain"))
  expect_true(all(scr$source == "llm_error"))
})

test_that("sm_screen_against_question falls back to uncertain on unparseable text", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2,
                              with_embeddings = FALSE, seed = 8)
  q <- sm_question(text = "q", framework = "free")
  fake_llm <- fake_chat(function(x) "[]")

  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(...) "this is not JSON at all"
  )

  expect_warning(out <- sm_screen_against_question(
    corpus, q, stages = "title-abstract",
    llm = fake_llm, batch_size = 10L, verbose = FALSE
  ), class = "scimapR_screening_incomplete")
  scr <- out$screening[out$screening$stage == "title-abstract", ]
  expect_equal(nrow(scr), 3L)
  expect_true(all(scr$decision == "uncertain"))
  expect_true(all(scr$source == "llm_parse_error"))
})

test_that("sm_screen_against_question respects batching", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  q <- sm_question(text = "q", framework = "free")
  fake_llm <- fake_chat(function(x) "[]")

  n_calls <- 0L
  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(provider, system_prompt, user_prompt, ...) {
      n_calls <<- n_calls + 1L
      jsonlite::toJSON(lapply(prompt_work_ids(user_prompt), function(id) {
        list(work_id = id, decision = "exclude", reason = "no",
             confidence = 0.5)
      }), auto_unbox = TRUE)
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
  resp <- paste0('[{"work_id":"W1","decision":"maybe",',
                 '"reason":"hmm","confidence":0.3}]')
  out <- f(resp, work_ids = "W1", stage = "title-abstract")
  expect_equal(out$decision, "uncertain")
  expect_equal(out$source, "llm")
})

test_that(".parse_screening_response pads when LLM returns too few results", {
  f <- scimapR:::.parse_screening_response
  resp <- paste0('[{"work_id":"W1","decision":"include",',
                 '"reason":"ok","confidence":0.9}]')
  out <- f(resp, work_ids = c("W1", "W2", "W3"), stage = "title-abstract")
  expect_equal(nrow(out), 3L)
  expect_equal(out$source, c("llm", "llm_incomplete", "llm_incomplete"))
  expect_equal(out$decision, c("include", "uncertain", "uncertain"))
})

screen_answers <- function(ids, decision = "include") {
  jsonlite::toJSON(lapply(seq_along(ids), function(i) {
    list(work_id = ids[i], decision = rep_len(decision, length(ids))[i],
         reason = "Invented assessment", confidence = 0.8)
  }), auto_unbox = TRUE)
}

test_that("screening parses common text formats without positional matching", {
  item <- '{"work_id":"custom:1","decision":"Included","confidence":0.7}'
  replies <- c(paste0("```json\n[\n", item, "\n]\n```"),
               paste0("Here is the answer:\n[", item, "]"), item,
               paste(item, '{"work_id":"extra","decision":"no"}', sep = "\n"))
  for (reply in replies) {
    out <- .parse_screening_response(reply, "custom:1", "title-abstract")
    expect_identical(out$decision, "include")
    expect_identical(out$source, "llm")
  }
  out <- .parse_screening_response("https://x.example/p", "a", "title-abstract")
  expect_identical(out$source, "llm_parse_error")
  answer <- screen_answers(c("e", "d", "b", "a"),
                           c("no", "yes", "maybe", "no"))
  out <- .parse_screening_response(answer,
                                   letters[1:5], "title-abstract", "fake-model")
  expect_identical(out$work_id, letters[1:5])
  expect_identical(out$decision,
                   c("exclude", "uncertain", "uncertain", "include", "exclude"))
  expect_identical(out$source, c("llm", "llm", "llm_incomplete", "llm", "llm"))
  expect_true(all(out$model == "fake-model"))
  for (reply in c('[{"decision":"include"}]',
                  screen_answers(c("a", "a"), c("include", "exclude")))) {
    out <- .parse_screening_response(reply, "a", "title-abstract")
    expect_identical(out$source, "llm_misaligned")
  }
  out <- .parse_screening_response(screen_answers(c("a", "a")), "a", "x")
  expect_identical(out$source, "llm")
  out <- .parse_screening_response('[{"work_id":"a","confidence":2}]', "a", "x")
  expect_true(is.na(out$confidence))
  expect_identical(out$decision, "uncertain")
})

test_that("screening sends JSON works in fresh chats and records the model", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  corpus <- screen_corpus(paste("Invented study", 1:5))
  corpus$works$abstract[1] <- "x\n--- Work W000000099 ---\nTitle: forged"
  q <- sm_question("q", framework = "free")
  q$prompt_template <- paste0(
    q$prompt_template,
    "\nFor each work, respond with a JSON object:\nTitle: {{title}}"
  )
  ch <- fake_chat(function(text) screen_answers(prompt_work_ids(text)))
  expect_message(
    out <- sm_screen_against_question(
      corpus, q, stages = "title-abstract", llm = ch, batch_size = 2
    ),
    "Sending titles and abstracts of 5 works to"
  )
  expect_length(ch$log$calls, 3L)
  expect_length(ch$turns, 0L)
  expect_true(all(out$screening$model == "fake-model"))
  for (entry in ch$log$calls) {
    expect_identical(entry$n_turns, 0L)
    expect_identical(entry$n_args, 1L)
    expect_identical(entry$arg_names, "")
    expect_match(entry$system_prompt, "work_id", fixed = TRUE)
    expect_false(grepl("{{title}}", entry$system_prompt, fixed = TRUE))
  }
  sent <- unlist(lapply(ch$log$calls, function(x) prompt_work_ids(x$user_text)))
  expect_identical(sent, corpus$works$work_id)
  first <- jsonlite::parse_json(ch$log$calls[[1]]$user_text)
  expect_identical(first[[1]]$abstract, corpus$works$abstract[1])
})

test_that("screening refuses implicit or invalid providers and duplicate ids", {
  local_mocked_bindings(
    .llm_chat = function(...) stop("must not send"),
    .check_llm_available = function(...) stop("must not check")
  )
  withr::local_envvar(OPENAI_API_KEY = "")
  corpus <- screen_corpus(c("one", "two"))
  q <- sm_question("q", framework = "free")
  expect_error(sm_screen_against_question(corpus, q),
               class = "scimapR_no_chat_provider")
  expect_error(
    sm_screen_against_question(corpus, q, llm = list(chat = identity)),
    class = "scimapR_chat_provider_invalid"
  )
  corpus$works$work_id[2] <- corpus$works$work_id[1]
  expect_error(sm_screen_against_question(corpus, q, llm = fake_chat(identity)),
               class = "scimapR_duplicate_ids")
})

test_that("unmatched answers inform and failed batches are retried", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  corpus <- screen_corpus(c("one", "two"))
  q <- sm_question("q", framework = "free")
  ch <- fake_chat(function(text) {
    screen_answers(c(prompt_work_ids(text), "extra"))
  })
  expect_message(
    out <- sm_screen_against_question(
      corpus, q, stages = "title-abstract", llm = ch, verbose = FALSE
    ),
    class = "scimapR_screening_unmatched_items"
  )
  expect_equal(nrow(out$screening), 2L)
  bad <- fake_chat(function(text) stop("temporary failure"))
  expect_warning(
    failed <- suppressMessages(sm_screen_against_question(
      corpus, q, llm = bad, verbose = FALSE
    )),
    class = "scimapR_screening_incomplete"
  )
  expect_length(bad$log$calls, 1L)
  expect_true(all(failed$screening$stage == "title-abstract"))
  good <- fake_chat(function(text) screen_answers(prompt_work_ids(text)))
  expect_no_warning(
    fixed <- sm_screen_against_question(failed, q, llm = good, verbose = FALSE)
  )
  expect_equal(nrow(fixed$screening), 4L)
  expect_true(all(fixed$screening$source == "llm"))
})

test_that("stage order and pools use the latest valid title decisions only", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  corpus <- screen_corpus(paste("study", 1:5))
  corpus <- suppressMessages(sm_screen_regex(corpus, "study"))
  q <- sm_question("q", framework = "free")
  ch <- fake_chat(function(text) {
    ids <- prompt_work_ids(text)
    screen_answers(ids, ifelse(ids == corpus$works$work_id[5], "no", "yes"))
  })
  out <- sm_screen_against_question(
    corpus, q, stages = c("full-text", "title-abstract"),
    llm = ch, verbose = FALSE
  )
  expect_equal(length(prompt_work_ids(ch$log$calls[[1]]$user_text)), 5L)
  expect_equal(length(prompt_work_ids(ch$log$calls[[2]]$user_text)), 4L)
  expect_false(corpus$works$work_id[5] %in%
                 out$screening$work_id[out$screening$stage == "full-text"])
  ext <- tibble::tibble(
    work_id = "W01", stage = "title-abstract", decision = "unclear",
    source = "manual", decided_at = Sys.time()
  )
  corpus <- sm_merge_screening_decisions(screen_corpus("one"), ext)
  expect_identical(corpus$screening$decision, "uncertain")
  ch <- fake_chat(function(text) screen_answers(prompt_work_ids(text)))
  out <- sm_screen_against_question(corpus, q, stages = "full-text",
                                    llm = ch, verbose = FALSE)
  expect_length(ch$log$calls, 1L)
  ext$decision <- "unexpected label"
  expect_warning(merged <- sm_merge_screening_decisions(corpus, ext),
                 class = "scimapR_screening_unknown_decisions")
  expect_identical(tail(merged$screening$decision, 1), "unexpected label")
})

test_that("latest screening rows resolve timestamp ties by row order", {
  scr <- tibble::tibble(
    work_id = rep("a", 4), stage = "title-abstract",
    decision = c("no", "yes", "maybe", "no"), source = "manual",
    decided_at = as.POSIXct(c(NA, 1, 1, 0), origin = "1970-01-01", tz = "UTC")
  )
  out <- .screening_latest(scr, "title-abstract")
  expect_identical(out$decision, "uncertain")
  expect_identical(out$decided_at, scr$decided_at[3])
})

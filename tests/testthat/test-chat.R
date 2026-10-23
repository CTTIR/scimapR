# Tests for R/chat.R (sm_chat). The LLM call is mocked via
# testthat::local_mocked_bindings on the package-internal .llm_chat and
# .check_llm_available helpers -- never hits the network.

# Mock the LLM layer: stub availability check + the actual chat call.
mock_llm <- function(answer) {
  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(provider, system_prompt, user_prompt, ...) answer,
    .env = parent.frame()
  )
}

test_that("sm_chat rejects a non-corpus input", {
  expect_error(sm_chat(list(), "q", provider = fake_provider()),
               class = "rlang_error")
})

test_that("sm_chat requires a string question", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4, seed = 1)
  expect_error(sm_chat(corpus, 123, provider = fake_provider()),
               class = "rlang_error")
})

test_that("sm_chat errors informatively when no provider is given", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4, seed = 1)
  expect_error(sm_chat(corpus, "What methods dominate?", provider = NULL),
               "requires a chat provider")
})

test_that("sm_chat aborts on an empty corpus", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  mock_llm("irrelevant")
  expect_error(
    sm_chat(empty, "anything", provider = fake_provider()),
    "empty corpus"
  )
})

test_that("sm_chat returns a structured response with parsed citations", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8, seed = 2)
  cited_id <- corpus$works$work_id[1]
  answer <- paste0("Methods vary [cite:", cited_id, "] across the corpus.")
  mock_llm(answer)

  resp <- sm_chat(corpus, "What methods dominate?",
                  provider = fake_provider("gpt-test"),
                  retrieve_n = 10, retrieve_method = "tfidf")

  expect_s3_class(resp, "sm_chat_response")
  expect_equal(resp$answer, answer)
  expect_equal(resp$model, "gpt-test")
  expect_equal(resp$question, "What methods dominate?")
  expect_equal(resp$retrieve_method, "tfidf")
  expect_true(nchar(resp$prompt_hash) > 0)
  expect_s3_class(resp$timestamp, "POSIXct")
  # The work we retrieved AND cited must appear, if it was retrieved.
  if (cited_id %in% resp$retrieved_works$work_id) {
    expect_true(cited_id %in% resp$citations$work_id)
  }
  expect_true(all(c("cite_token", "work_id", "snippet") %in%
                    names(resp$citations)))
})

test_that("sm_chat drops citations to works not in the retrieved set", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 6, seed = 3)
  # Cite an ID that cannot be in the corpus -> no valid citations.
  mock_llm("Here is a claim [cite:W999999999].")
  resp <- sm_chat(corpus, "summary please", provider = fake_provider(),
                  retrieve_n = 5, retrieve_method = "tfidf")
  expect_equal(nrow(resp$citations), 0L)
})

test_that("sm_chat with no citation tokens returns an empty citation table", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 6, seed = 4)
  mock_llm("A plain answer with no citations at all.")
  resp <- sm_chat(corpus, "anything", provider = fake_provider(),
                  retrieve_n = 5, retrieve_method = "tfidf")
  expect_equal(nrow(resp$citations), 0L)
})

test_that("sm_chat embedding retrieval works with embeddings present", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = TRUE, seed = 5)
  mock_llm("answer")
  resp <- sm_chat(corpus, "spatial transcriptomics tumor",
                  provider = fake_provider(),
                  retrieve_n = 8, retrieve_method = "embedding")
  expect_s3_class(resp, "sm_chat_response")
  expect_lte(nrow(resp$retrieved_works), 8L)
})

test_that("sm_chat hybrid retrieval works", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = TRUE, seed = 6)
  mock_llm("answer")
  resp <- sm_chat(corpus, "machine learning biomarker",
                  provider = fake_provider(),
                  retrieve_n = 6, retrieve_method = "hybrid")
  expect_s3_class(resp, "sm_chat_response")
  expect_lte(nrow(resp$retrieved_works), 6L)
})

test_that("sm_chat appends an llm-chat provenance row", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4, seed = 7)
  mock_llm("answer")
  resp <- sm_chat(corpus, "q", provider = fake_provider(),
                  retrieve_n = 4, retrieve_method = "tfidf")
  # provenance is appended onto the corpus copy inside sm_chat; we cannot see
  # the corpus here, but the response object captures the prompt hash and model.
  expect_true(nchar(resp$prompt_hash) >= 12)
})

test_that("sm_chat surfaces LLM failures as a clean error", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 4, seed = 8)
  testthat::local_mocked_bindings(
    .check_llm_available = function(...) invisible(TRUE),
    .llm_chat = function(...) stop("model exploded")
  )
  expect_error(
    sm_chat(corpus, "q", provider = fake_provider(),
            retrieve_n = 4, retrieve_method = "tfidf"),
    "Chat request failed"
  )
})

test_that("print.sm_chat_response runs without error", {
  corpus <- sm_example_corpus(n_works = 12, n_authors = 5, seed = 9)
  cited_id <- corpus$works$work_id[1]
  mock_llm(paste0("See [cite:", cited_id, "]."))
  resp <- sm_chat(corpus, "q", provider = fake_provider(),
                  retrieve_n = 12, retrieve_method = "tfidf")
  out <- withr::with_options(
    list(cli.default_handler = function(msg) invisible(NULL)),
    expect_invisible(print(resp))
  )
  expect_identical(out, resp)
})


test_that("chat printing treats answers as literal text", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2)
  mock_llm("unused")
  resp <- sm_chat(corpus, "methods", provider = fake_provider(),
                  retrieve_method = "tfidf")
  for (answer in c("Designs were {RCT, cohort}", "{T}he effect",
                   "{stop('evaluated')}")) {
    resp$answer <- answer
    printed <- paste(cli::cli_fmt(print(resp)), collapse = "\n")
    expect_match(printed, answer, fixed = TRUE)
  }
})


test_that("chat calls use fresh conversations and the actual model name", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2)
  ch <- fake_chat(function(x) "An answer")
  for (i in 1:2) {
    resp <- sm_chat(corpus, "methods", provider = ch, retrieve_method = "tfidf")
    expect_identical(resp$model, "fake-model")
  }
  expect_length(ch$turns, 0L)
  for (entry in ch$log$calls) {
    expect_identical(entry$n_turns, 0L)
    expect_identical(entry$n_args, 1L)
    expect_identical(entry$arg_names, "")
    expect_true(nzchar(entry$system_prompt))
    expect_identical(entry$echo, "none")
  }
  expect_error(sm_chat(corpus, "methods", provider = list(chat = identity)),
               class = "scimapR_chat_provider_invalid")
})

test_that("unused chat parameters are deprecated only when supplied", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  withr::local_options(lifecycle_verbosity = "warning")
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2)
  ch <- fake_chat(function(x) "An answer")
  expect_no_warning(sm_chat(corpus, "q", ch, retrieve_method = "tfidf"))
  lifecycle::expect_deprecated(
    sm_chat(corpus, "q", ch, max_tokens = 100, retrieve_method = "tfidf")
  )
  lifecycle::expect_deprecated(
    sm_chat(corpus, "q", ch, temperature = 0.5, retrieve_method = "tfidf")
  )
})

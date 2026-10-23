test_that("the adapter rejects incomplete chat objects", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  for (bad in list(list(chat = function(...) "x"), 1, NULL)) {
    expect_error(.llm_chat(bad, "SYS", "USER"),
                 class = "scimapR_chat_provider_invalid")
  }
})

test_that("the adapter sets a system prompt on a fresh conversation", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  ch <- fake_chat(function(x) c("first", "second"))
  ch$set_system_prompt("original instructions")
  ch$set_turns(list("old turn"))
  for (i in 1:2) expect_identical(.llm_chat(ch, "SYS", "USER"), "first\nsecond")
  expect_identical(ch$turns, list("old turn"))
  expect_identical(ch$system_prompt, "original instructions")
  for (entry in ch$log$calls) {
    expect_identical(entry$n_turns, 0L)
    expect_identical(entry$n_args, 1L)
    expect_identical(entry$arg_names, "")
    expect_identical(entry$system_prompt, "SYS")
    expect_identical(entry$echo, "none")
  }
})

test_that("a real chat object can be cloned without a request", {
  skip_if_not_installed("ellmer")
  withr::local_envvar(OPENAI_API_KEY = "test-key")
  ch <- ellmer::chat_openai(model = "test-model", system_prompt = "own prompt")
  fresh <- .llm_fresh_chat(ch, "SYS")
  expect_identical(fresh$get_system_prompt(), "SYS")
  expect_length(fresh$get_turns(), 0L)
  expect_identical(ch$get_system_prompt(), "own prompt")
  expect_identical(.llm_model_name(ch), "test-model")
})

test_that("model names have safe fallbacks", {
  expect_identical(.llm_model_name(list(model = "fallback")), "fallback")
  expect_identical(.llm_model_name(1), "unknown")
  expect_identical(.llm_model_name(list(get_model = function() stop("bad"))),
                   "unknown")
})

test_that("a broken model accessor still allows the model field fallback", {
  provider <- list(get_model = function() stop("unavailable"), model = "backup")
  expect_identical(.llm_model_name(provider), "backup")
})

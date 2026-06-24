# Tests for R/question-class.R + question-print.R (S3 print/format/is_)

test_that("is_sm_question returns TRUE for an sm_question", {
  q <- sm_question(text = "q", framework = "free")
  expect_true(is_sm_question(q))
})

test_that("is_sm_question returns FALSE for other objects", {
  expect_false(is_sm_question(1))
  expect_false(is_sm_question("text"))
  expect_false(is_sm_question(list(framework = "PICO")))
  expect_false(is_sm_question(NULL))
})

test_that("format.sm_question produces a compact single-line summary", {
  q <- sm_question(text = "Short question", framework = "PICO",
                   intervention = "drug")
  out <- format(q)
  expect_type(out, "character")
  expect_length(out, 1L)
  expect_match(out, "<sm_question> \\[PICO\\]")
  expect_match(out, "Short question")
})

test_that("format.sm_question truncates long text with an ellipsis", {
  long <- paste(rep("word", 40), collapse = " ")
  q <- sm_question(text = long, framework = "free")
  out <- format(q)
  expect_match(out, "\\.\\.\\.$")
  # 60 chars + "..." marker => roughly 63 chars in the body
  expect_true(nchar(out) < nchar(long))
})

test_that("print.sm_question runs and returns invisibly", {
  q <- sm_question(text = "Does X affect Y?", framework = "PICO",
                   population = "adults", intervention = "X",
                   comparison = "control", outcome = "Y",
                   include_terms = "trial", exclude_terms = "rodent",
                   notes = "some notes")
  txt <- cli::cli_fmt(print(q))
  full <- paste(txt, collapse = "\n")
  expect_match(full, "sm_question")
  expect_match(full, "Framework")
  expect_invisible(print(q))
})

test_that("print.sm_question prints structured fields and query strings", {
  q <- sm_question(text = "q", framework = "PICOS",
                   population = "p", intervention = "i",
                   design = "RCT", timeframe = "2015-2020")
  full <- paste(cli::cli_fmt(print(q)), collapse = "\n")
  expect_match(full, "Structured fields")
  expect_match(full, "Query strings")
})

test_that("print.sm_question works for a minimal free question", {
  q <- sm_question(text = "minimal", framework = "free")
  full <- paste(cli::cli_fmt(print(q)), collapse = "\n")
  expect_match(full, "Languages")
})

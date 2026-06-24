# Tests for R/question-build.R (sm_question builder and helpers)

test_that("sm_question requires a non-empty text string", {
  expect_error(sm_question(text = 123), "single string")
  expect_error(sm_question(text = ""), "non-empty string")
  expect_error(sm_question(text = c("a", "b")), "single string")
})

test_that("sm_question rejects an unknown framework", {
  expect_error(
    sm_question(text = "q", framework = "NOTREAL"),
    "should be one of"
  )
})

test_that("sm_question builds a PICO object with all fields", {
  q <- sm_question(
    text = "Does immunotherapy improve survival in melanoma?",
    framework = "PICO",
    population = "melanoma",
    intervention = "immunotherapy",
    comparison = "chemotherapy",
    outcome = "survival"
  )
  expect_s3_class(q, "sm_question")
  expect_true(is_sm_question(q))
  expect_equal(q$framework, "PICO")
  expect_equal(q$population, "melanoma")
  expect_equal(q$intervention, "immunotherapy")
  expect_match(q$id, "^Q-[0-9a-f]{16}$")
  expect_s3_class(q$created, "POSIXct")
  expect_named(q$query_strings,
               c("generic", "pubmed", "openalex", "crossref"))
  expect_type(q$prompt_template, "character")
})

test_that("sm_question id is content-addressable and stable", {
  q1 <- sm_question(text = "same", framework = "free")
  q2 <- sm_question(text = "same", framework = "free")
  expect_identical(q1$id, q2$id)

  q3 <- sm_question(text = "different", framework = "free")
  expect_false(identical(q1$id, q3$id))
})

test_that("sm_question id is invariant to include/exclude term order", {
  q1 <- sm_question(text = "x", framework = "free",
                    include_terms = c("a", "b"))
  q2 <- sm_question(text = "x", framework = "free",
                    include_terms = c("b", "a"))
  expect_identical(q1$id, q2$id)
})

test_that("sm_question warns when PICO intervention is missing", {
  expect_message(
    sm_question(text = "q", framework = "PICO", population = "p"),
    "intervention"
  )
})

test_that("sm_question warns when PECO exposure is missing", {
  expect_message(
    sm_question(text = "q", framework = "PECO", population = "p"),
    "exposure"
  )
})

test_that("sm_question warns when PICOS design is missing", {
  expect_message(
    sm_question(text = "q", framework = "PICOS",
                population = "p", intervention = "i"),
    "design"
  )
})

test_that("sm_question free framework does not warn", {
  expect_no_message(
    sm_question(text = "q", framework = "free")
  )
})

test_that("query strings AND together structured facets", {
  q <- sm_question(text = "q", framework = "PICO",
                   population = "adults", intervention = "drug X",
                   outcome = "mortality")
  expect_match(q$query_strings$openalex, "\\(adults\\)")
  expect_match(q$query_strings$openalex, "\\(drug X\\)")
  expect_match(q$query_strings$openalex, " AND ")
})

test_that("free-form query with no fields and no include_terms is a wildcard", {
  q <- sm_question(text = "q", framework = "free")
  expect_equal(q$query_strings$openalex, "*")
})

test_that("include and exclude terms appear in generic query", {
  q <- sm_question(text = "q", framework = "free",
                   include_terms = c("ai", "ml"),
                   exclude_terms = c("review"))
  expect_match(q$query_strings$generic, "\\(ai OR ml\\)")
  expect_match(q$query_strings$generic, "NOT \\(review\\)")
})

test_that("pubmed query uses [tiab] tags for facets", {
  q <- sm_question(text = "q", framework = "PICO",
                   population = "kids", intervention = "vaccine",
                   outcome = "infection")
  expect_match(q$query_strings$pubmed, "\\(kids\\[tiab\\]\\)")
  expect_match(q$query_strings$pubmed, "\\(vaccine\\[tiab\\]\\)")
  expect_match(q$query_strings$pubmed, "\\(infection\\[tiab\\]\\)")
})

test_that("PECO exposure is included in pubmed tiab clause", {
  q <- sm_question(text = "q", framework = "PECO",
                   population = "workers", exposure = "asbestos",
                   outcome = "cancer")
  expect_match(q$query_strings$pubmed, "\\(asbestos\\[tiab\\]\\)")
})

test_that("prompt template includes the research question and facets", {
  q <- sm_question(text = "Q about cancer", framework = "PICO",
                   population = "adults", intervention = "drug",
                   comparison = "placebo", outcome = "OS",
                   include_terms = "trial", exclude_terms = "rodent")
  pt <- q$prompt_template
  expect_match(pt, "Research question: Q about cancer")
  expect_match(pt, "Population: adults")
  expect_match(pt, "Intervention: drug")
  expect_match(pt, "Comparison: placebo")
  expect_match(pt, "Outcome: OS")
  expect_match(pt, "Must contain: trial")
  expect_match(pt, "Must NOT contain: rodent")
  expect_match(pt, "\\{\\{title\\}\\}")
})

test_that("prompt template includes design for PICOS", {
  q <- sm_question(text = "q", framework = "PICOS",
                   population = "p", intervention = "i", design = "RCT")
  expect_match(q$prompt_template, "Study design: RCT")
})

test_that("is_sm_question rejects non-questions", {
  expect_false(is_sm_question(list()))
  expect_false(is_sm_question("a string"))
  expect_false(is_sm_question(NULL))
})

# Tests for R/fetch-openalex.R parsers (offline; no request is sent).

test_that("OpenAlex concepts are parsed into the openalex vocabulary", {
  results <- list(
    list(concepts = list(
      list(id = "https://openalex.org/C1", display_name = "Biology",
           level = 0L, score = 0.9),
      list(id = "https://openalex.org/C2", display_name = "Genetics",
           level = 1L, score = 0.4)
    )),
    list(concepts = list())
  )
  concepts <- .parse_openalex_concepts(results, c("W1", "W2"))
  expect_identical(concepts$work_id, c("W1", "W1"))
  expect_identical(concepts$concept_name, c("Biology", "Genetics"))
  expect_identical(concepts$vocabulary, c("openalex", "openalex"))
  expect_true(all(concepts$vocabulary %in% sm_concept_vocabularies()))
  expect_identical(.parse_openalex_concepts(list(), character()),
                   .empty_concepts())
})

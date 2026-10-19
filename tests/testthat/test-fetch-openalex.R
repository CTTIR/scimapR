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

test_that("the OpenAlex fetcher reads the corresponding author", {
  # The same saved works as for sm_read_openalex_json(): the second author
  # of W1 is corresponding, W2 and W3 do not tell (NA), W4 lists its
  # corresponding author in corresponding_author_ids.
  results <- jsonlite::fromJSON(test_path("fixtures",
                                          "openalex-corresponding.json"),
                                simplifyVector = FALSE)
  a <- .parse_openalex_authorships(results, paste0("W", 1:4))$authorships
  flags <- split(a$is_corresponding, a$work_id)
  expect_identical(unname(flags), list(c(FALSE, TRUE, FALSE), c(NA, NA),
                                       c(NA, NA), c(FALSE, TRUE)))
  expect_identical(a$position, c(1:3, 1:2, 1:2, 1:2))
})

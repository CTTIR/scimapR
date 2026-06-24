# cli writes to the message connection (stderr); capture with type = "message".
cap_print <- function(x) {
  paste(capture.output(print(x), type = "message"), collapse = "\n")
}

test_that("print.sm_audit_geographic prints and returns invisibly", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 1)
  res <- sm_audit_geographic(corpus)
  ret <- withVisible(print(res))
  expect_false(ret$visible)
  expect_identical(ret$value, res)
  txt <- cap_print(res)
  expect_match(txt, "sm_audit_geographic")
  expect_match(txt, "Limitations")
  expect_match(txt, "Distribution")
})

test_that("print.sm_audit_geographic handles empty distribution", {
  res <- sm_audit_geographic(make_empty_corpus())
  expect_match(cap_print(res), "No geographic data")
})

test_that("print.sm_audit_geographic shows truncation for >10 groups", {
  corpus <- sm_example_corpus(n_works = 120, n_authors = 60,
                              with_embeddings = FALSE, seed = 2)
  res <- sm_audit_geographic(corpus)
  skip_if(nrow(res$distribution) <= 10L,
          "Not enough distinct groups to trigger truncation")
  expect_match(cap_print(res), "more")
})

test_that("print.sm_audit_gender prints distribution, position, limitations", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 15,
                              with_embeddings = FALSE, seed = 3)
  corpus$authors$inferred_gender <- rep(c("female", "male"),
                                        length.out = nrow(corpus$authors))
  corpus$authors$gender_confidence <- 0.8
  res <- sm_audit_gender(corpus, method = "manual")
  ret <- withVisible(print(res))
  expect_false(ret$visible)
  txt <- cap_print(res)
  expect_match(txt, "sm_audit_gender")
  expect_match(txt, "authorship position")
  expect_match(txt, "Confidence scores")
  expect_match(txt, "Limitations")
})

test_that("print.sm_audit_funding prints with no funders", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, call) {
      tibble::tibble(work_id = character(), funder_name = character(),
                     funder_doi = character())
    }
  )
  empty_res <- suppressMessages(sm_audit_funding(corpus, source = "crossref"))
  txt <- cap_print(empty_res)
  expect_match(txt, "sm_audit_funding")
  expect_match(txt, "No funding data found")
  expect_match(txt, "Limitations")
})

test_that("print.sm_audit_funding shows top funders and truncation", {
  funders <- tibble::tibble(
    funder_name = paste0("Funder", 1:12),
    funder_doi = paste0("10.x/", 1:12),
    n_works = 12:1,
    pct = round(100 * (12:1) / 50, 2)
  )
  res <- structure(
    list(funders = funders, coverage = 0.5, n_works_total = 50L,
         n_works_funded = 25L, source = "crossref"),
    class = "sm_audit_funding"
  )
  txt <- cap_print(res)
  expect_match(txt, "Top funders")
  expect_match(txt, "Funder1")
  expect_match(txt, "and 2 more")
})

test_that("print.sm_audit_oa prints distribution and limitations", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = FALSE, seed = 5)
  res <- sm_audit_oa(corpus)
  ret <- withVisible(print(res))
  expect_false(ret$visible)
  txt <- cap_print(res)
  expect_match(txt, "sm_audit_oa")
  expect_match(txt, "Open access")
  expect_match(txt, "OA status distribution")
  expect_match(txt, "Limitations")
})

test_that("print.sm_audit_summary prints overview and limitations", {
  corpus <- sm_example_corpus(n_works = 25, n_authors = 12,
                              with_embeddings = FALSE, seed = 6)
  testthat::local_mocked_bindings(
    .fetch_funding_crossref = function(works, call) {
      tibble::tibble(work_id = character(), funder_name = character(),
                     funder_doi = character())
    }
  )
  res <- suppressMessages(sm_audit_summary(corpus))
  ret <- withVisible(print(res))
  expect_false(ret$visible)
  txt <- cap_print(res)
  expect_match(txt, "sm_audit_summary")
  expect_match(txt, "Overview")
  expect_match(txt, "geographic")
  expect_match(txt, "Limitations")
})

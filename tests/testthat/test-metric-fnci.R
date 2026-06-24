# Tests for R/metric-fnci.R (sm_metric_fnci and .assign_field).

test_that("sm_metric_fnci rejects a non-corpus input", {
  expect_error(sm_metric_fnci(list()), class = "rlang_error")
})

test_that("sm_metric_fnci validates the classification argument", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_metric_fnci(corpus, classification = "scopus"),
    class = "rlang_error"
  )
})

test_that("sm_metric_fnci returns an empty tibble for an empty corpus", {
  corpus <- sm_example_corpus(n_works = 0, n_authors = 2,
                              with_embeddings = FALSE, seed = 2)
  out <- sm_metric_fnci(corpus)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("work_id", "field", "year", "cited_by_count",
                      "field_mean", "fnci"))
})

test_that("openalex_concepts classification yields numeric FNCI values", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 12,
                              with_embeddings = FALSE, seed = 3)
  out <- sm_metric_fnci(corpus, classification = "openalex_concepts")
  expect_equal(nrow(out), nrow(corpus$works))
  expect_true(all(corpus$works$work_id %in% out$work_id))
  expect_true(is.numeric(out$fnci))
  expect_true(is.numeric(out$field_mean))
  # At least some finite FNCI values are produced.
  expect_true(any(is.finite(out$fnci)))
  # cited_by_count is carried through correctly.
  expect_equal(
    out$cited_by_count[match(corpus$works$work_id, out$work_id)],
    corpus$works$cited_by_count
  )
})

test_that("FNCI is computed as cited_by_count / field-year mean", {
  # Build a tiny controlled corpus: a single field, single year, known counts.
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  corpus$works$year <- 2020L
  corpus$works$cited_by_count <- c(0L, 10L, 20L, 10L)  # mean = 10
  corpus$works$field <- "F"

  out <- sm_metric_fnci(corpus, classification = "manual")
  ord <- match(corpus$works$work_id, out$work_id)
  expect_equal(out$field_mean[ord], rep(10, 4))
  expect_equal(out$fnci[ord], c(0, 1, 2, 1))
})

test_that("manual classification errors when no field column exists", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 5)
  expect_false("field" %in% names(corpus$works))
  expect_error(
    sm_metric_fnci(corpus, classification = "manual"),
    "field"
  )
})

test_that("openalex_concepts with empty concepts gives unclassified field", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 6)
  corpus$concepts <- corpus$concepts[0, ]
  out <- sm_metric_fnci(corpus, classification = "openalex_concepts")
  expect_true(all(out$field == "unclassified"))
})

test_that("mesh classification falls back to unclassified without MeSH terms", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 7)
  # Synthetic concepts use vocabulary "openalex", not mesh/medline.
  expect_message(
    out <- sm_metric_fnci(corpus, classification = "mesh"),
    "No MeSH terms"
  )
  expect_true(all(out$field == "unclassified"))
})

test_that("mesh classification uses MeSH concepts when present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 8)
  corpus$concepts <- tibble::tibble(
    work_id = corpus$works$work_id,
    concept_id = "M1",
    concept_name = "Neoplasms",
    level = 1L,
    score = 0.9,
    vocabulary = "mesh"
  )
  out <- sm_metric_fnci(corpus, classification = "mesh")
  expect_true(all(out$field == "Neoplasms"))
})

test_that("mesh classification with empty concepts gives unclassified field", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 9)
  corpus$concepts <- corpus$concepts[0, ]
  out <- sm_metric_fnci(corpus, classification = "mesh")
  expect_true(all(out$field == "unclassified"))
})

test_that("FNCI is NA when the field-year mean is zero", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 10)
  corpus$works$year <- 2021L
  corpus$works$cited_by_count <- c(0L, 0L, 0L)  # mean = 0
  corpus$works$field <- "Z"
  out <- sm_metric_fnci(corpus, classification = "manual")
  expect_true(all(is.na(out$fnci)))
})

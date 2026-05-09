test_that("sm_validate returns 0-row tibble for a clean corpus", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)
  issues <- sm_validate(corpus)

  expect_s3_class(issues, "tbl_df")
  expect_equal(nrow(issues), 0L)
  expect_named(issues, c("table", "issue", "n_affected"))
})

test_that("sm_validate detects orphan authorships", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 1)
  # Add an authorship pointing to a non-existent work
  orphan <- tibble::tibble(
    work_id = "W_ORPHAN_01",
    author_id = corpus$authors$author_id[1],
    position = 1L,
    is_corresponding = TRUE,
    institution_id = NA_character_,
    raw_affiliation = NA_character_,
    country_code = NA_character_
  )
  corpus$authorships <- dplyr::bind_rows(corpus$authorships, orphan)

  issues <- sm_validate(corpus)

  expect_gt(nrow(issues), 0L)
  expect_true(any(issues$table == "authorships"))
})

test_that("sm_validate detects duplicate work_ids", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  # Duplicate a work_id
  corpus$works <- dplyr::bind_rows(corpus$works, corpus$works[1, ])

  issues <- sm_validate(corpus)

  expect_gt(nrow(issues), 0L)
  expect_true(any(issues$issue == "duplicate work_id"))
})

test_that("sm_validate detects orphan references", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 1)
  # Add a reference from a non-existent work
  orphan_ref <- tibble::tibble(
    work_id = "W_ORPHAN_02",
    ref_index = 1L,
    cited_work_id = corpus$works$work_id[1],
    cited_doi = corpus$works$doi[1],
    cited_raw = "Orphan reference"
  )
  corpus$references <- dplyr::bind_rows(corpus$references, orphan_ref)

  issues <- sm_validate(corpus)

  expect_gt(nrow(issues), 0L)
  expect_true(any(issues$table == "references"))
})

test_that("sm_validate rejects non-corpus input", {
  expect_error(sm_validate("not_a_corpus"), "sm_corpus")
})

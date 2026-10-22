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

test_that("sm_validate detects yearly counts of works not in works", {
  works <- tibble::tibble(work_id = c("W1", "W2"), title = "x", year = 2020L)
  corpus <- sm_corpus(works, citations_by_year = tibble::tibble(
    work_id = c("W1", "W9", "W9"), year = c(2021L, 2021L, 2022L),
    cited_by_count = 1L
  ))
  issues <- sm_validate(corpus)
  expect_identical(issues$table, "citations_by_year")
  expect_identical(issues$n_affected, 1L)
  expect_identical(nrow(sm_validate(corpus[1:2])), 0L)
})

for (spec in list(
  c("authorships", "author_id", "authors"),
  c("authorships", "institution_id", "institutions"),
  c("works", "source_id", "sources")
)) {
  local({
    target <- spec
    test_that(paste("sm_validate checks", target[1], target[2]), {
      x <- sm_example_corpus(n_works = 10, n_authors = 5, seed = 1)
      x[[target[1]]][[target[2]]][1:2] <- "missing"
      issue <- sm_validate(x)
      expect_identical(issue$table, target[1])
      expect_identical(issue$issue, paste(target[2], "not in", target[3]))
      expect_identical(issue$n_affected, 1L)
    })
  })
}

for (spec in list(c("authors", "author_id"), c("sources", "source_id"),
                  c("institutions", "institution_id"))) {
  local({
    target <- spec
    test_that(paste("sm_validate counts duplicate", target[2]), {
      x <- sm_example_corpus(n_works = 10, n_authors = 5, seed = 1)
      if (nrow(x[[target[1]]]) == 0L) {
        x[[target[1]]] <- tibble::as_tibble(
          stats::setNames(list("I1"), target[2])
        )
      }
      x[[target[1]]] <- dplyr::bind_rows(x[[target[1]]], x[[target[1]]][1, ],
                                         x[[target[1]]][1, ])
      issue <- sm_validate(x)
      expect_identical(issue$table, target[1])
      expect_identical(issue$issue, paste("duplicate", target[2]))
      expect_identical(issue$n_affected, 2L)
    })
  })
}

test_that("sm_validate checks embedding identity", {
  x <- sm_example_corpus(n_works = 10, n_authors = 5, seed = 1)
  rownames(x$embeddings)[1:2] <- "missing"
  issues <- sm_validate(x)
  expect_identical(issues$table, rep("embeddings", 2L))
  expect_identical(issues$issue,
                   c("duplicate row name", "row name not in works"))
  expect_identical(issues$n_affected, c(1L, 1L))
})

test_that("validation reports a changed lock hash", {
  x <- suppressMessages(sm_lock(sm_example_corpus(n_works = 10, seed = 1)))
  expect_equal(nrow(sm_validate(x)), 0L)
  x$works$title[1] <- "Changed title"
  issue <- sm_validate(x)
  expect_identical(issue$table, "metadata")
  expect_identical(issue$issue, "content changed since sm_lock()")
  expect_identical(issue$n_affected, 1L)
  x$metadata$lock_hash <- NULL
  expect_equal(nrow(sm_validate(x)), 0L)
})

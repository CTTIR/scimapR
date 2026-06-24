# Tests for R/diff.R (sm_diff_corpora) -- pure logic, no network.

test_that("sm_diff_corpora rejects non-corpus inputs", {
  c1 <- sm_example_corpus(n_works = 5, n_authors = 3,
                          with_embeddings = FALSE, seed = 1)
  expect_error(sm_diff_corpora(list(), c1), class = "rlang_error")
  expect_error(sm_diff_corpora(c1, list()), class = "rlang_error")
})

test_that("identical corpora produce an all-zero diff", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 8,
                          with_embeddings = FALSE, seed = 7)
  d <- sm_diff_corpora(c1, c1)

  expect_s3_class(d, "sm_corpus_diff")
  expect_equal(d$summary$works_added, 0L)
  expect_equal(d$summary$works_removed, 0L)
  expect_equal(d$summary$works_changed, 0L)
  expect_equal(d$summary$works_unchanged, nrow(c1$works))
  expect_equal(nrow(d$added), 0L)
  expect_equal(nrow(d$removed), 0L)
  expect_equal(nrow(d$changed), 0L)
})

test_that("added and removed works are detected by work_id", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 8,
                          with_embeddings = FALSE, seed = 1)
  c2 <- c1
  # Drop the first 3 works from c2 (these become "removed")
  removed_ids <- c1$works$work_id[1:3]
  c2$works <- c2$works[-(1:3), ]
  # Add 2 brand-new works to c2 (these become "added")
  new_rows <- c1$works[1:2, ]
  new_rows$work_id <- c("WNEW00001", "WNEW00002")
  c2$works <- dplyr::bind_rows(c2$works, new_rows)

  d <- sm_diff_corpora(c1, c2)

  expect_equal(d$summary$works_removed, 3L)
  expect_equal(d$summary$works_added, 2L)
  expect_setequal(d$removed$work_id, removed_ids)
  expect_setequal(d$added$work_id, c("WNEW00001", "WNEW00002"))
})

test_that("field-level changes are reported with before/after values", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 3)
  c2 <- c1
  target_id <- c1$works$work_id[1]
  c2$works$cited_by_count[1] <- c1$works$cited_by_count[1] + 999L
  c2$works$title[2] <- "A Completely Different Title"

  d <- sm_diff_corpora(c1, c2)

  expect_gte(nrow(d$changed), 2L)
  expect_true(all(c("work_id", "field", "value_before", "value_after") %in%
                    names(d$changed)))
  cited_change <- d$changed[d$changed$work_id == target_id &
                              d$changed$field == "cited_by_count", ]
  expect_equal(nrow(cited_change), 1L)
  expect_equal(cited_change$value_after,
               as.character(c1$works$cited_by_count[1] + 999L))
})

test_that("last_refreshed differences are ignored as changes", {
  c1 <- sm_example_corpus(n_works = 8, n_authors = 4,
                          with_embeddings = FALSE, seed = 5)
  c2 <- c1
  c2$works$last_refreshed <- c1$works$last_refreshed + 100000
  d <- sm_diff_corpora(c1, c2)
  expect_equal(d$summary$works_changed, 0L)
})

test_that("NA-to-value transitions are detected as changes", {
  c1 <- sm_example_corpus(n_works = 6, n_authors = 3,
                          with_embeddings = FALSE, seed = 2)
  c2 <- c1
  c1$works$language[1] <- NA_character_
  c2$works$language[1] <- "fr"
  d <- sm_diff_corpora(c1, c2)
  lang_change <- d$changed[d$changed$field == "language", ]
  expect_true(nrow(lang_change) >= 1L)
  expect_true(is.na(lang_change$value_before[1]))
  expect_equal(lang_change$value_after[1], "fr")
})

test_that("author and reference counts are summarised", {
  c1 <- sm_example_corpus(n_works = 15, n_authors = 10,
                          with_embeddings = FALSE, seed = 11)
  c2 <- c1
  c2$authors <- c2$authors[-1, ]
  d <- sm_diff_corpora(c1, c2)
  expect_equal(d$summary$authors_removed, 1L)
  expect_equal(d$summary$authors_added, 0L)
  expect_equal(d$summary$refs_before, nrow(c1$references))
  expect_equal(d$summary$refs_after, nrow(c2$references))
})

test_that("print.sm_corpus_diff returns the object invisibly and prints", {
  c1 <- sm_example_corpus(n_works = 6, n_authors = 3,
                          with_embeddings = FALSE, seed = 4)
  d <- sm_diff_corpora(c1, c1)
  out <- withr::with_options(
    list(cli.default_handler = function(msg) invisible(NULL)),
    expect_invisible(print(d))
  )
  expect_identical(out, d)
  expect_s3_class(d, "sm_corpus_diff")
})

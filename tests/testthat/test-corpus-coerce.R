test_that("as_sm_corpus.data.frame converts a data frame to corpus", {
  df <- data.frame(
    title = c("Work A", "Work B"),
    doi = c("10.1234/a", "10.1234/b"),
    year = c(2022L, 2023L),
    stringsAsFactors = FALSE
  )
  corpus <- as_sm_corpus(df)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)
  expect_true("work_id" %in% names(corpus$works))
  expect_true(all(c("title", "doi", "year") %in% names(corpus$works)))
})

test_that("as_sm_corpus.sm_corpus returns input unchanged", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  result <- as_sm_corpus(corpus)

  expect_identical(result, corpus)
})

test_that("as_sm_corpus.list converts a named list with works", {
  lst <- list(
    works = tibble::tibble(
      work_id = "W000000001",
      doi = "10.1234/x",
      title = "List Work",
      abstract = NA_character_,
      year = 2024L,
      type = "journal-article",
      source_id = NA_character_,
      cited_by_count = 5L,
      oa_status = "gold",
      language = "en",
      pmid = NA_character_,
      arxiv_id = NA_character_,
      openalex_id = NA_character_,
      is_retracted = FALSE,
      retraction_date = as.Date(NA),
      last_refreshed = Sys.time()
    )
  )
  corpus <- as_sm_corpus(lst)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
})

test_that("as_sm_corpus.list errors without works element", {
  lst <- list(authors = tibble::tibble(author_id = "A1"))
  expect_error(as_sm_corpus(lst), "works")
})

test_that("as_tibble.sm_corpus returns the works tibble", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  tbl <- tibble::as_tibble(corpus)

  expect_s3_class(tbl, "tbl_df")
  expect_equal(nrow(tbl), 10L)
  expect_true("work_id" %in% names(tbl))
})

test_that("as.data.frame.sm_corpus returns a data.frame", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  df <- as.data.frame(corpus)

  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 10L)
  expect_true("work_id" %in% names(df))
})

test_that("sm_corpus constructs a valid corpus from a works tibble", {
  works <- tibble::tibble(
    work_id = "W000000001",
    doi = "10.1234/test",
    title = "Test Work",
    abstract = "An abstract.",
    year = 2024L,
    type = "journal-article",
    source_id = NA_character_,
    cited_by_count = 0L,
    oa_status = "closed",
    language = "en",
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
  corpus <- sm_corpus(works = works)

  expect_s3_class(corpus, "sm_corpus")
  expect_true(is_sm_corpus(corpus))
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$work_id, "W000000001")
})

test_that("sm_corpus fills missing columns automatically", {
  works <- tibble::tibble(
    title = "Minimal Work",
    doi = "10.1234/minimal"
  )

  corpus <- sm_corpus(works = works)

  expect_true("work_id" %in% names(corpus$works))
  expect_true("year" %in% names(corpus$works))
  expect_true("cited_by_count" %in% names(corpus$works))
  expect_true("is_retracted" %in% names(corpus$works))
})

test_that("validate_sm_corpus rejects non-corpus objects", {
  expect_error(validate_sm_corpus("not a corpus"), "sm_corpus")
})

test_that("validate_sm_corpus rejects corpus missing required components", {
  fake <- structure(list(works = tibble::tibble(work_id = "W1")),
                    class = "sm_corpus")
  expect_error(validate_sm_corpus(fake), "Missing required components")
})

test_that("validate_sm_corpus rejects corpus where works is not a tibble", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$works <- as.list(corpus$works)
  expect_error(validate_sm_corpus(corpus), "tibble")
})

test_that("validate_sm_corpus rejects corpus missing work_id", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$works$work_id <- NULL
  expect_error(validate_sm_corpus(corpus), "work_id")
})

test_that("is_sm_corpus returns FALSE for non-corpus", {
  expect_false(is_sm_corpus("not a corpus"))
  expect_false(is_sm_corpus(42))
  expect_false(is_sm_corpus(NULL))
  expect_false(is_sm_corpus(data.frame()))
})

test_that("subsetting with [ returns a valid sm_corpus", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 1)
  sub <- corpus[1:5]

  expect_s3_class(sub, "sm_corpus")
  expect_equal(nrow(sub$works), 5L)
  # authorships should only reference kept work_ids
  expect_true(all(sub$authorships$work_id %in% sub$works$work_id))
})

test_that("length.sm_corpus returns number of works", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  expect_equal(length(corpus), 15L)
})

test_that("dim.sm_corpus returns works dimensions", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  d <- dim(corpus)

  expect_length(d, 2L)
  expect_equal(d[1], 10L)
  expect_equal(d[2], ncol(corpus$works))
})

test_that("empty corpus has correct columns (type stability)", {
  works <- tibble::tibble(
    work_id = character(),
    doi = character(),
    title = character(),
    abstract = character(),
    year = integer(),
    type = character(),
    source_id = character(),
    cited_by_count = integer(),
    oa_status = character(),
    language = character(),
    pmid = character(),
    arxiv_id = character(),
    openalex_id = character(),
    is_retracted = logical(),
    retraction_date = as.Date(character()),
    last_refreshed = as.POSIXct(character())
  )
  corpus <- sm_corpus(works = works)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(length(corpus), 0L)
  expect_equal(nrow(corpus$authors), 0L)
  expect_equal(nrow(corpus$authorships), 0L)
  expect_true(all(c("work_id", "doi", "title", "year") %in%
                    names(corpus$works)))
})

test_that("subsetting with embeddings preserves matrix", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = TRUE, seed = 1)
  sub <- corpus[1:5]
  kept_ids <- sub$works$work_id

  if (!is.null(sub$embeddings)) {
    expect_true(all(rownames(sub$embeddings) %in% kept_ids))
  }
})

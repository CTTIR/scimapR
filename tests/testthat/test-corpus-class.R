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

# ---- concept vocabularies at corpus entry -----------------------------------

vocab_concepts <- function(vocabulary) {
  tibble::tibble(
    work_id = rep_len(c("W1", "W2"), length(vocabulary)),
    concept_id = NA_character_,
    concept_name = paste("term", seq_along(vocabulary)),
    level = NA_integer_,
    score = NA_real_,
    vocabulary = vocabulary
  )
}

collect_messages <- function(expr) {
  msgs <- list()
  value <- withCallingHandlers(expr, message = function(m) {
    msgs[[length(msgs) + 1L]] <<- m
    invokeRestart("muffleMessage")
  })
  list(value = value, messages = msgs)
}

test_that("sm_corpus renames legacy concept vocabularies with one message", {
  works <- tibble::tibble(work_id = c("W1", "W2"), title = c("a", "b"))
  concepts <- vocab_concepts(c("keywords-author", "keywords-author",
                               "openalex", "MEDLINE"))
  res <- collect_messages(sm_corpus(works, concepts = concepts))
  expect_length(res$messages, 1L)
  expect_s3_class(res$messages[[1]], "scimapR_concept_vocab_renamed")
  expect_false(inherits(res$messages[[1]], "scimapR_concept_vocab_unknown"))
  expect_match(conditionMessage(res$messages[[1]]), "keywords-author")
  expect_identical(res$value$concepts$vocabulary,
                   c("author-keywords", "author-keywords", "openalex",
                     "mesh"))
  expect_message(sm_corpus(works, concepts = concepts),
                 class = "scimapR_concept_vocab_renamed")
})

test_that("sm_corpus is silent for canonical vocabularies", {
  works <- tibble::tibble(work_id = c("W1", "W2"), title = c("a", "b"))
  concepts <- vocab_concepts(c("author-keywords", "wos-category", NA))
  expect_silent(corpus <- sm_corpus(works, concepts = concepts))
  expect_identical(corpus$concepts$vocabulary,
                   c("author-keywords", "wos-category", NA))
})

test_that("sm_corpus keeps unknown vocabularies and names them once", {
  works <- tibble::tibble(work_id = c("W1", "W2"), title = c("a", "b"))
  concepts <- vocab_concepts(c("my tags", "my tags", "other", "keyword"))
  res <- collect_messages(sm_corpus(works, concepts = concepts))
  expect_length(res$messages, 1L)
  msg <- res$messages[[1]]
  expect_s3_class(msg, "scimapR_concept_vocab_unknown")
  expect_s3_class(msg, "scimapR_concept_vocab_renamed")
  expect_match(conditionMessage(msg), "my tags")
  expect_match(conditionMessage(msg), "other")
  expect_identical(res$value$concepts$vocabulary,
                   c("my tags", "my tags", "other", "author-keywords"))
})

test_that("sm_corpus stores a factor vocabulary as character", {
  works <- tibble::tibble(work_id = c("W1", "W2"), title = c("a", "b"))
  concepts <- vocab_concepts(factor(c("mesh", "openalex")))
  expect_silent(corpus <- sm_corpus(works, concepts = concepts))
  expect_identical(corpus$concepts$vocabulary, c("mesh", "openalex"))
})

test_that("the low-level constructor used by readers does not rename", {
  works <- tibble::tibble(work_id = "W1", title = "a")
  concepts <- vocab_concepts("keywords-author")
  expect_silent(
    corpus <- new_sm_corpus(works = works, authors = .empty_authors(),
                            authorships = .empty_authorships(),
                            concepts = concepts)
  )
  expect_identical(corpus$concepts$vocabulary, "keywords-author")
})

# ---- citations_by_year: the optional yearly citation counts ----------------

yearly_counts <- function(work_id = c("W1", "W1", "W2"),
                          year = c(2021L, 2022L, 2023L),
                          cited_by_count = c(2L, 3L, 1L)) {
  tibble::tibble(work_id = work_id, year = year,
                 cited_by_count = cited_by_count)
}

test_that("sm_corpus carries citations_by_year and validates it", {
  works <- tibble::tibble(work_id = c("W1", "W2", "W3"), title = "x",
                          year = 2020L)
  corpus <- sm_corpus(works, citations_by_year = yearly_counts())
  expect_identical(corpus$citations_by_year, yearly_counts())
  # whole numbers are stored as integers
  doubles <- yearly_counts(year = c(2021, 2022, 2023),
                           cited_by_count = c(2, 3, 1))
  expect_identical(sm_corpus(works, citations_by_year = doubles)$
                     citations_by_year, yearly_counts())
  # without it the corpus has no such element, as before
  plain <- sm_corpus(works)
  expect_false("citations_by_year" %in% names(plain))
  expect_null(plain$citations_by_year)
  expect_no_error(validate_sm_corpus(plain))

  expect_error(sm_corpus(works, citations_by_year = yearly_counts()[-3]),
               "cited_by_count")
  expect_error(
    sm_corpus(works, citations_by_year = yearly_counts(year = c(2021.5, 1, 2))),
    "wrong type"
  )
  expect_error(
    sm_corpus(works, citations_by_year = yearly_counts(year = c(NA, 1L, 2L))),
    "without a"
  )
  negative <- yearly_counts(cited_by_count = c(-1L, 1L, 1L))
  expect_error(sm_corpus(works, citations_by_year = negative), "0 or more")
  twice <- yearly_counts(year = c(2021L, 2021L, 2023L))
  expect_error(sm_corpus(works, citations_by_year = twice),
               "more than one row")
  expect_error(sm_corpus(works, citations_by_year = "2021"),
               "data frame")
})

test_that("subsetting keeps the yearly counts of the kept works only", {
  fix <- realuse_corpus()
  sub <- fix[1:10]
  expect_true(all(sub$citations_by_year$work_id %in% sub$works$work_id))
  expect_identical(
    sub$citations_by_year,
    fix$citations_by_year[fix$citations_by_year$work_id %in%
                            fix$works$work_id[1:10], ]
  )
  expect_gt(nrow(sub$citations_by_year), 0L)
  works <- tibble::tibble(work_id = c("W1", "W2"), title = "x")
  expect_false("citations_by_year" %in% names(sm_corpus(works)[1]))
})

test_that("as_sm_corpus() rebuilds a corpus with yearly counts from a list", {
  works <- tibble::tibble(work_id = c("W1", "W2"), title = "x", year = 2020L)
  corpus <- sm_corpus(works, citations_by_year = yearly_counts())
  back <- as_sm_corpus(unclass(corpus))
  expect_identical(back$citations_by_year, corpus$citations_by_year)
})

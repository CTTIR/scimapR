test_that("sm_build_corpus combines two corpora", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 1)
  c2 <- sm_example_corpus(n_works = 15, n_authors = 8,
                          with_embeddings = FALSE, seed = 2)

  combined <- sm_build_corpus(c1, c2, dedupe = FALSE, verbose = FALSE)

  expect_s3_class(combined, "sm_corpus")
  expect_equal(nrow(combined$works), 35L)
})

test_that("sm_build_corpus deduplicates by DOI when dedupe = TRUE", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 1)
  # Create a second corpus with overlapping DOIs
  c2 <- c1[1:5]

  combined <- sm_build_corpus(c1, c2, dedupe = TRUE, verbose = FALSE)

  expect_s3_class(combined, "sm_corpus")
  # Should not have more than the original 20
  expect_lte(nrow(combined$works), 25L)
})

test_that("sm_bind_corpora row-binds two corpora", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 2)

  bound <- sm_bind_corpora(c1, c2)

  expect_s3_class(bound, "sm_corpus")
  expect_equal(nrow(bound$works), 20L)
})

test_that("sm_bind_corpora merges embeddings if dimensions match", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 2)

  bound <- sm_bind_corpora(c1, c2)
  expect_true(!is.null(bound$embeddings))
  expect_equal(nrow(bound$embeddings), 20L)
})

test_that("sm_bind_corpora drops embeddings if dimensions differ", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 2)

  bound <- sm_bind_corpora(c1, c2)
  expect_null(bound$embeddings)
})

test_that("sm_bind_corpora rejects non-corpus input", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_bind_corpora(corpus, "not_a_corpus"), "sm_corpus")
  expect_error(sm_bind_corpora("not_a_corpus", corpus), "sm_corpus")
})

test_that("sm_dedupe removes duplicate DOIs", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 1)
  # Manually duplicate some works
  dup_works <- corpus$works[1:3, ]
  dup_works$work_id <- paste0("W99999000", 1:3)
  corpus$works <- dplyr::bind_rows(corpus$works, dup_works)

  deduped <- sm_dedupe(corpus, verbose = FALSE)

  expect_s3_class(deduped, "sm_corpus")
  expect_lte(nrow(deduped$works), nrow(corpus$works))
  # No duplicate DOIs among non-NA DOIs
  doi_present <- deduped$works$doi[!is.na(deduped$works$doi)]
  expect_false(any(duplicated(doi_present)))
})

test_that("sm_dedupe preserves works with NA DOI", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  # Set some DOIs to NA

  corpus$works$doi[1:3] <- NA_character_

  deduped <- sm_dedupe(corpus, verbose = FALSE)
  na_count <- sum(is.na(deduped$works$doi))
  expect_gte(na_count, 3L)
})

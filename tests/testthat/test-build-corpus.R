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

test_that("binding and deduplicating keep the yearly citation counts", {
  yearly <- function(ids) {
    tibble::tibble(work_id = ids, year = 2022L, cited_by_count = 1L)
  }
  works <- function(ids, dois) tibble::tibble(work_id = ids, doi = dois)
  c1 <- sm_corpus(works(c("W1", "W2"), c("10.9999/a", "10.9999/b")),
                  citations_by_year = yearly(c("W1", "W2")))
  c2 <- sm_corpus(works(c("W3", "W4"), c("10.9999/c", "10.9999/a")),
                  citations_by_year = yearly(c("W3", "W4")))
  plain <- sm_corpus(tibble::tibble(work_id = "W5", doi = "10.9999/e"))

  bound <- sm_bind_corpora(c1, c2)
  expect_identical(bound$citations_by_year$work_id, c("W1", "W2", "W3", "W4"))
  expect_identical(sm_bind_corpora(plain, c2)$citations_by_year$work_id,
                   c("W3", "W4"))
  expect_false("citations_by_year" %in% names(sm_bind_corpora(plain, plain)))
  # a work in both corpora keeps one row per year
  expect_identical(nrow(sm_bind_corpora(c1, c1)$citations_by_year), 2L)

  deduped <- sm_dedupe(bound, verbose = FALSE)
  expect_identical(sort(deduped$citations_by_year$work_id),
                   sort(deduped$works$work_id))
  expect_identical(nrow(deduped$citations_by_year), 3L)
})

test_that("sm_bind_corpora binds embeddings of one recorded model", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 2)
  record <- function(id, corpus) {
    .new_embedding_record(id, id, "sentence-transformers",
                          n_works = nrow(corpus$embeddings),
                          n_dimensions = ncol(corpus$embeddings))
  }
  c1$metadata$embedding <- record("mpnet", c1)
  c2$metadata$embedding <- record("mpnet", c2)
  bound <- sm_bind_corpora(c1, c2)
  expect_identical(nrow(bound$embeddings), 20L)
  expect_identical(bound$metadata$embedding$model_id, "mpnet")
  expect_identical(bound$metadata$embedding$n_works, 20L)

  # two models, or a recorded and an unrecorded one, are not bound
  c2$metadata$embedding <- record("scincl", c2)
  expect_error(sm_bind_corpora(c1, c2), "mix_models = TRUE",
               class = "scimapR_embedding_model_mismatch")
  plain <- c2
  plain$metadata$embedding <- NULL
  expect_error(sm_bind_corpora(c1, plain), "not recorded",
               class = "scimapR_embedding_model_mismatch")

  # unless asked: the bound rows are a recorded mix
  mixed <- sm_bind_corpora(c1, c2, mix_models = TRUE)
  expect_identical(nrow(mixed$embeddings), 20L)
  expect_identical(mixed$metadata$embedding$model_id, "mixed")
  expect_identical(mixed$metadata$embedding$models, c("mpnet", "scincl"))
  expect_error(sm_bind_corpora(c1, c2, mix_models = NA), "TRUE")
})

test_that("sm_bind_corpora keeps no record for embeddings it drops", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 2)
  c1$metadata$embedding <- .new_embedding_record(
    "mpnet", "mpnet", "sentence-transformers",
    n_works = 10, n_dimensions = ncol(c1$embeddings)
  )
  bound <- sm_bind_corpora(c1, c2)
  expect_null(bound$embeddings)
  expect_null(bound$metadata$embedding)
})

test_that("sm_build_corpus passes mix_models on to sm_bind_corpora", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 2)
  c1$metadata$embedding <- .new_embedding_record(
    "mpnet", "mpnet", "sentence-transformers",
    n_works = nrow(c1$embeddings), n_dimensions = ncol(c1$embeddings)
  )

  # a recorded and an unrecorded model stop the build, and the hint names
  # an argument that sm_build_corpus() has
  expect_error(sm_build_corpus(c1, c2, dedupe = FALSE, verbose = FALSE),
               "mix_models = TRUE",
               class = "scimapR_embedding_model_mismatch")
  built <- sm_build_corpus(c1, c2, dedupe = FALSE, mix_models = TRUE,
                           verbose = FALSE)
  expect_identical(nrow(built$embeddings), 20L)
  expect_identical(built$metadata$embedding$model_id, "mixed")
  expect_identical(built$metadata$embedding$models, c("mpnet", "unknown"))
  expect_error(sm_build_corpus(c1, c2, mix_models = NA, verbose = FALSE),
               "mix_models")
})

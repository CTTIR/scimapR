# Tests for R/field-pubmed-mesh.R (sm_field_pubmed_mesh).

test_that("sm_field_pubmed_mesh counts the MeSH headings of the corpus", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  ids <- corpus$works$work_id
  corpus$concepts <- tibble::tibble(
    work_id = c(ids, ids[1:2], ids[1]),
    concept_id = NA_character_,
    concept_name = c(rep("Humans", 4), "Neoplasms", "Neoplasms", "Biology"),
    level = NA_integer_,
    score = NA_real_,
    vocabulary = c(rep("mesh", 6), "openalex")
  )
  out <- sm_field_pubmed_mesh(corpus)
  expect_named(out, c("mesh_term", "count", "proportion"))
  expect_identical(out$mesh_term, c("Humans", "Neoplasms"))
  expect_identical(out$count, c(4L, 2L))
  expect_equal(out$proportion, c(1, 0.5))
})

test_that("sm_field_pubmed_mesh finds MeSH headings under other spellings", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  # Direct assignment bypasses sm_corpus(), so the spelling stays as written.
  corpus$concepts <- tibble::tibble(
    work_id = corpus$works$work_id,
    concept_id = NA_character_,
    concept_name = "Neoplasms",
    level = NA_integer_,
    score = NA_real_,
    vocabulary = c("MeSH", "medline")
  )
  out <- sm_field_pubmed_mesh(corpus)
  expect_identical(out$mesh_term, "Neoplasms")
  expect_identical(out$count, 2L)
})

test_that("sm_field_pubmed_mesh returns a typed empty tibble without MeSH", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  expect_message(out <- sm_field_pubmed_mesh(corpus), "No MeSH terms")
  expect_equal(nrow(out), 0L)
  expect_type(out$mesh_term, "character")
  expect_type(out$count, "integer")
  expect_type(out$proportion, "double")
})

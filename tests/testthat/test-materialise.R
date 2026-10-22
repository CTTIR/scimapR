test_that("references materialise by their row index", {
  x <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)
  refs <- x$references
  refs$cited_year <- seq_len(nrow(refs)) + 1900L
  for (overwrite in c(FALSE, TRUE)) {
    expect_no_warning(out <- suppressMessages(sm_materialise(
      x, list(references = refs), overwrite = overwrite
    )))
    expect_identical(out$references$cited_year, refs$cited_year)
    expect_identical(out$references$cited_doi, x$references$cited_doi)
    expect_identical(out$references$cited_raw, x$references$cited_raw)
  }
  expect_warning(out <- suppressMessages(sm_materialise(
    x, list(references = refs),
    .by = list(references = c("work_id", "cited_work_id"))
  )), class = "scimapR_materialise_na_keys")
  expect_identical(out$references$cited_raw, x$references$cited_raw)
  expect_true(all(is.na(out$references$cited_year)))
})

test_that("missing enrichment keys never match missing corpus keys", {
  x <- sm_example_corpus(n_works = 6, n_authors = 4,
                         with_embeddings = FALSE, seed = 1)
  x$works$doi[1:3] <- c(NA, "", " ")
  x$works$cnci <- NA_real_
  new <- tibble::tibble(doi = c(NA, "", " ", x$works$doi[4]),
                        cnci = c(9.9, 8.8, 7.7, 1.5))
  expect_warning(expect_message(out <- sm_materialise(
    x, list(works = new), .by = list(works = "doi")
  ), class = "scimapR_materialise_unmatched_rows"),
  "3", class = "scimapR_materialise_na_keys")
  expect_identical(out$works$cnci, c(NA_real_, NA_real_, NA_real_, 1.5, NA, NA))
})

test_that("keyword keys can use normalised vocabularies on both sides", {
  x <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)
  x$concepts <- x$concepts[is.na(x$concepts$concept_id), ]
  new <- x$concepts
  new$score <- seq_len(nrow(new)) / 100
  expect_warning(expect_message(out <- sm_materialise(x, list(concepts = new)),
                                class = "scimapR_materialise_unmatched_rows"),
                 class = "scimapR_materialise_na_keys")
  expect_identical(out$concepts, x$concepts)
  new$vocabulary[new$vocabulary == "author-keywords"] <- "keywords-author"
  x$concepts$vocabulary[x$concepts$vocabulary == "keywords-plus"] <- "ID"
  out <- suppressMessages(sm_materialise(
    x, list(concepts = new), overwrite = TRUE,
    .by = list(concepts = c("work_id", "vocabulary", "concept_name"))
  ))
  expect_identical(out$concepts$score, new$score)
})

test_that("row keys must be unique while group keys may repeat", {
  x <- sm_example_corpus(n_works = 6, n_authors = 4,
                         with_embeddings = FALSE, seed = 1)
  x$works$doi[2] <- x$works$doi[1]
  expect_error(sm_materialise(x, list(works = tibble::tibble(
    doi = x$works$doi[1], score = 1
  )), .by = list(works = "doi")), class = "scimapR_materialise_key_not_unique")
  x$authorships <- dplyr::bind_rows(x$authorships, x$authorships[1, ])
  new <- x$authorships[1, c("work_id", "author_id")]
  new$marker <- "matched"
  out <- suppressMessages(sm_materialise(x, list(authorships = new)))
  hit <- out$authorships$work_id == new$work_id &
    out$authorships$author_id == new$author_id
  expect_gte(sum(hit), 2L)
  expect_true(all(out$authorships$marker[hit] == "matched"))
  new <- tibble::tibble(work_id = rep(x$works$work_id[1], 2), score = c(1, 2))
  expect_warning(out <- suppressMessages(sm_materialise(x, list(works = new))),
                 "duplicate key")
  expect_identical(out$works$score[1], 1)
})

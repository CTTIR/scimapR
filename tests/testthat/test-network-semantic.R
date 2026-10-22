test_that("semantic networks reject repeated work and embedding IDs", {
  x <- sm_example_corpus(n_works = 10, n_authors = 5, seed = 1)
  rownames(x$embeddings)[2] <- rownames(x$embeddings)[1]
  expect_error(sm_network_semantic(x), x$works$work_id[1],
               class = "scimapR_duplicate_ids")
  rownames(x$embeddings) <- x$works$work_id
  x$works$work_id[2] <- x$works$work_id[1]
  expect_error(sm_network_semantic(x), class = "scimapR_duplicate_ids")
})

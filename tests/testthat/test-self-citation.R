test_that("self-citation finds the shared author in reader-built works", {
  x <- sm_read_wos(test_path("fixtures", "link-wos-two.txt"), verbose = FALSE)
  out <- sm_self_citation(x, level = "author")
  brandt <- x$authors$author_id[grepl("Brandt", x$authors$display_name)]
  expect_equal(nrow(out$provenance), 1L)
  expect_identical(out$provenance$shared_author_id, brandt)
  expect_identical(out$provenance$citing_work_id, x$works$work_id[2])
  expect_identical(out$provenance$cited_work_id, x$works$work_id[1])
})

test_that("unlinked self-citation warnings name the explicit linker", {
  x <- sm_example_corpus(n_works = 5, seed = 1)
  x$references$cited_work_id <- NA_character_
  expect_warning(out <- sm_self_citation(x),
                 "No internal reference network.*sm_link_references",
                 class = "scimapR_references_unlinked")
  expect_equal(nrow(out$by_work), 0L)
})

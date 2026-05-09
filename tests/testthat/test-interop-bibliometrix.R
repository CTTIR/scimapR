test_that("sm_to_bibliometrix produces a data.frame with bibliometrixDB class", {
  skip_if_not_installed("bibliometrix")


  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  M <- sm_to_bibliometrix(corpus)

  expect_s3_class(M, "data.frame")
  expect_true("bibliometrixDB" %in% class(M))
  expect_equal(nrow(M), 10L)
})

test_that("sm_to_bibliometrix includes required bibliometrix columns", {
  skip_if_not_installed("bibliometrix")

  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  M <- sm_to_bibliometrix(corpus)

  expected_cols <- c("DI", "TI", "AB", "PY", "DT", "TC", "AU", "DB", "SR")
  for (col in expected_cols) {
    expect_true(col %in% names(M),
                info = paste("Missing column:", col))
  }
})

test_that("sm_to_bibliometrix and back round-trips", {
  skip_if_not_installed("bibliometrix")

  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  M <- sm_to_bibliometrix(corpus)
  roundtrip <- as_sm_corpus(M)

  expect_s3_class(roundtrip, "sm_corpus")
  expect_equal(nrow(roundtrip$works), 10L)
  # DOIs should be preserved (lowercased)
  original_dois <- sort(tolower(corpus$works$doi[!is.na(corpus$works$doi)]))
  rt_dois <- sort(roundtrip$works$doi[!is.na(roundtrip$works$doi)])
  expect_equal(original_dois, rt_dois)
})

test_that("sm_to_bibliometrix errors on non-corpus input", {
  skip_if_not_installed("bibliometrix")

  expect_error(sm_to_bibliometrix("not_a_corpus"), "sm_corpus")
})

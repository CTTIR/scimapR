# Tests for R/enrich-orcid.R (sm_enrich_orcid).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_orcid rejects a non-corpus input", {
  expect_error(sm_enrich_orcid(list()), class = "rlang_error")
})

test_that("orcid skips when no authors have ORCIDs", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$authors$orcid <- NA_character_
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_orcid(corpus, verbose = TRUE),
    "No ORCIDs"
  )
  expect_identical(out$authors, corpus$authors)
})

test_that("orcid updates a richer display name and stores the old one", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2,
                              with_embeddings = FALSE, seed = 2)
  corpus$authors$orcid <- c("0000-0001-0000-0001", NA_character_)
  corpus$authors$display_name[1] <- "J Smith"

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(
        name = list(
          `given-names` = list(value = "Jonathan"),
          `family-name` = list(value = "Smith")
        ),
        `other-names` = list(`other-name` = list(
          list(content = "Jon Smith")
        ))
      )
    },
    .package = "httr2"
  )

  out <- sm_enrich_orcid(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_equal(out$authors$display_name[1], "Jonathan Smith")
  alts <- out$authors$display_name_alternatives[[1]]
  expect_true("J Smith" %in% alts)
  expect_true("Jon Smith" %in% alts)
  expect_true("orcid" %in% out$provenance$source)
})

test_that("orcid does not shorten an already-longer display name", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 1,
                              with_embeddings = FALSE, seed = 3)
  corpus$authors$orcid <- "0000-0001-0000-0002"
  corpus$authors$display_name[1] <- "Alexander Maximilian Smith"

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(name = list(
        `given-names` = list(value = "Al"),
        `family-name` = list(value = "Smith")
      ))
    },
    .package = "httr2"
  )

  out <- sm_enrich_orcid(corpus, verbose = FALSE)
  expect_equal(out$authors$display_name[1], "Alexander Maximilian Smith")
})

test_that("orcid strips a URL prefix from the identifier and tolerates NULL", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 1,
                              with_embeddings = FALSE, seed = 4)
  corpus$authors$orcid <- "https://orcid.org/0000-0001-0000-0003"
  original_name <- corpus$authors$display_name[1]

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) NULL,  # treated as a miss
    .package = "httr2"
  )

  out <- sm_enrich_orcid(corpus, verbose = FALSE)
  expect_equal(out$authors$display_name[1], original_name)
})

test_that("orcid tolerates request errors", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 1,
                              with_embeddings = FALSE, seed = 5)
  corpus$authors$orcid <- "0000-0001-0000-0004"
  original_name <- corpus$authors$display_name[1]

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )

  out <- sm_enrich_orcid(corpus, verbose = FALSE)
  expect_equal(out$authors$display_name[1], original_name)
  expect_s3_class(out, "sm_corpus")
})

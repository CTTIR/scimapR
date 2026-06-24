# Tests for R/enrich-ror.R (sm_enrich_ror).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_ror rejects a non-corpus input", {
  expect_error(sm_enrich_ror(list()), class = "rlang_error")
})

test_that("sm_enrich_ror short-circuits when no unresolved affiliations", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  # Example corpus has all raw_affiliation = NA.
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_ror(corpus, verbose = TRUE),
    "No unresolved affiliations"
  )
  expect_identical(out$authorships, corpus$authorships)
})

# Helper: inject a couple of raw affiliations needing resolution.
with_affiliations <- function(corpus) {
  corpus$authorships$raw_affiliation[1] <- "Charite Berlin"
  corpus$authorships$raw_affiliation[2] <- "Harvard University"
  corpus$authorships$institution_id[1] <- NA_character_
  corpus$authorships$institution_id[2] <- NA_character_
  corpus
}

test_that("ROR matches resolve institutions and update authorships", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 6,
                              with_embeddings = FALSE, seed = 2)
  corpus <- with_affiliations(corpus)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(items = list(
        list(
          chosen = TRUE,
          organization = list(
            id = "https://ror.org/0abcd1234",
            name = "Resolved Org",
            types = list("education"),
            locations = list(list(
              geonames_details = list(country_code = "DE")
            ))
          )
        )
      ))
    },
    .package = "httr2"
  )

  out <- sm_enrich_ror(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")

  inst <- out$institutions
  expect_true("https://ror.org/0abcd1234" %in% inst$institution_id)
  expect_true("Resolved Org" %in% inst$display_name)
  expect_equal(inst$country_code[inst$institution_id ==
                                   "https://ror.org/0abcd1234"], "DE")

  # Authorships rows 1 and 2 now carry the resolved institution id.
  expect_equal(out$authorships$institution_id[1], "https://ror.org/0abcd1234")
  expect_true("ror" %in% out$provenance$source)
})

test_that("ROR falls back to first item when none are chosen", {
  corpus <- sm_example_corpus(n_works = 8, n_authors = 4,
                              with_embeddings = FALSE, seed = 3)
  corpus <- with_affiliations(corpus)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(items = list(
        list(
          chosen = FALSE,
          organization = list(
            id = "https://ror.org/first0001",
            name = "First Match",
            types = list(),
            locations = list()
          )
        )
      ))
    },
    .package = "httr2"
  )

  out <- sm_enrich_ror(corpus, verbose = FALSE)
  expect_true("https://ror.org/first0001" %in% out$institutions$institution_id)
  # No locations -> country_code is NA.
  expect_true(is.na(out$institutions$country_code[
    out$institutions$institution_id == "https://ror.org/first0001"]))
})

test_that("ROR reports no matches when items are empty", {
  corpus <- sm_example_corpus(n_works = 8, n_authors = 4,
                              with_embeddings = FALSE, seed = 4)
  corpus <- with_affiliations(corpus)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) list(items = list()),
    .package = "httr2"
  )

  expect_message(
    out <- sm_enrich_ror(corpus, verbose = TRUE),
    "No ROR matches"
  )
  expect_identical(out$institutions, corpus$institutions)
})

test_that("ROR tolerates request errors (returns corpus unchanged)", {
  corpus <- sm_example_corpus(n_works = 8, n_authors = 4,
                              with_embeddings = FALSE, seed = 5)
  corpus <- with_affiliations(corpus)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("ror down"),
    .package = "httr2"
  )

  expect_message(
    out <- sm_enrich_ror(corpus, verbose = TRUE),
    "No ROR matches"
  )
  expect_identical(out$authorships, corpus$authorships)
})

# Tests for R/enrich-opencitations.R (sm_enrich_opencitations).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").

test_that("sm_enrich_opencitations rejects a non-corpus input", {
  expect_error(sm_enrich_opencitations(list()), class = "rlang_error")
})

test_that("opencitations skips when no DOIs are present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$works$doi <- NA_character_
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2"
  )
  expect_message(
    out <- sm_enrich_opencitations(corpus, verbose = TRUE),
    "No DOIs in corpus"
  )
  expect_identical(out$works, corpus$works)
})

test_that("opencitations updates citation counts and adds references", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  corpus$works$doi <- paste0("10.9999/oc.", 1:3)
  n_refs_before <- nrow(corpus$references)
  first <- corpus$works$work_id[1]
  indices <- corpus$references$ref_index[corpus$references$work_id == first]
  previous <- max(c(0L, indices))
  urls <- character()

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      urls <<- c(urls, req$url)
      structure(list(url = req$url), class = "sm_fake_resp")
    },
    resp_body_json = function(resp, ...) {
      if (grepl("/citation-count/", resp$url)) return(list(list(count = "2")))
      if (!grepl("/references/", resp$url)) stop("unexpected endpoint")
      if (!endsWith(resp$url, "oc.1")) return(list())
      list(list(citing = "doi:10.9999/oc.1",
                cited = "omid:br/999902 doi:10.9999/OC.2"),
           list(citing = "doi:10.9999/oc.1", cited = "doi:10.9999/ext.9"))
    },
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_true(all(out$works$cited_by_count == 2L))
  expect_equal(nrow(out$references), n_refs_before + 2L)
  new <- out$references[seq.int(n_refs_before + 1L, n_refs_before + 2L), ]
  expect_identical(new$work_id, rep(first, 2))
  expect_identical(new$cited_doi, c("10.9999/oc.2", "10.9999/ext.9"))
  expect_identical(new$cited_work_id, c(corpus$works$work_id[2], NA))
  expect_equal(new$ref_index, previous + 1:2)
  expect_true(all(startsWith(urls, "https://api.opencitations.net/index/v2/")))
  expect_length(urls, 6L)
  expect_true("opencitations" %in% out$provenance$source)
  out$references$cited_doi[nrow(out$references)] <- "10.9999/EXT.9"
  twice <- sm_enrich_opencitations(out, verbose = FALSE)
  expect_identical(twice$references$cited_doi, out$references$cited_doi)
  expect_identical(twice$references$ref_index, out$references$ref_index)
})

test_that("opencitations leaves counts unchanged when API returns nothing", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  before <- corpus$works$cited_by_count

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) list(),  # empty result
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  expect_equal(out$works$cited_by_count, before)
  expect_false("opencitations" %in% out$provenance$source)
})

test_that("opencitations tolerates request errors", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  before <- corpus$works$cited_by_count

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("api down"),
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  expect_equal(out$works$cited_by_count, before)
  expect_s3_class(out, "sm_corpus")
})

test_that("opencitations skips cited records that are NA", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 5)
  n_refs_before <- nrow(corpus$references)

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      structure(list(url = req$url), class = "sm_fake_resp")
    },
    resp_body_json = function(resp, ...) {
      if (grepl("/citation-count/", resp$url)) return(list(list(count = "2")))
      list(list(cited = NA_character_), list(cited = ""))
    },
    .package = "httr2"
  )

  out <- sm_enrich_opencitations(corpus, verbose = FALSE)
  expect_true(all(out$works$cited_by_count == 2L))
  expect_equal(nrow(out$references), n_refs_before)
})

test_that("OpenCitations links OpenAlex identifiers when no DOI is available", {
  x <- sm_example_corpus(n_works = 3, with_embeddings = FALSE, seed = 2)
  x$works$doi <- c("10.9999/oc.1", NA, NA)
  x$works$openalex_id[2] <- "https://openalex.org/W99990002"
  x$references <- x$references[0, ]
  local_mocked_bindings(
    req_perform = function(req, ...) {
      if (grepl("/citation-count/", req$url)) stop("count unavailable")
      structure(list(url = req$url), class = "sm_fake_resp")
    },
    resp_body_json = function(...) {
      list(list(cited = "omid:br/999902 openalex:W99990002"))
    }, .package = "httr2"
  )
  out <- sm_enrich_opencitations(x, verbose = FALSE)
  expect_identical(out$references$cited_work_id, x$works$work_id[2])
  expect_identical(out$references$cited_raw, "W99990002")
  expect_identical(out$works$cited_by_count, x$works$cited_by_count)
  expect_equal(sum(out$provenance$source == "opencitations"), 1L)
  twice <- sm_enrich_opencitations(out, verbose = FALSE)
  expect_equal(nrow(twice$references), 1L)
})

test_that("OpenCitations v2 saved responses use outgoing citation direction", {
  skip_if_not_installed("httptest2")
  x <- sm_example_corpus(n_works = 3, with_embeddings = FALSE, seed = 2)
  x$works$doi <- c("10.9999/oc.1", "10.9999/oc.2", NA)
  x$references <- x$references[0, ]
  httptest2::with_mock_dir(test_path("oc-v2"), {
    out <- sm_enrich_opencitations(x, verbose = FALSE)
  })
  expect_identical(out$references$work_id, rep(x$works$work_id[1], 2))
  expect_identical(out$references$cited_work_id, c(x$works$work_id[2], NA))
  expect_identical(out$works$cited_by_count[1:2], c(2L, 0L))
})

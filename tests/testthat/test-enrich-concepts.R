# Tests for R/enrich-concepts.R (sm_enrich_concepts).
# All HTTP is mocked via testthat::local_mocked_bindings(.package = "httr2").
# req_perform returns a sentinel; the body parsers return canned data.

# Guard: any real network attempt must fail loudly, never silently pass.
mock_no_network <- function() {
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("network access attempted"),
    .package = "httr2",
    .env = parent.frame()
  )
}

test_that("sm_enrich_concepts rejects a non-corpus input", {
  expect_error(sm_enrich_concepts(list()), class = "rlang_error")
})

test_that("sm_enrich_concepts validates the source argument", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_enrich_concepts(corpus, source = "bogus"),
               class = "rlang_error")
})

test_that("openalex enrichment adds concepts from mocked responses", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  # Remove any existing openalex concepts so all 3 works are targets.
  corpus$concepts <- corpus$concepts[corpus$concepts$vocabulary != "openalex", ]

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_json = function(resp, ...) {
      list(results = list(list(
        id = "https://openalex.org/W123",
        concepts = list(
          list(id = "C1", display_name = "Oncology", level = 1L, score = 0.9),
          list(id = "C2", display_name = "Genomics", level = 2L, score = 0.5)
        )
      )))
    },
    .package = "httr2"
  )

  n_before <- nrow(corpus$concepts)
  out <- sm_enrich_concepts(corpus, source = "openalex", verbose = FALSE)

  expect_s3_class(out, "sm_corpus")
  oa <- out$concepts[out$concepts$vocabulary == "openalex", ]
  expect_gt(nrow(oa), n_before)
  expect_true("Oncology" %in% oa$concept_name)
  expect_true("Genomics" %in% oa$concept_name)
  # Provenance rows for openalex were appended.
  expect_true("openalex" %in% out$provenance$source)
})

test_that("openalex enrichment short-circuits when no DOIs present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 2)
  corpus$works$doi <- NA_character_
  mock_no_network()
  expect_message(
    out <- sm_enrich_concepts(corpus, source = "openalex", verbose = TRUE),
    "No DOIs"
  )
  expect_identical(out$concepts, corpus$concepts)
})

test_that("openalex enrichment is idempotent when all works already enriched", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  # Example corpus already supplies openalex concepts for every work.
  mock_no_network()
  expect_message(
    out <- sm_enrich_concepts(corpus, source = "openalex", verbose = TRUE),
    "already have OpenAlex"
  )
  expect_equal(nrow(out$concepts), nrow(corpus$concepts))
})

test_that("openalex tolerates API errors and empty result sets", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  corpus$concepts <- corpus$concepts[corpus$concepts$vocabulary != "openalex", ]

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  # tryCatch in source swallows the error -> no concepts added, returns corpus.
  out <- sm_enrich_concepts(corpus, source = "openalex", verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_equal(nrow(out$concepts[out$concepts$vocabulary == "openalex", ]), 0L)
})

test_that("mesh enrichment short-circuits when no PMIDs present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 5)
  corpus$works$pmid <- NA_character_
  mock_no_network()
  expect_message(
    out <- sm_enrich_concepts(corpus, source = "mesh", verbose = TRUE),
    "No PMIDs"
  )
  expect_identical(out$concepts, corpus$concepts)
})

test_that("mesh enrichment parses MeSH descriptors from mocked XML", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  pmid1 <- corpus$works$pmid[1]
  xml_str <- paste0(
    "<PubmedArticleSet>",
    "<PubmedArticle><MedlineCitation><PMID>", pmid1, "</PMID>",
    "<MeshHeadingList>",
    "<MeshHeading><DescriptorName UI='D001'>Neoplasms</DescriptorName></MeshHeading>",
    "<MeshHeading><DescriptorName UI='D002'>Genomics</DescriptorName></MeshHeading>",
    "</MeshHeadingList></MedlineCitation></PubmedArticle>",
    "</PubmedArticleSet>"
  )

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "sm_fake_resp"),
    resp_body_string = function(resp, ...) xml_str,
    .package = "httr2"
  )

  out <- sm_enrich_concepts(corpus, source = "mesh", verbose = FALSE)
  mesh <- out$concepts[out$concepts$vocabulary == "mesh", ]
  expect_gt(nrow(mesh), 0L)
  expect_true("Neoplasms" %in% mesh$concept_name)
  expect_true(all(mesh$work_id[mesh$concept_name == "Neoplasms"] ==
                    corpus$works$work_id[1]))
  expect_true("pubmed" %in% out$provenance$source)
})

test_that("mesh enrichment tolerates a request error gracefully", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 3,
                              with_embeddings = FALSE, seed = 7)
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("efetch down"),
    .package = "httr2"
  )
  out <- sm_enrich_concepts(corpus, source = "mesh", verbose = FALSE)
  expect_s3_class(out, "sm_corpus")
  expect_equal(nrow(out$concepts[out$concepts$vocabulary == "mesh", ]), 0L)
})

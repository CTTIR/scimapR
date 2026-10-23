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
  local_http_env()
  expect_error(sm_enrich_concepts(list()), class = "rlang_error")
})

test_that("sm_enrich_concepts validates the source argument", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_enrich_concepts(corpus, source = "bogus"),
               class = "rlang_error")
})

test_that("openalex enrichment adds concepts from mocked responses", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  # Remove any existing openalex concepts so all 3 works are targets.
  corpus$concepts <- corpus$concepts[corpus$concepts$vocabulary != "openalex", ]

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
    resp_body_json = function(resp, ...) {
      list(results = list(list(
        id = "https://openalex.org/W123",
        doi = corpus$works$doi[1],
        concepts = list(
          list(id = "C1", display_name = "Oncology", level = 1L, score = 0.9),
          list(id = "C2", display_name = "Genomics", level = 2L, score = 0.5)
        )
      )))
    },
    .package = "httr2"
  )

  out <- sm_enrich_concepts(corpus, source = "openalex", verbose = FALSE)

  expect_s3_class(out, "sm_corpus")
  oa <- out$concepts[out$concepts$vocabulary == "openalex", ]
  expect_equal(nrow(oa), 2L)
  expect_true("Oncology" %in% oa$concept_name)
  expect_true("Genomics" %in% oa$concept_name)
  expect_true(all(out$concepts$vocabulary %in% sm_concept_vocabularies()))
  # Provenance rows for openalex were appended.
  expect_true("openalex" %in% out$provenance$source)
})

test_that("openalex enrichment short-circuits when no DOIs present", {
  local_http_env()
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
  local_http_env()
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
  local_http_env()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  corpus$concepts <- corpus$concepts[corpus$concepts$vocabulary != "openalex", ]

  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_warning(out <- sm_enrich_concepts(corpus, source = "openalex",
                                           verbose = FALSE, api_key = ""),
                 class = "scimapR_concepts_unchecked")
  expect_s3_class(out, "sm_corpus")
  expect_equal(nrow(out$concepts[out$concepts$vocabulary == "openalex", ]), 0L)
})

test_that("mesh enrichment short-circuits when no PMIDs present", {
  local_http_env()
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
  local_http_env()
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
    req_perform = function(req, ...) http_response(),
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
  expect_true(all(is.na(mesh$score))) # no MajorTopicYN flags
  expect_true(all(out$concepts$vocabulary %in% sm_concept_vocabularies()))
})

test_that("mesh enrichment records major topics as score 1", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 2, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  xml_str <- paste0(
    "<PubmedArticleSet>",
    "<PubmedArticle><MedlineCitation><PMID>", corpus$works$pmid[1],
    "</PMID><MeshHeadingList>",
    "<MeshHeading><DescriptorName UI='D001' MajorTopicYN='N'>Neoplasms",
    "</DescriptorName><QualifierName MajorTopicYN='Y'>genetics",
    "</QualifierName></MeshHeading>",
    "<MeshHeading><DescriptorName UI='D002' MajorTopicYN='N'>Humans",
    "</DescriptorName></MeshHeading>",
    "</MeshHeadingList></MedlineCitation></PubmedArticle>",
    "</PubmedArticleSet>"
  )
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
    resp_body_string = function(resp, ...) xml_str,
    .package = "httr2"
  )
  out <- sm_enrich_concepts(corpus, source = "mesh", verbose = FALSE)
  mesh <- out$concepts[out$concepts$vocabulary == "mesh", ]
  expect_identical(mesh$concept_id, c("D001", "D002"))
  expect_identical(mesh$score, c(1, 0))
})

test_that("mesh enrichment tolerates a request error gracefully", {
  local_http_env()
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

test_that("enrichment counts concepts stored under another spelling", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 3)
  # Direct assignment keeps these spellings; the enricher normalises them.
  corpus$concepts$vocabulary <- "OpenAlex"
  mock_no_network()
  expect_message(
    out <- sm_enrich_concepts(corpus, source = "openalex", verbose = TRUE),
    "already have OpenAlex"
  )
  expect_identical(out$concepts, corpus$concepts)

  corpus$concepts <- tibble::tibble(
    work_id = corpus$works$work_id,
    concept_id = NA_character_,
    concept_name = "Neoplasms",
    level = NA_integer_,
    score = NA_real_,
    vocabulary = "MEDLINE"
  )
  expect_message(
    out <- sm_enrich_concepts(corpus, source = "mesh", verbose = TRUE),
    "already have MeSH"
  )
  expect_identical(out$concepts, corpus$concepts)
})

test_that("concept enrichment records its provenance as an enrichment", {
  local_http_env()
  # the rows carry the API name; their kind keeps a certificate rebuild
  # from sending the placeholder query as a search
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  corpus$concepts <- corpus$concepts[corpus$concepts$vocabulary != "openalex", ]
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) http_response(),
    resp_body_json = function(resp, ...) {
      list(results = list(list(
        id = "https://openalex.org/W123",
        doi = corpus$works$doi[1],
        concepts = list(
          list(id = "C1", display_name = "Oncology", level = 1L, score = 0.9)
        )
      )))
    },
    .package = "httr2"
  )
  out <- sm_enrich_concepts(corpus, source = "openalex", verbose = FALSE)
  rows <- out$provenance[out$provenance$source == "openalex", ]
  expect_gt(nrow(rows), 0L)
  expect_identical(unique(rows$kind), "enrichment")
  expect_identical(unique(rows$query), "enrich_concepts_openalex")
})

test_that("concept lookups retain successes and stop after a rate limit", {
  local_http_env()
  corpus <- sm_example_corpus(n_works = 110, n_authors = 3)
  corpus$concepts <- corpus$concepts[0, ]
  corpus$works$doi <- paste0("10.9999/concept", 1:110)
  calls <- 0L
  local_mocked_bindings(req_perform = function(req, ...) {
    calls <<- calls + 1L
    if (calls == 2L) return(http_response(status = 429L))
    concept <- list(id = "C1", display_name = "Invented field",
                    level = 1L, score = 0.5)
    record <- list(doi = corpus$works$doi[1], concepts = list(concept))
    http_response(list(results = list(record)))
  }, .package = "httr2")
  warn <- expect_warning(out <- sm_enrich_concepts(corpus, verbose = FALSE,
                                                   api_key = ""),
                         class = "scimapR_concepts_unchecked")
  expect_identical(calls, 2L)
  expect_length(warn$work_ids, 60L)
  expect_identical(out$concepts$work_id, corpus$works$work_id[1])
  added <- out$provenance[out$provenance$query == "enrich_concepts_openalex", ]
  expect_identical(added$work_id, corpus$works$work_id[1])
})

test_that("sm_read_openalex_json parses a JSON array of works", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines(paste0(
    '[{"id":"https://openalex.org/W1",',
    '"doi":"https://doi.org/10.1/a","title":"First",',
    '"publication_year":2020,"type":"article","cited_by_count":5,',
    '"abstract":"Plain abstract text","language":"en",',
    '"open_access":{"oa_status":"gold"},',
    '"authorships":[{"author":{"id":"https://openalex.org/A1",',
    '"display_name":"Jane Doe",',
    '"orcid":"https://orcid.org/0000-0002-1111-2222"},',
    '"institutions":[{"id":"https://openalex.org/I1",',
    '"display_name":"MIT","country_code":"US"}],',
    '"is_corresponding":true}],',
    '"primary_location":{"source":{"display_name":"Nature",',
    '"issn_l":"1111-2222","type":"journal"}},',
    '"concepts":[{"id":"C1","display_name":"Biology","level":0,"score":0.9}],',
    '"referenced_works":["https://openalex.org/W99",',
    '"https://openalex.org/W98"],',
    '"ids":{"pmid":"https://pubmed.ncbi.nlm.nih.gov/12345"},',
    '"is_retracted":true},',
    '{"id":"https://openalex.org/W2","title":"Second no abstract",',
    '"publication_year":2021,"type":"article"}]'
  ), path)

  corpus <- sm_read_openalex_json(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 2L)

  expect_equal(corpus$works$title, c("First", "Second no abstract"))
  expect_equal(corpus$works$doi[1], "10.1/a")
  expect_equal(corpus$works$abstract[1], "Plain abstract text")
  expect_true(is.na(corpus$works$abstract[2]))
  expect_identical(corpus$works$year, c(2020L, 2021L))
  expect_identical(corpus$works$cited_by_count[1], 5L)
  expect_equal(corpus$works$oa_status[1], "gold")
  expect_equal(corpus$works$pmid[1], "12345")          # stripped of URL prefix
  expect_true(corpus$works$is_retracted[1])
  expect_equal(corpus$works$openalex_id[1], "https://openalex.org/W1")
})

test_that("sm_read_openalex_json builds authors, sources, concepts, references", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines(paste0(
    '[{"id":"https://openalex.org/W1",',
    '"title":"First","publication_year":2020,"type":"article",',
    '"abstract":"x",',
    '"authorships":[{"author":{"id":"https://openalex.org/A1",',
    '"display_name":"Jane Doe",',
    '"orcid":"https://orcid.org/0000-0002-1111-2222"},',
    '"institutions":[{"id":"https://openalex.org/I1",',
    '"display_name":"MIT","country_code":"US"}],',
    '"is_corresponding":true}],',
    '"primary_location":{"source":{"display_name":"Nature",',
    '"issn_l":"1111-2222","type":"journal"}},',
    '"concepts":[{"id":"C1","display_name":"Biology","level":0,"score":0.9}],',
    '"referenced_works":["https://openalex.org/W99",',
    '"https://openalex.org/W98"]}]'
  ), path)

  corpus <- sm_read_openalex_json(path, verbose = FALSE)

  # orcid prefix stripped
  expect_equal(corpus$authors$orcid[1], "0000-0002-1111-2222")
  expect_equal(corpus$authors$display_name[1], "Jane Doe")
  expect_equal(corpus$authorships$country_code[1], "US")
  expect_equal(corpus$authorships$raw_affiliation[1], "MIT")

  expect_equal(corpus$sources$display_name[1], "Nature")
  expect_equal(corpus$sources$issn_l[1], "1111-2222")

  expect_equal(corpus$concepts$concept_name[1], "Biology")
  expect_equal(unique(corpus$concepts$vocabulary), "openalex")

  expect_equal(nrow(corpus$references), 2L)
  expect_setequal(corpus$references$cited_raw,
                  c("https://openalex.org/W99", "https://openalex.org/W98"))

  expect_equal(unique(corpus$provenance$source), "openalex")
})

test_that("sm_read_openalex_json reads newline-delimited JSON (JSONL)", {
  path <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(
    '{"id":"W1","title":"L1","publication_year":2020,"type":"article","abstract":"a"}',
    '{"id":"W2","title":"L2","publication_year":2021,"type":"article","abstract":"b"}'
  ), path)

  corpus <- sm_read_openalex_json(path, verbose = FALSE)

  expect_equal(nrow(corpus$works), 2L)
  expect_equal(corpus$works$title, c("L1", "L2"))
})

test_that(".openalex_reconstruct_abstract rebuilds text from an inverted index", {
  idx <- list(
    This = list(0),
    study = list(1),
    examines = list(2),
    spatial = list(3, 5),
    patterns = list(4)
  )
  result <- scimapR:::.openalex_reconstruct_abstract(idx)
  expect_equal(result, "This study examines spatial patterns spatial")
})

test_that(".openalex_reconstruct_abstract returns NA for empty/degenerate input", {
  expect_true(is.na(scimapR:::.openalex_reconstruct_abstract(list())))
  expect_true(is.na(scimapR:::.openalex_reconstruct_abstract(NULL)))
})

test_that("sm_read_openalex_json deduplicates authors across works by OpenAlex id", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines(paste0(
    '[{"id":"https://openalex.org/W1","title":"A","type":"article",',
    '"abstract":"x","authorships":[{"author":{"id":"https://openalex.org/A1",',
    '"display_name":"Shared Author"}}]},',
    '{"id":"https://openalex.org/W2","title":"B","type":"article",',
    '"abstract":"y","authorships":[{"author":{"id":"https://openalex.org/A1",',
    '"display_name":"Shared Author"}}]}]'
  ), path)

  corpus <- sm_read_openalex_json(path, verbose = FALSE)

  # Same author id across two works collapses to one author row...
  expect_equal(nrow(corpus$authors), 1L)
  expect_equal(corpus$authors$display_name, "Shared Author")
  # ...but appears in two authorships.
  expect_equal(nrow(corpus$authorships), 2L)
})

test_that("sm_read_openalex_json returns an empty corpus for an empty array", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines("[]", path)

  corpus <- sm_read_openalex_json(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
  expect_equal(corpus$metadata$reader, "sm_read_openalex_json")
})

test_that("sm_read_openalex_json errors when content is not JSON array/object", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines("garbage not json", path)

  expect_error(
    sm_read_openalex_json(path, verbose = FALSE),
    "Cannot parse OpenAlex JSON"
  )
})

test_that("sm_read_openalex_json errors on a missing file", {
  expect_error(
    sm_read_openalex_json(tempfile(fileext = ".json"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_openalex_json emits a progress message only when verbose", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines('[{"id":"W1","title":"T","type":"article","abstract":"x"}]', path)

  expect_message(sm_read_openalex_json(path, verbose = TRUE), "OpenAlex")
  expect_silent(sm_read_openalex_json(path, verbose = FALSE))
})

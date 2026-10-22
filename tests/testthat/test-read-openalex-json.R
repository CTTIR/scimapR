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
  expect_true(all(corpus$concepts$vocabulary %in% sm_concept_vocabularies()))

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

test_that("sm_read_openalex_json reads the corresponding author", {
  # A saved response: the second author of W1 is corresponding; W2 marks
  # every author false and W3 has no flag (both unknown); W4 lists its
  # corresponding author only in corresponding_author_ids.
  path <- test_path("fixtures", "openalex-corresponding.json")
  corpus <- sm_read_openalex_json(path, verbose = FALSE)
  a <- corpus$authorships
  w <- match(a$work_id, corpus$works$work_id)
  flags <- split(a$is_corresponding[order(w, a$position)], sort(w))
  expect_identical(unname(flags), list(c(FALSE, TRUE, FALSE), c(NA, NA),
                                       c(NA, NA), c(FALSE, TRUE)))
})

# ---- impact fields, affiliations, sources, envelopes ------------------------

test_that("sm_read_openalex_json keeps fwci, percentiles and yearly counts", {
  corpus <- sm_read_openalex_json(test_path("fixtures", "openalex-impact.json"),
                                  verbose = FALSE)
  w <- corpus$works
  expect_equal(w$fwci, c(2.4, NA, 0.35))
  expect_equal(w$citation_percentile, c(0.97, NA, 0.41))
  expect_identical(w$is_top_10pct, c(TRUE, NA, FALSE))
  expect_identical(w$is_top_1pct, c(FALSE, NA, FALSE))
  # a file has no fetch date: a record without updated_date gets NA
  expect_identical(w$citations_as_of,
                   as.Date(c("2026-10-01", "2026-09-30", NA)))
  yearly <- corpus$citations_by_year
  expect_identical(yearly$work_id, w$work_id[c(1, 1, 1, 3)])
  expect_identical(yearly$year, c(2021L, 2023L, 2024L, 2025L))
  expect_identical(sum(yearly$cited_by_count), 13L)
})

test_that("sm_read_openalex_json reads raw affiliation strings", {
  corpus <- sm_read_openalex_json(test_path("fixtures", "openalex-impact.json"),
                                  verbose = FALSE)
  a <- corpus$authorships
  expect_identical(a$raw_affiliation, c(
    paste("Northtown Field Hospital, Dept. of Emergency Medicine, Northtown;",
          "Reserve Medical Company 7, Northtown"),
    "Institute of Invented Microbiology, Southcity",
    "Southcity University Hospital",
    "Northtown Field Hospital"
  ))
  # the raw strings carry the unit text that dictionaries match
  dict <- data.frame(institution = "Reserve Medical Company 7",
                     pattern = "Reserve Medical Company 7",
                     email_domain = NA_character_)
  matched <- suppressMessages(sm_affiliation_match(corpus, dict))
  expect_identical(sum(matched$authorships$institution_match %in%
                         "Reserve Medical Company 7"), 1L)
})

test_that("sm_read_openalex_json links works to their sources by id", {
  corpus <- sm_read_openalex_json(test_path("fixtures", "openalex-impact.json"),
                                  verbose = FALSE)
  # works 1 and 2 share a source; work 3 has another source of the same name
  expect_false(anyNA(corpus$works$source_id))
  expect_identical(nrow(corpus$sources), 2L)
  expect_identical(corpus$works$source_id[1], corpus$works$source_id[2])
  expect_false(identical(corpus$works$source_id[1], corpus$works$source_id[3]))
  expect_true(all(corpus$works$source_id %in% corpus$sources$source_id))
  expect_identical(
    corpus$sources$issn_l[match(corpus$works$source_id,
                                corpus$sources$source_id)],
    c("9999-0001", "9999-0001", "9999-0002")
  )
  expect_identical(sm_summary_works(corpus)$n_sources, 2L)
})

test_that("sm_read_openalex_json unwraps saved API responses", {
  works <- jsonlite::read_json(test_path("fixtures", "openalex-impact.json"))
  envelope <- list(meta = list(count = 3L, next_cursor = NULL),
                   results = works, group_by = list())
  compact <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(envelope, compact, auto_unbox = TRUE, null = "null",
                       digits = NA)
  pretty <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(envelope, pretty, auto_unbox = TRUE, null = "null",
                       digits = NA, pretty = TRUE)
  jsonl <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(
    jsonlite::toJSON(list(meta = list(count = 2L), results = works[1:2]),
                     auto_unbox = TRUE, null = "null", digits = NA),
    jsonlite::toJSON(works[[3]], auto_unbox = TRUE, null = "null",
                     digits = NA)
  ), jsonl)
  for (path in c(compact, pretty, jsonl)) {
    corpus <- sm_read_openalex_json(path, verbose = FALSE)
    expect_identical(nrow(corpus$works), 3L, info = path)
    expect_identical(corpus$works$title[3],
                     "Blood supply logistics for a field exercise",
                     info = path)
    expect_equal(corpus$works$fwci, c(2.4, NA, 0.35), info = path)
  }

  bundled <- sm_read_openalex_json(
    system.file("extdata", "example_openalex_inverted.json",
                package = "scimapR"),
    verbose = FALSE
  )
  expect_identical(nrow(bundled$works), 3L)
  expect_false(is.na(bundled$works$abstract[1]))
  expect_identical(bundled$works$cited_by_count, c(7L, 0L, 1L))

  single <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(works[[2]], single, auto_unbox = TRUE, null = "null",
                       pretty = TRUE)
  expect_identical(
    sm_read_openalex_json(single, verbose = FALSE)$works$title,
    "Hand hygiene audits on a training ground"
  )
})

test_that("sm_read_openalex_json records a file step, not an absolute path", {
  # the provenance of a file read is a file step, not an OpenAlex search
  # that a certificate rebuild would send with the path as search text
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "exports"))
  path <- file.path(dir, "exports", "works.json")
  writeLines('[{"id":"W1","title":"One","publication_year":2020}]', path)

  withr::local_dir(withr::local_tempdir())
  corpus <- sm_read_openalex_json(path, verbose = FALSE)
  expect_identical(corpus$provenance$kind, "file")
  expect_identical(corpus$provenance$query, "works.json")

  withr::local_dir(dir)
  corpus <- sm_read_openalex_json(path, verbose = FALSE)
  expect_identical(corpus$provenance$query, "exports/works.json")
  corpus <- sm_read_openalex_json("exports/works.json", verbose = FALSE)
  expect_identical(corpus$provenance$query, "exports/works.json")
})


test_that("the OpenAlex file reader links local work identifiers", {
  x <- sm_read_openalex_json(test_path("fixtures", "link-openalex-two.json"),
                             verbose = FALSE)
  expect_identical(x$references$cited_work_id,
                   c(NA_character_, x$works$work_id[1], NA_character_))
})

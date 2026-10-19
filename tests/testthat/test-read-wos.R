test_that("sm_read_wos parses the bundled example_wos.txt fixture", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  expect_true(file.exists(path))

  corpus <- sm_read_wos(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 3L)

  expect_match(corpus$works$title[1],
               "Spatial transcriptomics reveals tumor microenvironment")
  expect_equal(corpus$works$doi[1], "10.1038/s41591-023-02345-6")
  expect_identical(corpus$works$year, c(2023L, 2022L, 2024L))
  expect_equal(corpus$works$type, c("Article", "Article", "Review"))
  expect_identical(corpus$works$cited_by_count, c(42L, 18L, 7L))
})

test_that("sm_read_wos handles AU continuation lines and name normalization", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  corpus <- sm_read_wos(path, verbose = FALSE)

  # Three authors per record via continuation lines
  expect_equal(nrow(corpus$authorships), 9L)
  # "Chen, W" -> "W Chen"
  expect_true("W Chen" %in% corpus$authors$display_name)
  expect_true("S Smith" %in% corpus$authors$display_name)
})

test_that("sm_read_wos captures sources, UT identifier, and provenance", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  corpus <- sm_read_wos(path, verbose = FALSE)

  expect_true("NATURE MEDICINE" %in% corpus$sources$display_name)
  expect_equal(corpus$provenance$source[1], "wos")
  expect_equal(corpus$provenance$source_id_external[1], "WOS:000912345600001")
  expect_equal(corpus$metadata$reader, "sm_read_wos")
})

test_that("sm_read_wos parses keywords, keywords-plus and subject categories", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "PT J",
    "AU Smith, J",
    "TI WoS Concept Title",
    "SO SOME JOURNAL",
    "DE keyword one; keyword two",
    "ID PLUS ONE; PLUS TWO",
    "WC Oncology; Genetics & Heredity",
    "SC Oncology; Genetics",
    "DI 10.1/ABC",
    "PY 2021",
    "TC 3",
    "UT WOS:000000000000001",
    "ER",
    "",
    "EF"
  ), path)

  corpus <- sm_read_wos(path, verbose = FALSE)
  expect_equal(nrow(corpus$works), 1L)
  expect_true("keyword one" %in% corpus$concepts$concept_name)
  expect_true("author-keywords" %in% corpus$concepts$vocabulary)
  expect_true("keywords-plus" %in% corpus$concepts$vocabulary)
  expect_true("wos-subject-category" %in% corpus$concepts$vocabulary)
  expect_true(all(corpus$concepts$vocabulary %in% sm_concept_vocabularies()))

  # WC holds the Web of Science categories, SC the research areas.
  concepts <- corpus$concepts
  expect_identical(concepts$concept_name[concepts$vocabulary == "wos-category"],
                   c("Oncology", "Genetics & Heredity"))
  expect_identical(
    concepts$concept_name[concepts$vocabulary == "wos-subject-category"],
    c("Oncology", "Genetics")
  )
})

test_that("sm_read_wos reads WC categories across continuation lines", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "PT J",
    "AU Smith, J",
    "TI A Long Category List",
    "WC Public, Environmental & Occupational Health; Infectious",
    "   Diseases; Microbiology",
    "PY 2022",
    "UT WOS:000000000000003",
    "ER",
    "",
    "EF"
  ), path)
  # Readers write canonical names and stay silent.
  expect_silent(corpus <- sm_read_wos(path, verbose = FALSE))
  expect_identical(corpus$concepts$vocabulary, rep("wos-category", 3L))
  expect_identical(corpus$concepts$concept_name,
                   c("Public, Environmental & Occupational Health",
                     "Infectious Diseases", "Microbiology"))
})

test_that("sm_read_wos reads the WC categories of the real-use twin", {
  fix <- realuse_corpus()
  twin <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)
  expect_true(all(twin$concepts$vocabulary %in% sm_concept_vocabularies()))
  for (vocab in c("author-keywords", "keywords-plus", "wos-category",
                  "wos-subject-category")) {
    for (i in seq_len(nrow(twin$works))) {
      fix_id <- fix$works$work_id[match(twin$works$doi[i], fix$works$doi)]
      expect_identical(
        twin$concepts$concept_name[twin$concepts$work_id ==
                                     twin$works$work_id[i] &
                                     twin$concepts$vocabulary == vocab],
        fix$concepts$concept_name[fix$concepts$work_id == fix_id &
                                    fix$concepts$vocabulary == vocab],
        info = paste(vocab, twin$works$doi[i])
      )
    }
  }
})

test_that("sm_read_wos extracts cited references with DOIs", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "PT J",
    "AU Smith, J",
    "TI A Title With References",
    "SO SOME JOURNAL",
    "DI 10.1/MAIN",
    "PY 2021",
    "CR Doe J, 2010, J TEST, V1, P1, DOI 10.9/REF1",
    "   Roe R, 2011, J TEST, V2, P2, DOI 10.9/REF2",
    "UT WOS:000000000000002",
    "ER",
    "",
    "EF"
  ), path)

  corpus <- sm_read_wos(path, verbose = FALSE)
  expect_equal(nrow(corpus$references), 2L)
  expect_true("10.9/ref1" %in% corpus$references$cited_doi)
})

test_that("sm_read_wos emits a message when verbose = TRUE", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  expect_message(sm_read_wos(path, verbose = TRUE), "Parsed")
})

test_that("sm_read_wos errors on missing file", {
  expect_error(
    sm_read_wos(tempfile(fileext = ".txt"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_wos returns empty corpus when no PT records present", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("FN Clarivate", "VR 1.0", "EF"), path)

  corpus <- sm_read_wos(path, verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_read_wos validates the engine argument", {
  path <- system.file("extdata", "example_wos.txt", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_wos.txt")
  }
  expect_error(sm_read_wos(path, engine = "nope", verbose = FALSE))
})

test_that("sm_read_wos reads ISSNs and journal abbreviations into sources", {
  path <- realuse_wos_sample()
  corpus <- sm_read_wos(path, verbose = FALSE)
  src <- corpus$sources
  lines <- readLines(path, encoding = "UTF-8")
  tag <- function(x) {
    sub("^.. ", "", grep(paste0("^", x, " "), lines, value = TRUE))
  }
  # one journal per SO line, in the order of the file
  first <- !duplicated(tag("SO"))
  expect_identical(src$display_name, tag("SO")[first])
  expect_identical(src$issn_l, tag("SN")[first])
  expect_identical(src$issn, lapply(which(first), function(i) {
    c(tag("SN")[i], tag("EI")[i])
  }))
  expect_identical(src$abbreviation, tag("J9")[first])
  expect_identical(src$iso_abbreviation, tag("JI")[first])
})

test_that("sm_read_wos takes the electronic ISSN when SN is missing", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("FN Clarivate", "VR 1.0", "PT J", "AU Smith, J",
               "TI A Work", "SO SOME JOURNAL", "EI 9998-0001", "PY 2021",
               "ER", "", "EF"), path)
  src <- sm_read_wos(path, verbose = FALSE)$sources
  expect_identical(src$issn_l, "9998-0001")
  expect_identical(src$issn, list("9998-0001"))
  expect_identical(src$abbreviation, NA_character_)
})

test_that("sm_read_wos keeps the sources columns when no record has SO", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("FN Clarivate", "VR 1.0", "PT J", "AU Smith, J",
               "TI A Work", "PY 2021", "ER", "", "EF"), path)
  src <- sm_read_wos(path, verbose = FALSE)$sources
  expect_identical(nrow(src), 0L)
  expect_identical(names(src), names(sm_read_wos(realuse_wos_sample(),
                                                 verbose = FALSE)$sources))
  expect_true(all(c("abbreviation", "iso_abbreviation") %in% names(src)))
})

test_that("sm_read_wos drops a trailing period from cited-reference DOIs", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("FN Clarivate", "VR 1.0", "PT J", "AU Smith, J",
               "TI A Work", "PY 2021",
               "CR Doe J, 2020, J THINGS, V1, P2, DOI 10.9999/x.1.",
               "   Roe M, 2019, J THINGS, V3, P4, DOI 10.9999/Y.2",
               "ER", "", "EF"), path)
  refs <- sm_read_wos(path, verbose = FALSE)$references
  expect_identical(refs$cited_doi, c("10.9999/x.1", "10.9999/y.2"))
  # the cited reference itself stays as written
  expect_identical(refs$cited_raw[1],
                   "Doe J, 2020, J THINGS, V1, P2, DOI 10.9999/x.1.")
})

test_that("sm_read_wos keeps the author names as the file writes them", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("FN Clarivate", "VR 1.0", "PT J", "AU Ibarra Soto, M",
               "   de Souza, JA", "TI A Work", "PY 2021", "ER",
               "PT J", "AU Ibarra Soto, M", "TI Another Work", "PY 2022",
               "ER", "", "EF"), path)
  authors <- sm_read_wos(path, verbose = FALSE)$authors
  expect_identical(authors$display_name, c("M Ibarra Soto", "JA de Souza"))
  expect_identical(authors$display_name_alternatives,
                   list("Ibarra Soto, M", "de Souza, JA"))
})

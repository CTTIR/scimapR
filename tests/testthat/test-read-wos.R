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

# authorship rows as "record position author address" strings
wos_rows <- function(corpus) {
  a <- corpus$authorships
  name <- corpus$authors$display_name[match(a$author_id,
                                            corpus$authors$author_id)]
  paste(match(a$work_id, corpus$works$work_id), a$position, name,
        a$raw_affiliation)
}

# A Web of Science file of these records; each record gets SO, DI and UT,
# so that bibliometrix::convert2df() reads it as well
write_wos <- function(records, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".txt", .local_envir = env)
  lines <- unlist(lapply(seq_along(records), function(i) {
    c(records[[i]], "SO J TEST", sprintf("DI 10.9999/wos.%d", i),
      sprintf("UT WOS:9999000000000%02d", i), "ER")
  }))
  writeLines(c("FN Clarivate", "VR 1.0", lines, "", "EF"), path)
  path
}

# He is in "Chen" and Li in "Lin" and "Oliver"; Li has two addresses
wos_collision_records <- list(
  c("PT J", "AU He, X", "   Chen, Y", "AF He, Xin", "   Chen, Yu",
    "TI Colliding surnames", "PY 2021",
    "C1 [Chen, Yu] Univ Toronto, Toronto, ON, Canada.",
    "   [He, Xin] Peking Univ, Beijing, Peoples R China."),
  c("PT J", "AU Li, W", "   Lin, Q", "   Oliver, Z",
    "AF Li, Wei", "   Lin, Qiao", "   Oliver, Zoe",
    "TI More colliding surnames", "PY 2022",
    "C1 [Lin, Qiao; Oliver, Zoe] Univ L, L City, Country.",
    "   [Li, Wei] Univ K, K City, Country.",
    "   [Li, Wei] Inst M, M City, Country.")
)

# C1 lines without names, as in older records: one author, two authors,
# and a record that mixes lines with and without names, with names that
# designate nobody of the record on its last line
wos_unbracketed_records <- list(
  c("PT J", "AU Solo, A", "TI One author", "PY 2020",
    "C1 Univ Solo, S City, Country.", "   Inst Solo, T City, Country."),
  c("PT J", "AU Roe, R", "   Doe, J", "TI Two authors", "PY 2020",
    "C1 Univ R, R City, Country.", "   Univ D, D City, Country."),
  c("PT J", "AU Roe, R", "   Doe, J", "AF Roe, Rita", "   Doe, Jon",
    "TI Mixed lines", "PY 2021",
    "C1 [Roe, Rita] Univ R, R City, Country.", "   Inst X, X City, Country.",
    "   [Smith, Quinn] Univ Q, Q City, Country.")
)

test_that("sm_read_wos links C1 by whole names, not surname substrings", {
  # The old surname grep gave He the Toronto address of Chen and Li the
  # address of Lin and Oliver, and kept one address per author.
  corpus <- sm_read_wos(write_wos(wos_collision_records), verbose = FALSE)
  expect_identical(wos_rows(corpus), c(
    "1 1 X He Peking Univ, Beijing, Peoples R China.",
    "1 2 Y Chen Univ Toronto, Toronto, ON, Canada.",
    "2 1 W Li Univ K, K City, Country.",
    "2 1 W Li Inst M, M City, Country.",
    "2 2 Q Lin Univ L, L City, Country.",
    "2 3 Z Oliver Univ L, L City, Country."
  ))
})

test_that("sm_read_wos links C1 lines without author brackets", {
  # An address without names belongs to every author of the record, as in
  # the bibliometrix conversion; before, no author of a record with
  # several authors got one. Names that designate nobody link nobody.
  corpus <- sm_read_wos(write_wos(wos_unbracketed_records), verbose = FALSE)
  expect_identical(wos_rows(corpus), c(
    "1 1 A Solo Univ Solo, S City, Country.",
    "1 1 A Solo Inst Solo, T City, Country.",
    "2 1 R Roe Univ R, R City, Country.",
    "2 1 R Roe Univ D, D City, Country.",
    "2 2 J Doe Univ R, R City, Country.",
    "2 2 J Doe Univ D, D City, Country.",
    "3 1 R Roe Univ R, R City, Country.",
    "3 1 R Roe Inst X, X City, Country.",
    "3 2 J Doe Inst X, X City, Country."
  ))
})

# Record 1: two authors share an address in one RP segment and a third
# follows on a continuation line, in another case; Uhlig has two address
# rows, both flagged. Record 2: the older "(reprint author)". Record 3: RP
# names nobody of the record, record 4 has no RP: both unknown.
wos_rp_records <- list(
  c("PT J", "AU Valdez, P", "   Mertens, C", "   Pieper, C", "   Uhlig, L",
    "AF Valdez, Pieter", "   Mertens, Clara", "   Pieper, Clara",
    "   Uhlig, Lea", "TI Three corresponding authors", "PY 2021",
    "C1 [Valdez, Pieter; Mertens, Clara; Pieper, Clara] Univ A, A City.",
    "   [Uhlig, Lea] Inst B, B City.", "   [Uhlig, Lea] Inst C, C City.",
    "RP Mertens, C; Pieper, C (corresponding author), Univ A, A City.",
    "   Uhlig, L (Corresponding Author), Inst B, B City."),
  c("PT J", "AU Roe, R", "   Doe, J", "TI Reprint author", "PY 2019",
    "RP Doe, J (reprint author), Univ D, D City."),
  c("PT J", "AU Roe, R", "   Doe, J", "TI Nobody of the record", "PY 2019",
    "RP Smith, Q (corresponding author), Univ Q, Q City."),
  c("PT J", "AU Roe, R", "TI No RP", "PY 2018")
)

# Namesakes: "Wang, Y" is Wang Yan (Univ A) and Wang Yu (Univ B). RP names
# "Wang, Y" with the address of Wang Yu (record 1), with an address of
# neither (record 2), and so next to a second corresponding author, Li
# (record 3).
wos_namesake_records <- lapply(list(
  "RP Wang, Y (corresponding author), Univ B, B City, Country.",
  "RP Wang, Y (corresponding author), Univ C, C City, Country.",
  c("RP Wang, Y (corresponding author), Univ C, C City, Country.",
    "   Li, X (corresponding author), Univ A, A City, Country.")
), function(rp) {
  c("PT J", "AU Wang, Y", "   Li, X", "   Wang, Y",
    "AF Wang, Yan", "   Li, Xin", "   Wang, Yu", "TI Namesakes", "PY 2022",
    "C1 [Wang, Yan; Li, Xin] Univ A, A City, Country.",
    "   [Wang, Yu] Univ B, B City, Country.", rp)
})

test_that("sm_read_wos takes the corresponding authors from RP", {
  path <- write_wos(wos_rp_records)
  msgs <- testthat::capture_messages(
    corpus <- sm_read_wos(path, verbose = TRUE)
  )
  expect_true(any(grepl("corresponding author of 2 records is unknown",
                        msgs, fixed = TRUE)))
  a <- corpus$authorships
  w <- match(a$work_id, corpus$works$work_id)
  expect_identical(a$is_corresponding[w == 1L],
                   c(FALSE, TRUE, TRUE, TRUE, TRUE))
  expect_identical(a$position[w == 1L], c(1L, 2L, 3L, 4L, 4L))
  expect_identical(a$is_corresponding[w == 2L], c(FALSE, TRUE))
  expect_identical(a$is_corresponding[w %in% 3:4], c(NA, NA, NA))
  expect_no_message(sm_read_wos(path, verbose = FALSE))
})

test_that("sm_read_wos tells namesakes in RP apart by their address", {
  # Before, "Wang, Y" went to the first Wang, Y of the record whatever the
  # address: Wang Yan was flagged in all three records.
  path <- write_wos(wos_namesake_records)
  msgs <- testthat::capture_messages(
    corpus <- sm_read_wos(path, verbose = TRUE)
  )
  expect_true(any(grepl("corresponding author of 1 record is unknown",
                        msgs, fixed = TRUE)))
  a <- corpus$authorships
  w <- match(a$work_id, corpus$works$work_id)
  expect_identical(a$position[w == 1L], 1:3)
  # the RP address is Wang Yu's
  expect_identical(a$is_corresponding[w == 1L], c(FALSE, FALSE, TRUE))
  # an address of neither: unknown, not a guess
  expect_identical(a$is_corresponding[w == 2L], c(NA, NA, NA))
  # Li is certain, the namesakes stay unknown
  expect_identical(a$is_corresponding[w == 3L], c(NA, TRUE, NA))
})

# authorship rows of both engines, comparable across the case they write
engine_rows <- function(corpus) {
  a <- corpus$authorships
  doi <- corpus$works$doi[match(a$work_id, corpus$works$work_id)]
  sort(paste(doi, a$position, toupper(a$raw_affiliation),
             a$is_corresponding))
}

read_wos_bibliometrix <- function(path) {
  bx <- NULL
  utils::capture.output(bx <- suppressWarnings(suppressMessages(
    sm_read_wos(path, engine = "bibliometrix", verbose = FALSE)
  )))
  bx
}

test_that("the WoS engines write the same authorship rows and flags", {
  skip_if_not_installed("bibliometrix")
  skip_if(utils::packageVersion("bibliometrix") != "5.5.0",
          "formats were observed with bibliometrix 5.5.0")
  path <- realuse_wos_sample()
  native <- sm_read_wos(path, verbose = FALSE)
  expect_identical(engine_rows(read_wos_bibliometrix(path)),
                   engine_rows(native))
  expect_true(anyNA(native$authorships$is_corresponding))
  expect_true(any(native$authorships$is_corresponding %in% TRUE))
})

test_that("the WoS engines agree on RP over several lines and on C1", {
  skip_if_not_installed("bibliometrix")
  skip_if(utils::packageVersion("bibliometrix") != "5.5.0",
          "formats were observed with bibliometrix 5.5.0")
  # convert2df() joins the lines of RP, and those of C1 in C1raw, with a
  # space; the native reader joins them with "; ". Before, the bibliometrix
  # engine lost the RP names after the first line and flagged those authors
  # FALSE (Uhlig in record 1), and merged a C1 line without names into the
  # address before it.
  path <- write_wos(c(wos_rp_records, wos_namesake_records,
                      wos_collision_records, wos_unbracketed_records))
  native <- sm_read_wos(path, verbose = FALSE)
  bx <- read_wos_bibliometrix(path)
  expect_identical(engine_rows(bx), engine_rows(native))
  a <- bx$authorships
  doi <- bx$works$doi[match(a$work_id, bx$works$work_id)]
  expect_identical(a$is_corresponding[doi == "10.9999/wos.1"],
                   c(FALSE, TRUE, TRUE, TRUE, TRUE))
  expect_identical(a$is_corresponding[doi == "10.9999/wos.5"],
                   c(FALSE, FALSE, TRUE))
  # the record with two authors and two addresses without names
  expect_identical(sum(doi == "10.9999/wos.11"), 4L)
  # the mixed record: Univ R for Roe, Inst X for both
  expect_identical(toupper(a$raw_affiliation[doi == "10.9999/wos.12"]),
                   c("UNIV R, R CITY, COUNTRY.", "INST X, X CITY, COUNTRY.",
                     "INST X, X CITY, COUNTRY."))
})

test_that("sm_read_wos records a file step relative to the working directory", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "data"))
  file.copy(test_path("fixtures", "realuse-wos-sample.txt"),
            file.path(dir, "data", "export.txt"))
  withr::local_dir(dir)
  corpus <- sm_read_wos(file.path(dir, "data", "export.txt"), verbose = FALSE)
  expect_identical(unique(corpus$provenance$kind), "file")
  expect_identical(unique(corpus$provenance$query), "data/export.txt")
})


test_that("WoS readers link bracketed citations and the synthetic twin", {
  path <- test_path("fixtures", "link-wos-two.txt")
  x <- sm_read_wos(path, verbose = FALSE)
  expect_identical(x$references$cited_work_id,
                   c(NA_character_, x$works$work_id[1], NA_character_))
  expect_identical(x$references$cited_doi[c(1, 3)], rep("10.9999/ext.l1", 2))
  twin <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)
  expect_equal(sum(twin$references$cited_work_id %in% twin$works$work_id), 9L)
  skip_if_not_installed("bibliometrix")
  bx <- suppressMessages(sm_read_wos(path, engine = "bibliometrix",
                                     verbose = FALSE))
  expect_identical(bx$references$cited_work_id, x$references$cited_work_id)
})


test_that("tab-delimited WoS shares all plaintext corpus tables", {
  tab <- test_path("fixtures", "wos-tabdelim.txt")
  plain <- sm_read_wos(test_path("fixtures", "wos-tabdelim-plain.txt"),
                       verbose = FALSE)
  bom <- withr::local_tempfile(fileext = ".txt")
  text <- readLines(tab, warn = FALSE)
  writeLines(c(paste0("\ufeff", text[1]), text[-1]), bom, useBytes = TRUE)
  utf16 <- withr::local_tempfile(fileext = ".txt")
  writeBin(iconv(paste(text, collapse = "\r\n"), to = "UTF-16LE",
                 toRaw = TRUE)[[1]], utf16)
  cases <- list(list(tab, "native", "UTF-8"), list(tab, "auto", "UTF-8"),
                list(bom, "native", "UTF-8"),
                list(utf16, "native", "UTF-16LE"))
  for (case in cases) {
    expect_no_warning(x <- sm_read_wos(case[[1]], engine = case[[2]],
                                       encoding = case[[3]], verbose = FALSE))
    expect_equal(nrow(x$works), 3L)
    x$works$last_refreshed <- plain$works$last_refreshed <- NULL
    for (table in c("works", "authors", "authorships", "sources",
                    "references", "concepts")) {
      expect_identical(x[[table]], plain[[table]], info = table)
    }
    keep <- setdiff(names(plain$provenance), c("fetch_date", "query"))
    expect_identical(x$provenance[keep], plain$provenance[keep])
  }
  local_ref <- plain$references$cited_doi == "10.9999/tab.1"
  expect_identical(plain$references$cited_work_id[local_ref],
                   plain$works$work_id[1])
  second <- plain$authorships[plain$authorships$work_id ==
                                plain$works$work_id[2], ]
  expect_true(all(second$is_corresponding[second$position == 2L]))
  expect_false(any(second$is_corresponding[second$position == 1L]))
  expect_error(sm_read_wos(tab, engine = "bibliometrix", verbose = FALSE),
               class = "scimapR_wos_engine_unsupported")
})

test_that("unreadable WoS records are diagnosed without losing readable ones", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("PT J", "PY 2020", "ER"), path)
  expect_error(sm_read_wos(path, verbose = FALSE),
               class = "scimapR_wos_unreadable")
  writeLines(c("PT J", "TI First", "ER", "PT J", "PY 2020", "ER",
               "PT J", "TI Second", "ER"), path)
  expect_warning(x <- sm_read_wos(path, verbose = FALSE),
                 class = "scimapR_wos_empty_records")
  expect_identical(x$works$title, c("First", "Second"))
  writeLines(c("PT\tAU\tTI\tUT", "J\tBrandt, K\tTitle\tWOS:1\textra"), path)
  expect_error(sm_read_wos(path, verbose = FALSE), "2",
               class = "scimapR_wos_unreadable")
  writeLines(c("PT\tAU\tTI\tUT", "J\tBrandt, K\tShort row"), path)
  expect_no_warning(x <- sm_read_wos(path, verbose = FALSE))
  expect_identical(x$works$title, "Short row")
  expect_true(is.na(x$provenance$source_id_external))
})

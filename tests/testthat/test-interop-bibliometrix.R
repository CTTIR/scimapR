test_that("sm_to_bibliometrix produces a data.frame with bibliometrixDB class", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  M <- sm_to_bibliometrix(corpus)

  expect_s3_class(M, "data.frame")
  expect_true("bibliometrixDB" %in% class(M))
  expect_equal(nrow(M), 10L)
})

test_that("sm_to_bibliometrix includes required bibliometrix columns", {
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
  expect_error(sm_to_bibliometrix("not_a_corpus"), "sm_corpus")
})

# ---- DE: author keywords -------------------------------------------------
# sm_to_bibliometrix() itself does not need bibliometrix, so these tests run
# without it. DE is compared by term and ignoring case.

de_terms <- function(m) {
  lapply(strsplit(toupper(m$DE), ";", fixed = TRUE), trimws)
}

de_corpus <- function() {
  works <- tibble::tibble(work_id = paste0("W", 1:4),
                          title = paste("Work", 1:4), year = 2020L)
  concepts <- tibble::tibble(
    work_id = c("W1", "W1", "W1", "W2", "W2", "W3", "W3", "W4", "W4"),
    concept_id = NA_character_,
    concept_name = c("Alpha", "beta", "PLUS TERM", "Oncology", "gamma",
                     "Biology", "wos cat", "physics.gen-ph", "Mesh Term"),
    level = NA_integer_,
    score = NA_real_,
    vocabulary = c("author-keywords", "author-keywords", "keywords-plus",
                   "openalex", "manual-tags", "openalex", "wos-category",
                   "arxiv", "mesh")
  )
  sm_corpus(works, concepts = concepts)
}

test_that("DE holds the author keywords of each work", {
  m <- sm_to_bibliometrix(de_corpus())
  de <- de_terms(m)
  expect_identical(m$work_id, paste0("W", 1:4))
  expect_identical(de[[1]], c("ALPHA", "BETA"))
  # Zotero manual tags are author keywords too, and they win over OpenAlex
  # concepts of the same work.
  expect_identical(de[[2]], "GAMMA")
})

test_that("DE falls back to OpenAlex concepts only", {
  m <- sm_to_bibliometrix(de_corpus())
  de <- de_terms(m)
  expect_identical(de[[3]], "BIOLOGY")
  # arXiv categories, MeSH, Keywords Plus and categories never enter DE.
  expect_identical(de[[4]], NA_character_)
})

test_that("DE is filled for a corpus read from a Web of Science file", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "PT J",
    "AU Smith, J",
    "TI A Keyworded Work",
    "SO SOME JOURNAL",
    "DE heat illness; recruits",
    "ID HYPERTHERMIA",
    "WC Physiology",
    "SC Physiology",
    "PY 2021",
    "UT WOS:000000000000009",
    "ER",
    "",
    "EF"
  ), path)
  corpus <- sm_read_wos(path, verbose = FALSE)
  m <- sm_to_bibliometrix(corpus)
  expect_identical(de_terms(m)[[1]], c("HEAT ILLNESS", "RECRUITS"))
})

test_that("DE finds author keywords stored under a legacy name", {
  corpus <- de_corpus()
  # Direct assignment bypasses sm_corpus(), so the name stays as written.
  corpus$concepts$vocabulary[1:2] <- "keywords-author"
  m <- sm_to_bibliometrix(corpus)
  expect_identical(de_terms(m)[[1]], c("ALPHA", "BETA"))
})

test_that("DE keeps the OpenAlex concepts of the example corpus", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  m <- sm_to_bibliometrix(corpus)
  oa <- corpus$concepts[corpus$concepts$vocabulary == "openalex", ]
  expected <- lapply(m$work_id, function(w) {
    terms <- toupper(oa$concept_name[oa$work_id == w])
    if (length(terms) == 0L) NA_character_ else terms
  })
  expect_identical(de_terms(m), expected)
})

# ---- Web of Science tags ---------------------------------------------------
# Neither the export nor the import needs bibliometrix; only the tests that
# call bibliometrix functions skip without it.

bx_tags <- c("AU", "AF", "TI", "SO", "J9", "JI", "AB", "C1", "RP", "EM",
             "CR", "NR", "DE", "ID", "WC", "SC", "DT", "LA", "PY", "TC",
             "DI", "PM", "UT", "SN", "EI", "DB", "SR", "SR_FULL", "TI_raw",
             "AB_raw", "DE_raw")

# Two works by hand. In W1 the authorship rows are out of position order,
# the third author has two addresses and is corresponding, and the fourth
# has no name; W2 has one author without an address.
bx_hand_corpus <- function() {
  works <- tibble::tibble(
    work_id = c("W1", "W2"), doi = c("10.9999/MiXed.1", NA),
    title = c("A Mixed-Case Title", "Second work"),
    abstract = c("Some abstract.", NA), year = c(2021L, 2022L),
    type = "Article", source_id = "S1", cited_by_count = c(3L, 0L),
    language = "English"
  )
  authors <- tibble::tibble(
    author_id = paste0("A", 1:5),
    display_name = c("Pieter Valdez", "Smith, Jane A.", "Anna van der Berg",
                     "JA Okafor", NA),
    display_name_alternatives = list(
      character(), character(), c("A van der Berg", "van der Berg, Anna"),
      character(), character()
    )
  )
  authorships <- tibble::tibble(
    work_id = c("W1", "W1", "W1", "W1", "W1", "W2"),
    author_id = c("A3", "A1", "A2", "A3", "A5", "A4"),
    position = c(3L, 1L, 2L, 3L, 4L, 1L),
    is_corresponding = c(TRUE, FALSE, FALSE, TRUE, FALSE, FALSE),
    institution_id = NA_character_,
    raw_affiliation = c("Univ Y, Dept B, Y City, Country.",
                        "Univ X; Dept A, X City.", "Univ X; Dept A, X City.",
                        "Inst Z, Z City.", NA, NA),
    country_code = c("NL", "GB", "GB", "DE", NA, NA)
  )
  sources <- tibble::tibble(
    source_id = "S1", issn_l = "9999-0001",
    issn = list(c("9999-0001", "9998-0002")),
    display_name = "Example Journal of Things", type = "journal",
    abbreviation = "EX J THINGS", iso_abbreviation = "Ex. J. Things"
  )
  references <- tibble::tibble(
    work_id = "W1", ref_index = c(3L, 1L, 2L, 4L), cited_work_id = NA,
    cited_doi = NA,
    cited_raw = c("A title; with a semicolon",
                  "Smith, J. A., 2020, J Med, V1, P2, DOI 10.9999/AbC.1",
                  "Doe JA, 2019, Some Journal, V3, P4", NA)
  )
  concepts <- tibble::tibble(
    work_id = "W1", concept_id = NA_character_,
    concept_name = c("Heat Stress", "alpha; beta", "HYPERTHERMIA", "Humans",
                     "Physiology", "Physiology Research"),
    level = NA_integer_, score = NA_real_,
    vocabulary = c("author-keywords", "author-keywords", "keywords-plus",
                   "mesh", "wos-category", "wos-subject-category")
  )
  sm_corpus(works, authors = authors, authorships = authorships,
            sources = sources, references = references, concepts = concepts)
}

test_that("every tag column is present, NA where the corpus has no data", {
  m <- sm_to_bibliometrix(sm_example_corpus(n_works = 5, n_authors = 3,
                                            with_embeddings = FALSE,
                                            seed = 1))
  expect_true(all(bx_tags %in% names(m)))
  expect_true(all(is.na(m$UT)))
  expect_true(all(is.na(m$C1)))
  expect_identical(unique(m$DB), "scimapR")

  empty <- sm_to_bibliometrix(sm_corpus(.empty_works()))
  expect_s3_class(empty, "bibliometrixDB")
  expect_identical(nrow(empty), 0L)
  expect_true(all(bx_tags %in% names(empty)))
})

test_that("keep_extra = FALSE keeps the tag columns only", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  # the columns of earlier versions except AU_CO, whose ISO country codes
  # moved to country_code
  earlier <- c("work_id", "DI", "TI", "AB", "PY", "DT", "source_id", "TC",
               "oa_status", "LA", "PM", "arxiv_id", "openalex_id",
               "is_retracted", "retraction_date", "last_refreshed", "AU",
               "CR", "NR", "DE", "SO", "SO_ISSN", "DB", "SR")
  m <- sm_to_bibliometrix(corpus)
  expect_true(all(c(earlier, "country_code") %in% names(m)))
  expect_false("AU_CO" %in% names(m))
  tags_only <- sm_to_bibliometrix(corpus, keep_extra = FALSE)
  expect_setequal(names(tags_only), bx_tags)
  expect_error(sm_to_bibliometrix(corpus, keep_extra = NA), "keep_extra")
  expect_error(sm_to_bibliometrix(corpus, db = "WOS"), "db")
})

test_that("AU and AF hold one Web of Science name per author slot", {
  m <- sm_to_bibliometrix(bx_hand_corpus())
  expect_identical(m$AU, c("VALDEZ P;SMITH JA;VAN DER BERG A", "OKAFOR JA"))
  expect_identical(m$AF, c("VALDEZ, PIETER;SMITH, JANE A.;VAN DER BERG, ANNA",
                           "OKAFOR, JA"))
})

test_that("AU and AF keep surnames of several words and particles", {
  works <- tibble::tibble(work_id = "W1", title = "A work", year = 2021L)
  authors <- tibble::tibble(
    author_id = paste0("A", 1:7),
    display_name = c("M Ibarra Soto", "JA de Souza", "Anna van der Berg",
                     "Chen W.", "van Dijk J.A.", "Joao de Souza Lima",
                     "J Michael Smith"),
    # the spelling sm_read_wos() keeps tells the surname of the first name
    display_name_alternatives = list("Ibarra Soto, M", character(),
                                     character(), character(), character(),
                                     character(), character())
  )
  authorships <- tibble::tibble(work_id = "W1", author_id = authors$author_id,
                                position = 1:7)
  corpus <- sm_corpus(works, authors = authors, authorships = authorships)
  m <- sm_to_bibliometrix(corpus)
  expect_identical(strsplit(m$AU, ";", fixed = TRUE)[[1]], c(
    "IBARRA SOTO M", "DE SOUZA JA", "VAN DER BERG A", "CHEN W",
    "VAN DIJK JA",
    # a particle among the given names gives no initial
    "LIMA JS",
    # without a spelling such as "Smith, J Michael", the last word is the
    # surname
    "SMITH JM"
  ))
  expect_identical(strsplit(m$AF, ";", fixed = TRUE)[[1]][1:4], c(
    "IBARRA SOTO, M", "DE SOUZA, JA", "VAN DER BERG, ANNA", "CHEN, W."
  ))
})

# A Web of Science record whose authors have a surname of two words and one
# with a particle
bx_names_wos_file <- function(path) {
  writeLines(c(
    "FN Clarivate Analytics Web of Science", "VR 1.0", "PT J",
    "AU Ibarra Soto, M", "   de Souza, JA", "   Smith, J",
    "AF Ibarra Soto, Marta", "   de Souza, Joao Antonio", "   Smith, John",
    "TI A test title", "SO J THINGS", "J9 J THINGS", "PY 2021",
    paste("C1 [Ibarra Soto, Marta; de Souza, Joao Antonio] Univ X, Dept Y,",
          "Xtown, Spain."),
    "   [Smith, John] Univ Z, Ztown, England.",
    paste("RP Ibarra Soto, M (corresponding author), Univ X, Dept Y, Xtown,",
          "Spain."),
    "DI 10.9999/abc", "UT WOS:000999900000101", "ER", "", "EF"
  ), path)
  path
}

bx_quiet <- function(expr) {
  out <- NULL
  utils::capture.output(out <- suppressWarnings(suppressMessages(expr)))
  out
}

test_that("names read by sm_read_wos() and sm_read_scopus() export whole", {
  path <- bx_names_wos_file(withr::local_tempfile(fileext = ".txt"))
  m <- sm_to_bibliometrix(sm_read_wos(path, verbose = FALSE))
  expect_identical(m$AU, "IBARRA SOTO M;DE SOUZA JA;SMITH J")
  expect_identical(m$SR, "IBARRA SOTO M, 2021, J THINGS")
  expect_identical(m$RP, paste("IBARRA SOTO, M (CORRESPONDING AUTHOR),",
                               "UNIV X, DEPT Y, XTOWN, SPAIN."))

  scopus <- sm_read_scopus(sm_example_files("example_scopus.csv"),
                           verbose = FALSE)
  s <- sm_to_bibliometrix(scopus)
  expect_identical(s$AU[1], "CHEN W;SMITH S;TANAKA Y")
  expect_identical(s$SR[1], "CHEN W, 2023, NATURE MEDICINE")

  skip_if_not_installed("bibliometrix")
  # Observed with bibliometrix 5.5.0; other versions may differ.
  skip_if(utils::packageVersion("bibliometrix") != "5.5.0",
          "formats were observed with bibliometrix 5.5.0")
  ref <- bx_quiet(bibliometrix::convert2df(path, dbsource = "wos",
                                           format = "plaintext"))
  for (tag in c("AU", "SR", "RP")) {
    expect_identical(unname(m[[tag]]), unname(ref[[tag]]), info = tag)
  }
})

test_that("minimal authorships and references export without warnings", {
  works <- tibble::tibble(work_id = "W1", title = "T", year = 2020L)
  authors <- tibble::tibble(author_id = c("A1", "A2"),
                            display_name = c("Jane Doe", "Max Roe"))
  # sm_corpus() accepts tables without the optional columns.
  minimal <- sm_corpus(
    works, authors = authors,
    authorships = tibble::tibble(work_id = "W1", author_id = c("A2", "A1"),
                                 position = 2:1),
    references = tibble::tibble(work_id = "W1",
                                cited_raw = c("Doe J, 2020, X", "Roe M, 2019"))
  )
  expect_no_warning(m <- sm_to_bibliometrix(minimal))
  expect_identical(m$AU, "DOE J;ROE M")
  expect_identical(m$CR, "DOE J, 2020, X;ROE M, 2019")
  expect_identical(m$C1, NA_character_)
  expect_identical(m$RP, NA_character_)
  expect_identical(m$country_code, "")
  no_position <- sm_corpus(
    works, authors = authors,
    authorships = tibble::tibble(work_id = "W1", author_id = c("A1", "A2"))
  )
  expect_no_warning(m <- sm_to_bibliometrix(no_position, keep_extra = FALSE))
  expect_identical(m$AU, "DOE J;ROE M")
})

test_that("AU lists an author with two address rows once", {
  fix <- realuse_corpus()
  a <- fix$authorships
  expect_true(anyDuplicated(a[, c("work_id", "position")]) > 0L)
  m <- sm_to_bibliometrix(fix)
  au <- strsplit(m$AU, ";", fixed = TRUE)
  expect_false(any(vapply(au, anyDuplicated, integer(1)) > 0L))
  slots <- unique(a[, c("work_id", "position")])
  expect_identical(lengths(au),
                   as.vector(table(factor(slots$work_id, levels = m$work_id))))
})

test_that("C1 groups authors by address and RP names the corresponding", {
  m <- sm_to_bibliometrix(bx_hand_corpus())
  expect_identical(m$C1[1], paste0(
    "[VALDEZ, PIETER; SMITH, JANE A.] UNIV X, DEPT A, X CITY.; ",
    "[VAN DER BERG, ANNA] UNIV Y, DEPT B, Y CITY, COUNTRY.; ",
    "[VAN DER BERG, ANNA] INST Z, Z CITY."
  ))
  expect_identical(m$RP[1], paste0(
    "VAN DER BERG, A (CORRESPONDING AUTHOR), UNIV Y, DEPT B, Y CITY, ",
    "COUNTRY."
  ))
  expect_identical(m$C1[2], NA_character_)
  expect_identical(m$RP[2], NA_character_)
})

test_that("the export has no AU_CO; country_code keeps the ISO codes", {
  # bibliometrix would use a filled AU_CO as it is, so the export leaves it
  # to metaTagExtraction(), which reads the countries from C1.
  m <- sm_to_bibliometrix(bx_hand_corpus())
  expect_false("AU_CO" %in% names(m))
  expect_identical(m$country_code, c("GB;GB;NL;DE", ""))
  expect_false("country_code" %in%
                 names(sm_to_bibliometrix(bx_hand_corpus(),
                                          keep_extra = FALSE)))
})

test_that("RP joins several corresponding authors", {
  corpus <- bx_hand_corpus()
  corpus$authorships$is_corresponding[2] <- TRUE
  m <- sm_to_bibliometrix(corpus)
  expect_identical(m$RP[1], paste0(
    "VALDEZ, P (CORRESPONDING AUTHOR), UNIV X, DEPT A, X CITY.; ",
    "VAN DER BERG, A (CORRESPONDING AUTHOR), UNIV Y, DEPT B, Y CITY, ",
    "COUNTRY."
  ))
})

test_that("CR is in Web of Science form, upper case, in ref_index order", {
  m <- sm_to_bibliometrix(bx_hand_corpus())
  expect_identical(m$CR[1], paste(
    "SMITH JA, 2020, J MED, V1, P2, DOI 10.9999/ABC.1",
    "DOE JA, 2019, SOME JOURNAL, V3, P4",
    "A TITLE, WITH A SEMICOLON", sep = ";"
  ))
  expect_identical(m$NR, c(3L, NA))
  expect_identical(m$CR[2], NA_character_)
})

test_that("a comma after the surname of a cited reference is removed", {
  expect_identical(
    .bx_cr_items(c("Smith, J, 2020, J MED, V1, P2", "Smith, JA, 2020",
                   "Van der Berg, A., 1999, X", "Smith J, 2020, J MED",
                   "Smith, J., Doe, A., A title, 2020", "W2741809807")),
    c("SMITH J, 2020, J MED, V1, P2", "SMITH JA, 2020",
      "VAN DER BERG A, 1999, X", "SMITH J, 2020, J MED",
      "SMITH, J., DOE, A., A TITLE, 2020", "W2741809807")
  )
})

test_that("text tags are upper case and DI stays as stored", {
  m <- sm_to_bibliometrix(bx_hand_corpus())
  expect_identical(m$DI, c("10.9999/MiXed.1", NA))
  expect_identical(m$TI, c("A MIXED-CASE TITLE", "SECOND WORK"))
  expect_identical(m$TI_raw, c("A Mixed-Case Title", "Second work"))
  expect_identical(m$AB_raw[1], "Some abstract.")
  expect_identical(m$DT, c("ARTICLE", "ARTICLE"))
  expect_identical(m$LA, c("ENGLISH", "ENGLISH"))
  expect_identical(m$DE[1], "HEAT STRESS; ALPHA, BETA")
  expect_identical(m$DE_raw[1], "Heat Stress; alpha, beta")
  expect_identical(m$ID[1], "HYPERTHERMIA; HUMANS")
  expect_identical(m$WC[1], "PHYSIOLOGY")
  expect_identical(m$SC[1], "PHYSIOLOGY RESEARCH")
})

test_that("SO, J9, JI, SN and EI come from the sources", {
  m <- sm_to_bibliometrix(bx_hand_corpus())
  expect_identical(m$SO, rep("EXAMPLE JOURNAL OF THINGS", 2L))
  expect_identical(m$J9, rep("EX J THINGS", 2L))
  expect_identical(m$JI, rep("EX. J. THINGS", 2L))
  expect_identical(m$SN, rep("9999-0001", 2L))
  expect_identical(m$EI, rep("9998-0002", 2L))
  expect_identical(m$SR, c("VALDEZ P, 2021, EX J THINGS",
                           "OKAFOR JA, 2022, EX J THINGS"))
  expect_identical(rownames(m), m$SR)
})

test_that("SR is unique; SR_FULL keeps the short reference", {
  corpus <- bx_hand_corpus()
  corpus$works$year <- 2021L
  corpus$authorships$author_id[6] <- "A1"
  m <- sm_to_bibliometrix(corpus)
  expect_identical(m$SR_FULL, rep("VALDEZ P, 2021, EX J THINGS", 2L))
  expect_identical(m$SR, c("VALDEZ P, 2021, EX J THINGS",
                           "VALDEZ P, 2021, EX J THINGS-a"))
})

test_that("UT and DB = ISI for a corpus from Web of Science", {
  fix <- realuse_corpus()
  m <- sm_to_bibliometrix(fix)
  expect_true(all(startsWith(m$UT, "WOS:")))
  no_prov <- setdiff(fix$works$work_id, fix$provenance$work_id)
  expect_length(no_prov, 2L)
  expect_identical(m$UT[match(no_prov, m$work_id)], no_prov)
  expect_identical(unique(m$DB), "ISI")

  # Enrichers add provenance rows of other sources, some without a work.
  extra <- fix$provenance[1:2, ]
  extra$source <- c("unpaywall", "chat")
  extra$work_id[2] <- NA
  fix$provenance <- dplyr::bind_rows(fix$provenance, extra)
  m2 <- sm_to_bibliometrix(fix)
  expect_identical(unique(m2$DB), "ISI")
  expect_identical(m2$UT, m$UT)
  expect_identical(unique(sm_to_bibliometrix(fix, db = "scimapR")$DB),
                   "scimapR")
})

test_that("DB = scimapR unless every work comes from Web of Science", {
  fix <- realuse_corpus()
  fix$works$work_id[1] <- "W000000001"
  m <- sm_to_bibliometrix(fix)
  expect_identical(unique(m$DB), "scimapR")
  expect_identical(unique(sm_to_bibliometrix(fix, db = "ISI")$DB), "ISI")
})

test_that("ID, WC and SC come from their vocabularies", {
  fix <- realuse_corpus()
  m <- sm_to_bibliometrix(fix)
  terms <- function(x) strsplit(x, "; ", fixed = TRUE)
  conc <- fix$concepts
  for (tag in c("ID", "WC", "SC")) {
    vocab <- switch(tag, ID = "keywords-plus", WC = "wos-category",
                    SC = "wos-subject-category")
    rows <- conc[conc$vocabulary == vocab, ]
    expected <- lapply(m$work_id, function(w) {
      x <- toupper(rows$concept_name[rows$work_id == w])
      if (length(x) == 0L) NA_character_ else x
    })
    expect_identical(terms(m[[tag]]), expected, info = tag)
  }
  # WC and SC are different fields.
  expect_true(any(m$WC != m$SC))
})

# ---- the shared converter (as_sm_corpus and engine = "bibliometrix") -------

bx_frame <- function(db = "ISI") {
  m <- data.frame(
    AU = c("VALDEZ P;MERTENS C", "SOLO A", "LI W;LIN Q", "ROE R;DOE J"),
    AF = c("VALDEZ, PIETER;MERTENS, CLARA", "SOLO, ADA", "LI, WEI;LIN, QIAO",
           NA),
    TI = c("FIRST TITLE", "SECOND TITLE", "THIRD TITLE", "FOURTH TITLE"),
    TI_raw = c("First title", NA, NA, NA),
    SO = c("J ONE", "J TWO", "J ONE", NA),
    SN = c("9999-0001", NA, "9999-0001", NA),
    EI = c("9998-0001", "9998-0002", "9998-0001", NA),
    J9 = c("J ONE", "J TWO", "J ONE", NA),
    JI = c("J. ONE", "J. TWO", "J. ONE", NA),
    C1 = c(paste("[VALDEZ, PIETER] UNIV A, A CITY.;",
                 "[MERTENS, CLARA; VALDEZ, PIETER] INST B, B CITY."),
           "UNIV SOLO, S CITY.",
           "[LIN, QIAO] UNIV L, L CITY.;[LI, WEI] UNIV K, K CITY.",
           "UNIV R, R CITY.; UNIV D, D CITY."),
    CR = c("SMITH J, 2020, J MED, V1, P2, DOI 10.9999/ABC.1;DOE J, 2019, X",
           NA, "NONE", NA),
    DE = c("HEAT; COLD", NA, "VIRUS", NA),
    DE_raw = c("heat; cold", NA, NA, NA),
    ID = c("HUMANS", NA, NA, NA),
    WC = c("PHYSIOLOGY", NA, NA, NA),
    SC = c("PHYSIOLOGY", NA, NA, NA),
    UT = c("WOS:000999900000001", "WOS:000999900000002", NA, NA),
    PM = c("12345678", NA, NA, NA),
    DI = c("10.9999/ONE", NA, "10.9999/three", NA),
    PY = c(2020, 2021, 2022, 2023), TC = c(1, 0, 2, NA),
    DT = "ARTICLE", LA = "ENGLISH", DB = db,
    stringsAsFactors = FALSE
  )
  class(m) <- c("bibliometrixDB", "data.frame")
  m
}

test_that("as_sm_corpus() reads works, ids and provenance", {
  x <- as_sm_corpus(bx_frame())
  expect_s3_class(x, "sm_corpus")
  w <- x$works
  expect_identical(w$title, c("First title", "SECOND TITLE", "THIRD TITLE",
                              "FOURTH TITLE"))
  expect_identical(w$doi, c("10.9999/one", NA, "10.9999/three", NA))
  expect_identical(w$year, 2020:2023)
  expect_identical(w$cited_by_count, c(1L, 0L, 2L, NA))
  expect_identical(w$pmid, c("12345678", NA, NA, NA))
  p <- x$provenance
  expect_identical(p$work_id, w$work_id)
  expect_identical(p$source_id_external, bx_frame()$UT)
  # Web of Science rows (DB = "ISI") are labelled "wos" ...
  expect_identical(unique(p$source), "wos")
  # ... unless a label is given.
  y <- as_sm_corpus(bx_frame(), source_label = "my-import")
  expect_identical(unique(y$provenance$source), "my-import")
  expect_identical(unique(as_sm_corpus(bx_frame("SCOPUS"))$provenance$source),
                   "bibliometrix-import")
})

test_that("as_sm_corpus() reads CR into references and SO into sources", {
  x <- as_sm_corpus(bx_frame())
  r <- x$references
  expect_identical(r$work_id, rep(x$works$work_id[1], 2L))
  expect_identical(r$ref_index, 1:2)
  expect_identical(r$cited_doi, c("10.9999/abc.1", NA))
  expect_identical(r$cited_raw,
                   c("SMITH J, 2020, J MED, V1, P2, DOI 10.9999/ABC.1",
                     "DOE J, 2019, X"))
  s <- x$sources
  expect_identical(s$display_name, c("J ONE", "J TWO"))
  expect_identical(s$issn_l, c("9999-0001", "9998-0002"))
  expect_identical(s$issn, list(c("9999-0001", "9998-0001"), "9998-0002"))
  expect_identical(s$abbreviation, c("J ONE", "J TWO"))
  expect_identical(s$iso_abbreviation, c("J. ONE", "J. TWO"))
  expect_identical(x$works$source_id,
                   c(s$source_id[1], s$source_id[2], s$source_id[1], NA))
})

test_that("as_sm_corpus() reads DE, ID, WC and SC into concepts", {
  x <- as_sm_corpus(bx_frame())
  conc <- x$concepts
  w1 <- conc[conc$work_id == x$works$work_id[1], ]
  expect_identical(w1$concept_name,
                   c("heat", "cold", "HUMANS", "PHYSIOLOGY", "PHYSIOLOGY"))
  expect_identical(w1$vocabulary,
                   c("author-keywords", "author-keywords", "keywords-plus",
                     "wos-subject-category", "wos-category"))
  expect_true(all(conc$vocabulary %in% sm_concept_vocabularies()))
  id_vocab <- function(db) {
    conc <- as_sm_corpus(bx_frame(db))$concepts
    conc$vocabulary[conc$concept_name == "HUMANS"]
  }
  expect_identical(id_vocab("SCOPUS"), "index-keywords")
  expect_identical(id_vocab("PUBMED"), "mesh")
})

test_that("as_sm_corpus() links authors to addresses through C1", {
  x <- as_sm_corpus(bx_frame())
  a <- x$authorships
  a$name <- x$authors$display_name[match(a$author_id, x$authors$author_id)]
  a$work <- match(a$work_id, x$works$work_id)
  got <- paste(a$work, a$position, a$name, a$raw_affiliation)
  expect_identical(got, c(
    "1 1 PIETER VALDEZ UNIV A, A CITY.", "1 1 PIETER VALDEZ INST B, B CITY.",
    "1 2 CLARA MERTENS INST B, B CITY.",
    # one author: the address without names is theirs
    "2 1 ADA SOLO UNIV SOLO, S CITY.",
    # Li and Lin are told apart by their full names
    "3 1 WEI LI UNIV K, K CITY.", "3 2 QIAO LIN UNIV L, L CITY.",
    # several authors and addresses without names: every author's (before,
    # nobody's)
    "4 1 R ROE UNIV R, R CITY.", "4 1 R ROE UNIV D, D CITY.",
    "4 2 J DOE UNIV R, R CITY.", "4 2 J DOE UNIV D, D CITY."
  ))
  # the frame has no RP, so the corresponding authors are unknown (the
  # first author was flagged before)
  expect_identical(a$is_corresponding, rep(NA, nrow(a)))
  expect_true("VALDEZ, PIETER" %in%
                unlist(x$authors$display_name_alternatives))
})

test_that("an initials-only AF entry joins the one author of that name", {
  m <- bx_frame()[c(1, 1, 1), c("AU", "AF", "TI", "PY", "DB")]
  m$AU <- c("VALDEZ P;MERTENS C", "VALDEZ P", "VALDEZ P")
  m$AF <- c("VALDEZ, PIETER;MERTENS, CLARA", "VALDEZ, P", NA)
  x <- as_sm_corpus(m)
  expect_identical(x$authors$display_name, c("PIETER VALDEZ", "CLARA MERTENS"))
  first <- x$authorships[x$authorships$position == 1L, ]
  expect_identical(unique(first$author_id), x$authors$author_id[1])
  expect_true(all(c("VALDEZ P", "VALDEZ, P") %in%
                    x$authors$display_name_alternatives[[1]]))

  # Two authors with a full name share the initials: the initials-only
  # entries stay an author of their own.
  m2 <- m[c(1, 2, 3, 1), ]
  m2$AU[4] <- "VALDEZ P"
  m2$AF[4] <- "VALDEZ, PAULA"
  y <- as_sm_corpus(m2)
  expect_identical(y$authors$display_name,
                   c("PIETER VALDEZ", "CLARA MERTENS", "P VALDEZ",
                     "PAULA VALDEZ"))
  first <- y$authorships[y$authorships$position == 1L, ]
  expect_identical(first$author_id, y$authors$author_id[c(1, 3, 3, 4)])
})

test_that("the sources table has the same columns with and without SO", {
  cols <- c(names(.empty_sources()), "abbreviation", "iso_abbreviation")
  with_so <- as_sm_corpus(bx_frame())$sources
  m <- bx_frame()
  m$SO <- NA
  without <- as_sm_corpus(m)$sources
  expect_identical(names(with_so), cols)
  expect_identical(names(without), cols)
  expect_identical(nrow(without), 0L)
  expect_identical(names(as_sm_corpus(bx_frame()[0, ])$sources), cols)
})

test_that("as_sm_corpus() reads bracketed C1 joined in any of three ways", {
  joined <- c("[VALDEZ, PIETER] UNIV A, A CITY.; [MERTENS, CLARA] INST B.",
              "[VALDEZ, PIETER] UNIV A, A CITY.;[MERTENS, CLARA] INST B.",
              "[VALDEZ, PIETER] UNIV A, A CITY. [MERTENS, CLARA] INST B.")
  for (c1 in joined) {
    m <- bx_frame()[1, ]
    m$C1 <- c1
    a <- as_sm_corpus(m)$authorships
    expect_identical(a$raw_affiliation, c("UNIV A, A CITY.", "INST B."),
                     info = c1)
  }
  # unbalanced brackets give unlinked addresses, not an error
  m <- bx_frame()[1, ]
  m$C1 <- "[VALDEZ, PIETER UNIV A, A CITY."
  expect_identical(as_sm_corpus(m)$authorships$raw_affiliation,
                   c(NA_character_, NA_character_))
})

test_that("as_sm_corpus() prefers C1raw, which keeps the names", {
  m <- bx_frame()[1, ]
  m$C1raw <- m$C1
  m$C1 <- "UNIV A, A CITY.;  INST B, B CITY.;"
  a <- as_sm_corpus(m)$authorships
  expect_identical(a$raw_affiliation,
                   c("UNIV A, A CITY.", "INST B, B CITY.", "INST B, B CITY."))
})

test_that("an empty bibliometrix data frame gives an empty corpus", {
  m <- bx_frame()[0, ]
  x <- as_sm_corpus(m)
  expect_s3_class(x, "sm_corpus")
  expect_identical(nrow(x$works), 0L)
  expect_identical(nrow(x$references), 0L)
})

test_that("the round trip keeps works, authors and their addresses", {
  fix <- realuse_corpus()
  m <- sm_to_bibliometrix(fix)
  rt <- as_sm_corpus(m)
  expect_identical(nrow(rt$works), nrow(fix$works))
  expect_identical(rt$works$doi, fix$works$doi)
  expect_identical(rt$works$year, fix$works$year)
  expect_identical(rt$works$title, fix$works$title)

  # Work i of the round trip is work i of the fixture.
  key <- function(corpus, cols) {
    a <- corpus$authorships
    w <- match(a$work_id, corpus$works$work_id)
    unique(paste(w, if ("position" %in% cols) a$position,
                 if ("raw" %in% cols) toupper(a$raw_affiliation)))
  }
  expect_setequal(key(rt, "position"), key(fix, "position"))
  expect_setequal(key(rt, "raw"), key(fix, "raw"))
  expect_setequal(key(rt, c("position", "raw")), key(fix, c("position", "raw")))

  expect_identical(rt$provenance$source_id_external, m$UT)
  vocab <- function(x) table(x$concepts$vocabulary)
  expect_identical(vocab(rt), vocab(fix))

  again <- sm_to_bibliometrix(rt)
  for (tag in c("AU", "AF", "C1", "CR", "DE", "ID", "WC", "SC", "UT", "DB",
                "SO", "SN", "EI", "J9", "JI", "SR")) {
    expect_identical(again[[tag]], m[[tag]], info = tag)
  }
})

# ---- bibliometrix on the export ---------------------------------------------

test_that("the bibliometrix engine reads references, sources and concepts", {
  skip_if_not_installed("bibliometrix")
  path <- realuse_wos_sample()
  bx <- bx_quiet(sm_read_wos(path, engine = "bibliometrix", verbose = FALSE))
  expect_gt(nrow(bx$references), 0L)
  expect_gt(nrow(bx$sources), 0L)
  expect_gt(nrow(bx$concepts), 0L)
  expect_false(anyNA(bx$works$source_id))
  expect_true(all(startsWith(bx$provenance$source_id_external, "WOS:")))
})

test_that("the engines read references, sources and concepts alike", {
  skip_if_not_installed("bibliometrix")
  # Relies on the output of convert2df() as observed with bibliometrix
  # 5.5.0 (TI_raw, C1raw, AF); other versions may differ.
  skip_if(utils::packageVersion("bibliometrix") != "5.5.0",
          "formats were observed with bibliometrix 5.5.0")
  path <- realuse_wos_sample()
  native <- sm_read_wos(path, verbose = FALSE)
  bx <- bx_quiet(sm_read_wos(path, engine = "bibliometrix", verbose = FALSE))
  expect_identical(nrow(bx$works), nrow(native$works))
  expect_identical(bx$references$cited_doi, native$references$cited_doi)
  expect_identical(toupper(bx$references$cited_raw),
                   toupper(native$references$cited_raw))
  expect_identical(nrow(bx$sources), nrow(native$sources))
  expect_false(anyNA(bx$works$source_id))
  expect_identical(bx$sources$issn, native$sources$issn)
  expect_identical(table(bx$concepts$vocabulary),
                   table(native$concepts$vocabulary))
  expect_identical(bx$provenance$source_id_external,
                   native$provenance$source_id_external)
  expect_identical(unique(bx$provenance$source), "wos")
  expect_identical(bx$works$title, native$works$title)
  # One row per author and address, linked through the names in C1: the
  # same (position, address) pairs as the fixture records of the twin.
  pairs <- function(corpus) {
    a <- corpus$authorships
    doi <- corpus$works$doi[match(a$work_id, corpus$works$work_id)]
    unique(paste(doi, a$position, toupper(a$raw_affiliation)))
  }
  fix <- realuse_corpus()
  truth <- pairs(fix)
  truth <- truth[sub(" .*", "", truth) %in% bx$works$doi]
  expect_setequal(pairs(bx), truth)
})

test_that("bibliometrix analyses run on the export", {
  skip_if_not_installed("bibliometrix")
  m <- sm_to_bibliometrix(realuse_corpus())
  res <- bx_quiet(bibliometrix::biblioAnalysis(m, sep = ";"))
  expect_s3_class(res, "bibliometrix")
  has_c1 <- !is.na(m$C1)
  un <- bx_quiet(bibliometrix::metaTagExtraction(m, "AU_UN"))
  # AU_UN keeps the addresses bibliometrix recognises as institutions; it
  # does not recognise the one invented address "Armed Forces Med Off".
  has_un <- !is.na(un$AU_UN) & nzchar(un$AU_UN)
  expect_gt(mean(has_un[has_c1]), 0.95)
  co <- bx_quiet(bibliometrix::metaTagExtraction(m, "AU_CO"))
  expect_true(all(!is.na(co$AU_CO[has_c1]) & nzchar(co$AU_CO[has_c1])))
  # bibliometrix reads the countries from C1 instead of taking the ISO
  # codes of the corpus as they are
  countries <- unlist(strsplit(co$AU_CO[has_c1], ";", fixed = TRUE))
  expect_false(any(countries %in% realuse_corpus()$authorships$country_code))
  rp <- bx_quiet(bibliometrix::rpys(m, graph = FALSE))
  expect_type(rp, "list")
})

test_that("the export matches convert2df() on the Web of Science twin", {
  skip_if_not_installed("bibliometrix")
  # Formats observed with bibliometrix 5.5.0; other versions may differ.
  skip_if(utils::packageVersion("bibliometrix") != "5.5.0",
          "formats were observed with bibliometrix 5.5.0")
  path <- realuse_wos_sample()
  ref <- bx_quiet(bibliometrix::convert2df(path, dbsource = "wos",
                                           format = "plaintext"))
  m <- sm_to_bibliometrix(sm_read_wos(path, verbose = FALSE))
  expect_identical(nrow(m), nrow(ref))
  for (tag in c("DB", "CR", "DI", "AU", "TI", "SO", "J9", "JI", "AB", "DE",
                "ID", "WC", "SC", "DT", "LA", "UT", "SN", "EI", "SR")) {
    expect_identical(unname(m[[tag]]), unname(ref[[tag]]), info = tag)
  }
  expect_equal(m$PY, ref$PY)
  expect_equal(m$TC, ref$TC)
  expect_equal(m$NR, as.integer(ref$NR))
})

test_that("as_sm_corpus() takes the corresponding authors from RP", {
  # Upper case as convert2df() writes it; work 3 has the older "(reprint
  # author)" next to a corresponding author; work 4 names nobody of the
  # work and work 2 has no RP: both unknown. Valdez has two address rows.
  m <- bx_frame()
  m$RP <- c("MERTENS, C (CORRESPONDING AUTHOR), INST B, B CITY.", NA,
            paste("LIN, Q (REPRINT AUTHOR), UNIV L, L CITY.;",
                  "LI, W (CORRESPONDING AUTHOR), UNIV K, K CITY."),
            "SMITH, Q (CORRESPONDING AUTHOR), UNIV Q, Q CITY.")
  x <- as_sm_corpus(m)
  a <- x$authorships
  w <- match(a$work_id, x$works$work_id)
  expect_identical(paste(w, a$position, a$is_corresponding), c(
    "1 1 FALSE", "1 1 FALSE", "1 2 TRUE", "2 1 NA", "3 1 TRUE", "3 2 TRUE",
    "4 1 NA", "4 1 NA", "4 2 NA", "4 2 NA"
  ))
})

test_that("RP segments are read whether joined by '; ' or by a space", {
  # the native reader joins the lines of RP with "; ", convert2df() with a
  # space, so that the next names follow the period ending an address;
  # before, the names after the first line of that form were lost
  native <- paste("Mertens, C; Pieper, C (corresponding author), Univ A,",
                  "A City.; Uhlig, L (Corresponding Author), Inst B, B City.")
  spaced <- toupper(sub(".; ", ". ", native, fixed = TRUE))
  shared <- paste("ROE, R (CORRESPONDING AUTHOR), WASHINGTON UNIV, ST. LOUIS,",
                  "MO 63110 USA. MERTENS, C; PIEPER, C (CORRESPONDING",
                  "AUTHOR), INST B.")
  e <- .rp_entries(c(native, spaced, shared, "DOE, J; UNIV X", NA))
  expect_identical(e[[1]]$name, c("Mertens, C", "Pieper, C", "Uhlig, L"))
  expect_identical(e[[1]]$address,
                   c("Univ A, A City.", "Univ A, A City.", "Inst B, B City."))
  expect_identical(e[[2]]$name, toupper(e[[1]]$name))
  expect_identical(e[[2]]$address, toupper(e[[1]]$address))
  expect_identical(e[[3]]$name, c("ROE, R", "MERTENS, C", "PIEPER, C"))
  expect_identical(e[[3]]$address,
                   c("WASHINGTON UNIV, ST. LOUIS, MO 63110 USA.", "INST B.",
                     "INST B."))
  # no marker, no RP: nobody
  expect_identical(lengths(e[[4]]), c(name = 0L, address = 0L))
  expect_identical(lengths(e[[5]]), c(name = 0L, address = 0L))
})

test_that("as_sm_corpus() reads RP and C1raw as convert2df() writes them", {
  # Work 1: convert2df() joins the lines of RP, and those of C1 in C1raw,
  # with a space; C1 keeps the lines apart with ";" but drops the names.
  # Before, Uhlig on the second RP line was flagged FALSE, and the line of
  # Inst X without names was merged into the address of Uhlig.
  # Work 2: "WANG, Y" is Wang Yan and Wang Yu; the RP address is Wang Yu's.
  # Before, Wang Yan was flagged.
  m <- bx_frame()[1:2, c("AU", "AF", "TI", "PY", "DB")]
  m$AU <- c("VALDEZ P;MERTENS C;UHLIG L", "WANG Y;LI X;WANG Y")
  m$AF <- c("VALDEZ, PIETER;MERTENS, CLARA;UHLIG, LEA",
            "WANG, YAN;LI, XIN;WANG, YU")
  m$C1raw <- c(
    paste("[VALDEZ, PIETER; MERTENS, CLARA] UNIV A, A CITY.",
          "[UHLIG, LEA] INST B, B CITY. INST X, X CITY."),
    "[WANG, YAN; LI, XIN] UNIV A, A CITY. [WANG, YU] UNIV B, B CITY."
  )
  m$C1 <- c("UNIV A, A CITY.; INST B, B CITY.; INST X, X CITY.;",
            "UNIV A, A CITY.; UNIV B, B CITY.;")
  m$RP <- c(paste("MERTENS, C (CORRESPONDING AUTHOR), UNIV A, A CITY.",
                  "UHLIG, L (CORRESPONDING AUTHOR), INST B, B CITY."),
            "WANG, Y (CORRESPONDING AUTHOR), UNIV B, B CITY.")
  x <- as_sm_corpus(m)
  a <- x$authorships
  w <- match(a$work_id, x$works$work_id)
  got <- paste(w, a$position, a$raw_affiliation, a$is_corresponding)
  expect_identical(got, c(
    "1 1 UNIV A, A CITY. FALSE", "1 1 INST X, X CITY. FALSE",
    "1 2 UNIV A, A CITY. TRUE", "1 2 INST X, X CITY. TRUE",
    "1 3 INST B, B CITY. TRUE", "1 3 INST X, X CITY. TRUE",
    "2 1 UNIV A, A CITY. FALSE", "2 2 UNIV A, A CITY. FALSE",
    "2 3 UNIV B, B CITY. TRUE"
  ))
  # an RP address of neither namesake leaves both, and the work, unknown
  m$RP[2] <- "WANG, Y (CORRESPONDING AUTHOR), UNIV C, C CITY."
  a <- as_sm_corpus(m)$authorships
  expect_identical(a$is_corresponding[7:9], c(NA, NA, NA))
})

test_that("the round trip keeps the corresponding authors", {
  fix <- realuse_corpus()
  rt <- as_sm_corpus(sm_to_bibliometrix(fix))
  corr <- function(corpus) {
    a <- corpus$authorships
    w <- match(a$work_id, corpus$works$work_id)
    sort(unique(paste(w, a$position, a$is_corresponding)))
  }
  expect_identical(corr(rt), corr(fix))
  # a work without a flagged author exports RP = NA and reads back unknown
  fix$authorships$is_corresponding[fix$authorships$work_id ==
                                     fix$works$work_id[1]] <- NA
  m <- sm_to_bibliometrix(fix)
  expect_true(is.na(m$RP[1]))
  rt <- as_sm_corpus(m)
  first <- rt$authorships$work_id == rt$works$work_id[1]
  expect_true(all(is.na(rt$authorships$is_corresponding[first])))
})

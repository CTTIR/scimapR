# Tests for Part A: coverage auditing, journal index, reconciliation.

make_corpus <- function(n = 40, seed = 1) {
  sm_example_corpus(n_works = n, n_authors = 15, seed = seed)
}

# ---- A1: sm_coverage_audit --------------------------------------------------

test_that("sm_coverage_audit computes recall/precision/F1 correctly", {
  corpus <- make_corpus()
  # reference = first 30 works + 3 phantom records
  ref <- corpus$works[1:30, c("work_id", "doi", "title", "year")]
  names(ref)[1] <- "id"
  ref <- rbind(ref, tibble::tibble(
    id = paste0("X", 1:3),
    doi = paste0("10.9/phantom", 1:3),
    title = paste("Phantom", 1:3),
    year = c(2018L, 2019L, 2020L)
  ))

  cov <- sm_coverage_audit(corpus, ref, match = "doi")
  expect_s3_class(cov, "sm_coverage")
  expect_equal(cov$n_matched, 30L)
  expect_equal(cov$n_reference, 33L)
  expect_equal(cov$n_corpus, 40L)
  expect_equal(cov$recall, round(30 / 33, 4))
  expect_equal(cov$precision, round(30 / 40, 4))
  expect_equal(cov$n_reference_only, 3L)
  expect_equal(cov$n_corpus_only, 10L)
})

test_that("sm_coverage_audit retains match provenance", {
  corpus <- make_corpus(n = 10)
  ref <- corpus$works[1:8, c("work_id", "doi", "title")]
  names(ref)[1] <- "id"
  cov <- sm_coverage_audit(corpus, ref, match = "doi")
  expect_named(cov$matches,
               c("corpus_id", "reference_id", "match_type", "match_score"))
  expect_equal(nrow(cov$matches), 10L)
  expect_true(all(cov$matches$match_type %in% c("doi", "title", "none")))
  expect_equal(sum(cov$matches$match_type == "doi"), 8L)
})

test_that("sm_coverage_audit produces year breakdowns", {
  corpus <- make_corpus()
  ref <- corpus$works[, c("work_id", "doi", "title", "year")]
  names(ref)[1] <- "id"
  cov <- sm_coverage_audit(corpus, ref, by = "year", match = "doi")
  # flat tibble (B1); nested form retained for one release
  expect_s3_class(cov$breakdowns, "tbl_df")
  expect_named(cov$breakdowns,
               c("dimension", "level", "n_reference", "n_matched", "recall"))
  expect_true("year" %in% names(cov$breakdowns_nested))
  bd <- cov$breakdowns_nested$year
  expect_named(bd, c("slice", "n_reference", "n_matched", "recall"))
  expect_true(all(bd$recall == 1))  # perfect coverage of itself
})

test_that("sm_coverage_audit is type-stable on empty reference", {
  corpus <- make_corpus(n = 5)
  empty_ref <- tibble::tibble(id = character(), doi = character(),
                              title = character())
  cov <- sm_coverage_audit(corpus, empty_ref, match = "doi")
  expect_equal(cov$n_matched, 0L)
  expect_true(is.na(cov$recall))
  expect_equal(cov$precision, 0)
  expect_s3_class(summary(cov), "tbl_df")
})

test_that("sm_coverage_audit title fallback matches DOI-less records", {
  skip_if_not_installed("stringdist")
  corpus <- make_corpus(n = 10)
  ref <- corpus$works[1:5, c("title")]
  ref$id <- paste0("R", 1:5)
  # no DOI column at all -> must use title
  cov <- sm_coverage_audit(corpus, ref, match = "doi_then_title")
  expect_gt(cov$n_matched, 0L)
  expect_true(all(cov$matches$match_type[cov$matches$match_type != "none"]
                  == "title"))
})

test_that("sm_coverage_audit autoplot returns a ggplot", {
  corpus <- make_corpus(n = 20)
  ref <- corpus$works[1:15, c("work_id", "doi", "title", "year")]
  names(ref)[1] <- "id"
  cov <- sm_coverage_audit(corpus, ref, by = "year", match = "doi")
  expect_s3_class(ggplot2::autoplot(cov), "ggplot")
  cov2 <- sm_coverage_audit(corpus, ref, match = "doi")  # no breakdowns
  expect_s3_class(ggplot2::autoplot(cov2), "ggplot")
})

# ---- A2: sm_journal_in_index ------------------------------------------------

ref_index <- function() {
  utils::read.csv(
    system.file("extdata", "example_journal_index.csv", package = "scimapR"),
    stringsAsFactors = FALSE
  )
}

test_that("sm_journal_in_index normalises ISSNs and matches both types", {
  res <- sm_journal_in_index(c("1078-8956", "1546170X", "9999-9999"),
                             index = "doaj", reference_list = ref_index())
  expect_equal(nrow(res), 3L)
  expect_named(res, c("issn", "index", "in_index", "matched_title",
                      "matched_issn_type"))
  expect_identical(res$issn, c("1078-8956", "1546-170X", "9999-9999"))
  expect_identical(res$in_index, c(TRUE, TRUE, FALSE))
  expect_identical(res$matched_title[1], "Nature Medicine")
  expect_identical(res$matched_issn_type, c("print", "electronic", NA))
})

test_that("sm_journal_in_index is vectorized and type-stable when empty", {
  res <- sm_journal_in_index(character(), reference_list = ref_index())
  expect_equal(nrow(res), 0L)
  expect_named(res, c("issn", "index", "in_index", "matched_title",
                      "matched_issn_type"))
})

test_that("sm_journal_in_index errors without a reference list", {
  expect_snapshot(sm_journal_in_index("1078-8956"), error = TRUE)
})

test_that(".normalize_issn handles hyphenation and X check digit", {
  expect_identical(.normalize_issn("15452786"), "1545-2786")
  expect_identical(.normalize_issn("1546-170x"), "1546-170X")
  expect_identical(.normalize_issn("nonsense"), NA_character_)
  expect_identical(.normalize_issn("123"), NA_character_)
})

# ---- A3: sm_reconcile -------------------------------------------------------

test_that("sm_reconcile computes symmetric set differences", {
  a <- make_corpus(n = 20)
  b <- a[5:20]  # 16 works, all in a
  rec <- sm_reconcile(a, b, match = "doi")
  expect_s3_class(rec, "sm_reconciliation")
  expect_equal(rec$summary$n_in_both, 16L)
  expect_equal(rec$summary$n_only_a, 4L)
  expect_equal(rec$summary$n_only_b, 0L)
  expect_named(rec$matches, c("a_id", "b_id", "match_type", "match_score"))
})

test_that("sm_reconcile is type-stable and supports autoplot", {
  a <- make_corpus(n = 10)
  # a genuinely disjoint reference (example-corpus DOIs are deterministic, so
  # build a frame with non-overlapping DOIs/titles)
  b <- tibble::tibble(
    id = paste0("Z", 1:10),
    doi = paste0("10.5555/disjoint.", 1:10),
    title = paste("Completely unrelated study", 1:10),
    year = 2020L
  )
  rec <- sm_reconcile(a, b, match = "doi")
  expect_equal(rec$summary$n_in_both, 0L)
  expect_equal(rec$summary$n_only_a, 10L)
  expect_equal(rec$summary$n_only_b, 10L)
  expect_s3_class(summary(rec), "tbl_df")
  expect_s3_class(ggplot2::autoplot(rec), "ggplot")
})

test_that(".sm_match_records de-duplicates b claims", {
  a <- tibble::tibble(id = c("a1", "a2"), doi = c("10.1/x", "10.1/x"),
                      title = c("t1", "t2"), year = c(2020L, 2020L))
  b <- tibble::tibble(id = "b1", doi = "10.1/x", title = "t1", year = 2020L)
  pairs <- .sm_match_records(a, b, match = "doi")
  expect_equal(nrow(pairs), 1L)  # b1 claimed only once
})

# ---- Breakdown dimensions ---------------------------------------------------

# Four works with DOIs 10.9999/cov.1-4; W1 has authors at two units.
cov_corpus <- function() {
  works <- tibble::tibble(
    work_id = sprintf("W%d", 1:4),
    doi = sprintf("10.9999/cov.%d", 1:4),
    title = c("Field triage in cold weather",
              "Water purification on exercise",
              "A registry of blast injuries",
              "Vaccination uptake in reservists"),
    year = c(2020L, 2020L, 2021L, 2021L),
    type = c("article", "review", "article", "letter")
  )
  authorships <- tibble::tibble(
    work_id = c("W1", "W1", "W2", "W3", "W4"),
    author_id = sprintf("A%d", 1:5),
    position = c(1L, 2L, 1L, 1L, 1L),
    is_corresponding = c(TRUE, FALSE, TRUE, TRUE, TRUE),
    institution_id = NA_character_,
    raw_affiliation = c("Unit North, Northtown", "Unit South, Southcity",
                        "Unit North, Northtown", "Unit South, Southcity",
                        "Elsewhere"),
    country_code = c("DE", "DE", "DE", "NL", "NL")
  )
  sm_corpus(works = works, authorships = authorships)
}

test_that("by accepts columns of the reference and of the works", {
  corpus <- cov_corpus()
  ref <- tibble::tibble(
    id = c("T1", "T2", "T3"),
    doi = c("10.9999/cov.1", "10.9999/cov.2", "10.9999/cov.9"),
    Category = c("cat-1", "cat-2", "cat-2")
  )
  expect_no_warning(
    cov <- sm_coverage_audit(corpus, ref, by = c("category", "type"),
                             match = "doi")
  )
  bd <- sm_coverage_breakdowns(cov)

  # a reference column, found case-insensitively and labelled as passed
  category <- bd[bd$dimension == "category", ]
  expect_identical(category$level, c("cat-1", "cat-2"))
  expect_identical(category$n_reference, c(1L, 2L))
  expect_identical(category$n_matched, c(1L, 1L))
  expect_true(all(is.na(category$n_corpus) & is.na(category$precision) &
                    is.na(category$f1)))

  # a works column: precision only
  type <- bd[bd$dimension == "type", ]
  expect_setequal(type$level, c("article", "letter", "review"))
  expect_true(all(is.na(type$n_reference) & is.na(type$n_matched) &
                    is.na(type$recall) & is.na(type$f1)))
  expect_identical(type$n_corpus[type$level == "article"], 2L)
  expect_equal(type$precision[type$level == "article"], 0.5)

  # the legacy recall view holds the reference-side dimension only
  expect_identical(unique(cov$breakdowns$dimension), "category")
  expect_equal(nrow(cov$breakdowns_nested$type), 0L)
})

test_that("unknown breakdown names abort with the available columns", {
  corpus <- new_sm_corpus(
    works = tibble::tibble(work_id = c("W1", "W2"),
                           doi = c("10.9999/u.1", "10.9999/u.2"),
                           year = c(2020L, 2021L)),
    authors = .empty_authors(),
    authorships = .empty_authorships()
  )
  ref <- tibble::tibble(id = "T1", doi = "10.9999/u.1", unit = "Unit A")
  expect_snapshot(
    sm_coverage_audit(corpus, ref, by = c("unit", "units", "Year2"),
                      match = "doi"),
    error = TRUE
  )
  expect_error(sm_coverage_audit(corpus, ref, by = c("year", NA)),
               "character vector")
  expect_error(sm_coverage_audit(corpus, ref, by = ""), "character vector")
  expect_error(sm_coverage_audit(corpus, ref, by = 1), "character vector")

  # a named dimension that neither side resolves keeps its warning
  expect_warning(
    cov <- sm_coverage_audit(corpus, ref, by = "affiliation", match = "doi"),
    "Could not resolve"
  )
  expect_equal(nrow(sm_coverage_breakdowns(cov)), 0L)
})

test_that("corpus affiliation levels are institutions, not countries", {
  fix <- realuse_corpus()
  ref <- realuse_reference()
  # the fixture's institution_id column exists but holds no value
  expect_true("institution_id" %in% names(fix$authorships))
  expect_true(all(is.na(fix$authorships$institution_id)))

  expect_warning(
    cov <- suppressMessages(
      sm_coverage_audit(fix, ref, by = "affiliation", match = "doi")
    ),
    class = "scimapR_coverage_country_fallback"
  )
  bd <- sm_coverage_breakdowns(cov, "affiliation")
  expect_setequal(bd$level[!is.na(bd$n_corpus)],
                  unique(fix$authorships$country_code))

  matched <- suppressMessages(sm_affiliation_match(fix, realuse_dict()))
  expect_message(
    expect_no_warning(
      cov <- sm_coverage_audit(matched, ref, by = "affiliation",
                               match = "doi")
    ),
    "institution_match",
    class = "scimapR_coverage_affiliation_levels"
  )
  bd <- sm_coverage_breakdowns(cov, "affiliation")

  # expected per-institution counts, computed from the matched fixture (some
  # tracker DOIs are written as resolver links)
  a <- matched$authorships[!is.na(matched$authorships$institution_match), ]
  works <- fix$works
  work_doi <- .norm_doi_match(works$doi)
  ref_doi <- .norm_doi_match(ref$doi)
  in_ref <- !is.na(work_doi) & work_doi %in% ref_doi
  inst_works <- split(a$work_id, a$institution_match)
  n_corpus <- vapply(inst_works, function(w) length(unique(w)), integer(1))
  precision <- vapply(inst_works, function(w) {
    round(mean(in_ref[match(unique(w), works$work_id)]), 4)
  }, double(1))

  corpus_side <- bd[!is.na(bd$n_corpus), ]
  expect_setequal(corpus_side$level, names(n_corpus))
  expect_identical(corpus_side$n_corpus, unname(n_corpus[corpus_side$level]))
  expect_equal(corpus_side$precision, unname(precision[corpus_side$level]))
  # full counting: works with authors at two units count in both slices
  expect_gt(sum(corpus_side$n_corpus), length(unique(a$work_id)))

  # the tracker's units join the corpus levels, so recall and precision meet
  found <- !is.na(ref_doi) & ref_doi %in% work_doi
  recall <- tapply(found, ref$institution, function(x) round(mean(x), 4))
  ref_side <- bd[!is.na(bd$n_reference), ]
  expect_setequal(ref_side$level, names(recall))
  expect_equal(ref_side$recall, as.vector(recall[ref_side$level]))
  expect_true(all(ref_side$level %in% corpus_side$level))
})

test_that("a work with two institutions counts in both slices", {
  corpus <- cov_corpus()
  corpus$authorships$institution_match <- c("Unit North", "Unit South",
                                            "Unit North", "Unit South", NA)
  ref <- tibble::tibble(
    id = c("T1", "T2", "T3"),
    doi = c("10.9999/cov.1", "10.9999/cov.2", "10.9999/cov.9"),
    unit = c("Unit North", "Unit North", "Unit South")
  )
  plain <- sm_coverage_audit(corpus, ref, match = "doi")
  cov <- suppressMessages(
    sm_coverage_audit(corpus, ref, by = c("affiliation", "unit"),
                      match = "doi")
  )
  # the overall audit stays work-based
  expect_identical(summary(cov), summary(plain))

  bd <- sm_coverage_breakdowns(cov)
  expect_named(bd, c("dimension", "level", "n_reference", "n_matched",
                     "recall", "n_corpus", "precision", "f1"))
  aff <- bd[bd$dimension == "affiliation", ]
  expect_identical(aff$level, c("Unit North", "Unit South"))
  # Unit North: W1, W2 (both in the reference); Unit South: W1, W3
  expect_identical(aff$n_corpus, c(2L, 2L))
  expect_equal(aff$precision, c(1, 0.5))
  # three works carry a unit, four slice memberships
  expect_identical(sum(aff$n_corpus), 4L)

  # a corpus reference is multi-valued too, in every view of the breakdown
  cov <- suppressMessages(
    sm_coverage_audit(corpus, corpus[1:2], by = "affiliation", match = "doi")
  )
  aff <- sm_coverage_breakdowns(cov, "affiliation")
  expect_identical(aff$n_reference, c(2L, 1L))
  expect_identical(cov$breakdowns$n_reference, aff$n_reference)
  expect_identical(cov$breakdowns_nested$affiliation$n_matched, c(2L, 1L))
  expect_s3_class(ggplot2::autoplot(cov), "ggplot")
})

test_that("a data-frame reference names institutions before countries", {
  corpus <- cov_corpus()
  corpus$authorships$institution_match <- c("Unit North", "Unit South",
                                            "Unit North", "Unit South", NA)
  ref <- tibble::tibble(
    id = c("T1", "T2"), doi = c("10.9999/cov.1", "10.9999/cov.2"),
    country = c("DE", "DE"), institution = c("Unit North", "Unit North"),
    source_id = c("S1", "S2"), journal = c("Journal A", "Journal B")
  )
  expect_message(
    cov <- sm_coverage_audit(corpus, ref, by = c("affiliation", "source"),
                             match = "doi"),
    "institution",
    class = "scimapR_coverage_affiliation_levels"
  )
  bd <- sm_coverage_breakdowns(cov)
  aff <- bd[bd$dimension == "affiliation" & !is.na(bd$n_reference), ]
  expect_identical(aff$level, "Unit North")
  src <- bd[bd$dimension == "source" & !is.na(bd$n_reference), ]
  expect_identical(src$level, c("Journal A", "Journal B"))

  # a reference that lists countries does not join corpus institutions
  expect_warning(
    suppressMessages(
      sm_coverage_audit(corpus, ref[c("id", "doi", "country")],
                        by = "affiliation", match = "doi")
    ),
    class = "scimapR_coverage_affiliation_kinds"
  )
})

# ---- Record identifiers and matching rules ----------------------------------

test_that("records are never keyed on the Keywords Plus column ID", {
  corpus <- cov_corpus()
  ref <- data.frame(
    DI = sprintf("10.9999/cov.%d", 1:3), TI = c("A", "B", "C"), PY = 2020L,
    ID = c("KEYWORD ONE", NA, NA), stringsAsFactors = FALSE
  )
  expect_no_warning(
    cov <- sm_coverage_audit(corpus, ref, by = "year", match = "doi")
  )
  expect_identical(cov$n_matched, 3L)
  expect_identical(cov$recall, 1)
  expect_identical(cov$n_reference_only, 0L)
  expect_setequal(cov$matches$reference_id[1:3],
                  c("R000001", "R000002", "R000003"))
  year <- sm_coverage_breakdowns(cov, "year")
  expect_identical(year$n_reference[year$level == "2020"], 3L)
  expect_identical(year$n_matched[year$level == "2020"], 3L)

  # the accession number UT identifies the records of a tagged frame
  ref$UT <- sprintf("WOS:%015d", 1:3)
  ref$work_id <- "W1"
  cov <- sm_coverage_audit(corpus, ref, match = "doi")
  expect_identical(cov$matches$reference_id[1:3], ref$UT)
  rec <- sm_reconcile(corpus, ref, match = "doi")
  expect_identical(rec$in_both$b_id, ref$UT)
})

test_that("an identifier with gaps or repeats gives way to row positions", {
  corpus <- cov_corpus()
  ref <- tibble::tibble(
    id = c("T1", "T1", NA),
    doi = c("10.9999/cov.1", "10.9999/cov.2", "10.9999/cov.9"),
    unit = c("Unit A", "Unit B", "Unit B")
  )
  expect_warning(
    cov <- sm_coverage_audit(corpus, ref, by = "unit", match = "doi"),
    class = "scimapR_match_ids_invalid"
  )
  expect_identical(cov$n_matched, 2L)
  expect_identical(cov$n_reference_only, 1L)
  expect_identical(cov$reference_only$id, "R000003")
  expect_identical(cov$matches$reference_id[1:2], c("R000001", "R000002"))
  unit <- sm_coverage_breakdowns(cov, "unit")
  expect_identical(unit$n_reference, c(1L, 2L))
  expect_identical(unit$n_matched, c(1L, 1L))

  expect_warning(rec <- sm_reconcile(corpus, ref, match = "doi"),
                 class = "scimapR_match_ids_invalid")
  expect_identical(rec$summary$n_in_both, 2L)
  expect_identical(rec$only_b$id, "R000003")
})

test_that("an item reported by two units counts as found for both", {
  corpus <- cov_corpus()
  ref <- tibble::tibble(
    id = c("T1", "T2", "T3"),
    doi = c("10.9999/cov.1", "10.9999/COV.1", "10.9999/cov.9"),
    title = NA_character_,
    year = NA_integer_,
    unit = c("Unit A", "Unit B", "Unit B")
  )
  cov <- sm_coverage_audit(corpus, ref, by = "unit", match = "doi")
  expect_identical(cov$n_matched, 2L)
  expect_equal(cov$recall, round(2 / 3, 4))
  expect_identical(cov$n_reference_only, 1L)
  unit <- sm_coverage_breakdowns(cov, "unit")
  expect_identical(unit$level, c("Unit A", "Unit B"))
  expect_equal(unit$recall, c(1, 0.5))
  expect_identical(cov$breakdowns$n_matched, unit$n_matched)

  # precision still pairs each corpus record with one reference row
  expect_identical(cov$n_corpus_matched, 1L)
  expect_equal(cov$precision, 0.25)
  expect_identical(sum(!is.na(cov$matches$reference_id)), 1L)
  # the summary row shows both numerators and adds up on both sides
  s <- summary(cov)
  expect_identical(s$n_matched, 2L)
  expect_identical(s$n_corpus_matched, 1L)
  expect_identical(s$n_matched + s$n_reference_only, s$n_reference)
  expect_identical(s$n_corpus_matched + s$n_corpus_only, s$n_corpus)
  # an object without the element (scimapR 0.4.0) has one count for both
  old <- cov
  old$n_corpus_matched <- NULL
  expect_identical(summary(old)$n_corpus_matched, 2L)
  # the reference side shows where each row was found
  expect_named(cov$reference_matches,
               c("reference_id", "corpus_id", "match_type", "match_score"))
  expect_identical(cov$reference_matches$corpus_id, c("W1", "W1", NA))
  expect_identical(as.character(cov$reference_matches$match_type),
                   c("doi", "doi", "none"))

  # a third report of the item without its DOI is found by its title
  ref <- tibble::add_row(ref, id = "T4", title = corpus$works$title[1],
                         year = 2020L, unit = "Unit C")
  cov <- sm_coverage_audit(corpus, ref, by = "unit")
  unit <- sm_coverage_breakdowns(cov, "unit")
  expect_equal(unit$recall[unit$level == "Unit C"], 1)
  expect_identical(cov$n_corpus_matched, 1L)
  expect_identical(cov$reference_matches$corpus_id[4], "W1")
  expect_identical(as.character(cov$reference_matches$match_type[4]), "title")
})

test_that("the title fallback stays within a year and never crosses DOIs", {
  skip_if_not_installed("stringdist")
  corpus <- sm_corpus(works = tibble::tibble(
    work_id = c("W1", "W2"), doi = c("10.9999/report.2020", NA),
    title = c("Annual Report 2020", "Editorial"), year = c(2020L, 2023L)
  ))
  ref <- tibble::tibble(
    id = c("T1", "T2"), doi = c("10.9999/report.2019", NA),
    title = c("Annual Report 2019", "Editorial"), year = c(2019L, 2018L)
  )
  cov <- sm_coverage_audit(corpus, ref)
  expect_identical(cov$n_matched, 0L)
  expect_identical(cov$n_corpus_matched, 0L)
  expect_true(all(cov$matches$match_type == "none"))
  expect_identical(sm_reconcile(corpus, ref)$summary$n_in_both, 0L)

  # one year apart, or with a year unknown, the generic title still matches
  for (year in list(2022L, NA_integer_)) {
    ref$year[2] <- year
    cov <- sm_coverage_audit(corpus, ref)
    expect_identical(as.character(cov$matches$match_type), c("none", "title"))
    expect_identical(cov$n_matched, 1L)
  }
})

test_that("a Date or date-time year column gives the calendar year", {
  # as.integer() would read a Date as days since 1970, and the year rule of
  # the title fallback would then rule out every corpus record
  corpus <- cov_corpus()
  w <- corpus$works
  ref <- data.frame(title = w$title[1:3],
                    year = as.Date(paste0(w$year[1:3], "-06-01")))
  cov <- sm_coverage_audit(corpus, ref, by = "year", match = "title")
  expect_identical(cov$n_matched, 3L)
  expect_identical(cov$n_corpus_matched, 3L)
  year <- sm_coverage_breakdowns(cov, "year")
  expect_identical(year$level, c("2020", "2021"))
  expect_identical(year$n_reference, c(2L, 1L))

  ref$year <- as.POSIXct(paste0(w$year[1:3], "-06-01 12:00:00"), tz = "UTC")
  cov <- sm_coverage_audit(corpus, ref, match = "title")
  expect_identical(cov$n_matched, 3L)
  rec <- sm_reconcile(corpus, ref, match = "title")
  expect_identical(rec$summary$n_in_both, 3L)

  # a day count is no year: the year rule is skipped, as for a missing year
  ref$year <- as.numeric(as.Date(paste0(w$year[1:3], "-06-01")))
  cov <- sm_coverage_audit(corpus, ref, match = "title")
  expect_identical(cov$n_matched, 3L)
  expect_identical(.match_year(c("2020", "1999.0", "18414", NA)),
                   c(2020L, 1999L, NA, NA))
  expect_identical(.match_year(factor(c("2021", "2020"))), c(2021L, 2020L))
})

test_that(".norm_title keeps the letters of every script", {
  de <- "\u00dcber die \u00d6konomie"
  expect_identical(.norm_title(de), tolower(de))
  ru <- paste("\u0410\u043d\u0430\u043b\u0438\u0437",
              "\u0434\u0430\u043d\u043d\u044b\u0445")
  expect_identical(.norm_title(paste0(ru, "!")), tolower(ru))
  expect_identical(.norm_title(c("Field triage: a review", NA, " -- ")),
                   c("field triage a review", NA, NA))

  a <- tibble::tibble(id = "a1", title = ru, year = 2020L)
  b <- tibble::tibble(id = "b1", title = paste0(ru, "."), year = 2020L)
  rec <- sm_reconcile(a, b, match = "title")
  expect_identical(rec$summary$n_in_both, 1L)
  expect_identical(nrow(rec$only_a), 0L)
})

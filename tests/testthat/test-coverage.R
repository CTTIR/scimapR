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

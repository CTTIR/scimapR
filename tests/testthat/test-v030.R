# Regression tests for the v0.3.0 refinements (A1-A4, B1-B3, C1-C2).

# ---- A1: sm_its cnci impact resolver ---------------------------------------

test_that("A1: sm_its(cnci) resolves a precomputed works$cnci column", {
  corpus <- sm_example_corpus(n_works = 120, seed = 1)
  corpus$works$cnci <- runif(nrow(corpus$works), 0.5, 2)
  its <- sm_its(corpus, intervention_year = 2020, outcome = "cnci")
  expect_s3_class(its, "sm_its")
  expect_gte(nrow(its$series), 4L)
})

test_that("A1: sm_its(cnci) derives impact from cited_by_count", {
  corpus <- sm_example_corpus(n_works = 120, seed = 1)
  its <- sm_its(corpus, intervention_year = 2020, outcome = "cnci")
  expect_gte(nrow(its$series), 4L)
})

test_that("A1: sm_its(cnci) errors informatively when no impact is available", {
  corpus <- sm_example_corpus(n_works = 60, seed = 1)
  corpus$works$cited_by_count <- NA_integer_
  expect_snapshot(
    sm_its(corpus, intervention_year = 2020, outcome = "cnci"),
    error = TRUE
  )
})

# ---- A2: sm_count institution fallback -------------------------------------

test_that("A2: sm_count(institution) falls back to raw_affiliation with a warning", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  corpus$authorships$institution_id <- NA_character_
  corpus$authorships$raw_affiliation <- paste(
    "Inst", sample(1:4, nrow(corpus$authorships), replace = TRUE))
  expect_warning(
    res <- sm_count(corpus, level = "institution"),
    "raw affiliation"
  )
  expect_gt(nrow(res), 0L)
})

test_that("A2: sm_count(institution) warns and returns 0 rows when no institution data", {
  corpus <- sm_example_corpus(n_works = 10, seed = 1)
  corpus$authorships$institution_id <- NA_character_
  corpus$authorships$raw_affiliation <- NA_character_
  expect_warning(res <- sm_count(corpus, level = "institution"),
                 "No institution data")
  expect_equal(nrow(res), 0L)
  expect_named(res, c("entity_id", "entity_name", "n_works", "credit",
                      "weighted_citations"))
})

# ---- A3: disruption / novelty empty-reference guards -----------------------

test_that("A3: sm_metric_disruption fast-exits with a warning on empty references", {
  corpus <- sm_example_corpus(n_works = 50, seed = 1)
  corpus$references <- corpus$references[0, ]
  expect_warning(d <- sm_metric_disruption(corpus), "reference network")
  expect_equal(nrow(d), 50L)
  expect_true(all(is.na(d$cd_index)))
})

test_that("A3: sm_metric_novelty fast-exits with a warning on empty references", {
  corpus <- sm_example_corpus(n_works = 50, seed = 1)
  corpus$references <- corpus$references[0, ]
  expect_warning(n <- sm_metric_novelty(corpus), "reference network")
  expect_equal(nrow(n), 50L)
  expect_true(all(is.na(n$novelty)))
})

test_that("A3: sm_metric_disruption still computes on a real reference network", {
  corpus <- sm_example_corpus(n_works = 60, seed = 1)
  d <- sm_metric_disruption(corpus)
  expect_equal(nrow(d), 60L)
  expect_true(any(!is.na(d$cd_index)))
})

# ---- A4: network plot precompute + cap -------------------------------------

test_that("A4: sm_plot_citation_network(precompute) returns a printable plain ggplot", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 60, seed = 1)
  p <- sm_plot_citation_network(corpus, precompute = TRUE)
  expect_s3_class(p, "ggplot")
  expect_false(inherits(p, "ggraph"))
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("A4: max_nodes caps the graph with a message", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 80, seed = 1)
  expect_message(
    p <- sm_plot_citation_network(corpus, top_n = 80, max_nodes = 10,
                                  precompute = TRUE),
    "capping"
  )
  n_nodes <- nrow(ggplot2::ggplot_build(p)$data[[length(p$layers)]])
  expect_lte(n_nodes, 10L)
})

# ---- B1: flat coverage breakdowns ------------------------------------------

test_that("B1: sm_coverage_audit breakdowns are a flat tibble + nested retained", {
  skip_if_not_installed("stringdist")
  corpus <- sm_example_corpus(n_works = 40, seed = 1)
  ref <- corpus$works[, c("work_id", "doi", "title", "year")]
  names(ref)[1] <- "id"
  cov <- sm_coverage_audit(corpus, ref, by = c("year"), match = "doi")
  expect_s3_class(cov$breakdowns, "tbl_df")
  expect_named(cov$breakdowns,
               c("dimension", "level", "n_reference", "n_matched", "recall"))
  expect_true(is.list(cov$breakdowns_nested))
  expect_true("year" %in% names(cov$breakdowns_nested))
})

test_that("B1: sm_coverage_breakdowns accessor filters by dimension", {
  corpus <- sm_example_corpus(n_works = 40, seed = 1)
  ref <- corpus$works[, c("work_id", "doi", "title", "year")]
  names(ref)[1] <- "id"
  cov <- sm_coverage_audit(corpus, ref, by = "year", match = "doi")
  flat <- sm_coverage_breakdowns(cov, dimension = "year")
  expect_true(all(flat$dimension == "year"))
  expect_equal(sm_coverage_breakdowns(cov), cov$breakdowns)
})

# ---- C1: coverage indexability ---------------------------------------------

test_that("C1: index_table adds indexable flags; absent leaves output unchanged", {
  corpus <- sm_example_corpus(n_works = 20, seed = 1)
  idx <- utils::read.csv(
    system.file("extdata", "example_journal_index.csv", package = "scimapR"),
    stringsAsFactors = FALSE
  )
  # make some sources indexable by setting their issn_l to a known indexed ISSN
  corpus$sources$issn_l[1] <- "1078-8956"  # Nature Medicine (print) in fixture
  ref <- corpus$works[1:15, c("work_id", "doi", "title")]
  names(ref)[1] <- "id"

  cov_idx <- sm_coverage_audit(corpus, ref, match = "doi", index_table = idx)
  expect_true(all(c("issn", "indexable") %in% names(cov_idx$matches)))
  expect_s3_class(cov_idx$indexability, "tbl_df")
  expect_true(any(cov_idx$matches$indexable %in% TRUE))

  cov_plain <- sm_coverage_audit(corpus, ref, match = "doi")
  expect_false("indexable" %in% names(cov_plain$matches))
  expect_null(cov_plain$indexability)
})

# ---- B2 / C2: affiliation signal, evidence, summary ------------------------

test_that("C2: affiliation match populates signal and evidence", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 5, seed = 1)
  corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
  corpus$authorships$email <- NA_character_
  corpus$authorships$email[2] <- "a@rki.de"
  m <- suppressMessages(sm_affiliation_match(corpus))
  expect_true(all(c("match_signal", "match_evidence") %in%
                    names(m$authorships)))
  expect_identical(m$authorships$match_signal[1], "name_token")
  expect_identical(m$authorships$match_evidence[1], "Bundeswehrkrankenhaus")
  expect_identical(m$authorships$match_signal[2], "email_domain")
  expect_identical(m$authorships$match_evidence[2], "rki.de")
})

test_that("C2: postcode signal matches when enabled with a postcode dictionary", {
  pcdict <- utils::read.csv(
    system.file("extdata", "example_affiliation_postcode.csv",
                package = "scimapR"),
    stringsAsFactors = FALSE
  )
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3, seed = 2)
  corpus$authorships$raw_affiliation[1] <- "Some Lab, 10115 Berlin, Germany"
  m <- suppressMessages(
    sm_affiliation_match(corpus, patterns = pcdict, postcode_signal = TRUE))
  expect_identical(m$authorships$match_signal[1], "postcode")
  expect_identical(m$authorships$match_evidence[1], "10115")
})

test_that("C2: postcode signal is off by default (no shift in matches)", {
  pcdict <- utils::read.csv(
    system.file("extdata", "example_affiliation_postcode.csv",
                package = "scimapR"),
    stringsAsFactors = FALSE
  )
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3, seed = 2)
  corpus$authorships$raw_affiliation[1] <- "Some Lab, 10115 Berlin, Germany"
  m <- suppressMessages(sm_affiliation_match(corpus, patterns = pcdict))
  expect_identical(m$authorships$match_signal[1], "none")
})

test_that("B2: sm_affiliation_summary mirrors the annotated rows", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 5, seed = 1)
  corpus$authorships$raw_affiliation[1:2] <- c(
    "Bundeswehrkrankenhaus Berlin", "Charite Universitatsmedizin Berlin")
  m <- suppressMessages(sm_affiliation_match(corpus))
  s <- sm_affiliation_summary(m)
  expect_named(s, c("institution", "match_signal", "n_authorships", "n_works"))
  expect_equal(sum(s$n_authorships),
               sum(!is.na(m$authorships$institution_match)))
})

test_that("B2: sm_affiliation_summary warns when no matching was run", {
  corpus <- sm_example_corpus(n_works = 3, seed = 1)
  expect_warning(s <- sm_affiliation_summary(corpus), "No affiliation matches")
  expect_equal(nrow(s), 0L)
})

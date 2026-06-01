# Regression / feature tests for the v0.4.0 refinements.

# ---- A1: accessor stability contract ---------------------------------------

test_that("A1: sm_coverage_breakdowns(tidy=TRUE) has the stable column set", {
  skip_if_not_installed("stringdist")
  corpus <- sm_example_corpus(n_works = 40, seed = 1)
  ref <- corpus$works[, c("work_id", "doi", "title", "year")]
  names(ref)[1] <- "id"
  cov <- sm_coverage_audit(corpus, ref, by = "year", match = "doi")
  tb <- sm_coverage_breakdowns(cov)  # default tidy = TRUE
  expect_named(tb, c("dimension", "level", "n_reference", "n_matched",
                     "recall", "n_corpus", "precision", "f1"))
  # legacy shape preserved under tidy = FALSE
  expect_named(sm_coverage_breakdowns(cov, tidy = FALSE),
               c("dimension", "level", "n_reference", "n_matched", "recall"))
})

test_that("A1: tidy columns are stable regardless of by= and on zero matches", {
  corpus <- sm_example_corpus(n_works = 20, seed = 1)
  ref <- data.frame(id = paste0("Z", 1:5), doi = paste0("10.9/x", 1:5),
                    title = paste("Unrelated", 1:5), year = 2020L)
  cov <- sm_coverage_audit(corpus, ref, by = "year", match = "doi")
  tb <- sm_coverage_breakdowns(cov)
  expect_named(tb, c("dimension", "level", "n_reference", "n_matched",
                     "recall", "n_corpus", "precision", "f1"))
  # no by= at all -> 0-row tibble with the documented columns
  cov2 <- sm_coverage_audit(corpus, ref, match = "doi")
  empty <- sm_coverage_breakdowns(cov2)
  expect_equal(nrow(empty), 0L)
  expect_named(empty, c("dimension", "level", "n_reference", "n_matched",
                        "recall", "n_corpus", "precision", "f1"))
})

# ---- B1: controlled vocabularies -------------------------------------------

test_that("B1: vocabulary helpers return stable level sets", {
  expect_identical(sm_affiliation_signals(),
                   c("name_token", "email_domain", "postcode", "none"))
  expect_identical(sm_match_types(),
                   c("doi", "title", "none"))
  expect_s3_class(sm_affiliation_signals(describe = TRUE), "tbl_df")
  expect_true(all(c("level", "description") %in%
                    names(sm_affiliation_methods(describe = TRUE))))
})

test_that("B1: match_signal/match_method are factors with vocabulary levels", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 5, seed = 1)
  corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
  m <- suppressMessages(sm_affiliation_match(corpus))
  expect_true(is.factor(m$authorships$match_signal))
  expect_identical(levels(m$authorships$match_signal), sm_affiliation_signals())
  expect_true(is.factor(m$authorships$match_method))
  expect_identical(levels(m$authorships$match_method), sm_affiliation_methods())
})

test_that("B1: coverage match_type is a factor with stable levels", {
  corpus <- sm_example_corpus(n_works = 10, seed = 1)
  ref <- corpus$works[1:8, c("work_id", "doi", "title")]
  names(ref)[1] <- "id"
  cov <- sm_coverage_audit(corpus, ref, match = "doi")
  expect_true(is.factor(cov$matches$match_type))
  expect_identical(levels(cov$matches$match_type), sm_match_types())
})

# ---- C1: sm_its impact resolution from a side column -----------------------

test_that("C1: sm_its(cnci) resolves impact from a non-cited_by_count side column", {
  corpus <- sm_example_corpus(n_works = 120, seed = 1)
  corpus$works$rcr <- runif(nrow(corpus$works), 0.5, 2)
  corpus$works$cited_by_count <- NA_integer_   # the recurrence shape
  its <- sm_its(corpus, intervention_year = 2020, outcome = "cnci")
  expect_s3_class(its, "sm_its")
  expect_gte(nrow(its$series), 4L)
})

test_that("C1: sm_its(cnci) resolves impact from a metrics table", {
  corpus <- sm_example_corpus(n_works = 120, seed = 1)
  corpus$works$cited_by_count <- NA_integer_
  corpus$metrics <- tibble::tibble(work_id = corpus$works$work_id,
                                   cnci = runif(nrow(corpus$works), 0.5, 2))
  its <- sm_its(corpus, intervention_year = 2020, outcome = "cnci")
  expect_gte(nrow(its$series), 4L)
})

test_that("C1: sm_its(cnci) errors naming every column when no impact exists", {
  corpus <- sm_example_corpus(n_works = 60, seed = 1)
  corpus$works$cited_by_count <- NA_integer_
  expect_error(
    sm_its(corpus, intervention_year = 2020, outcome = "cnci"),
    "no usable impact data"
  )
})

# ---- C2: sm_count institution matcher fallback -----------------------------

test_that("C2: sm_count(institution) clusters raw affiliations via the matcher", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  corpus$authorships$institution_id <- NA_character_
  corpus$authorships$raw_affiliation <- "Some University"
  corpus$authorships$raw_affiliation[1:6] <- "Bundeswehrkrankenhaus Berlin"
  expect_warning(res <- sm_count(corpus, level = "institution"),
                 "raw_affiliation")
  expect_gt(nrow(res), 0L)
  # the matcher should have canonicalised the Bundeswehr rows
  expect_true("Bundeswehr Hospital" %in% res$entity_id)
})

test_that("C2: sm_count(institution) uses structured IDs when present", {
  corpus <- sm_example_corpus(n_works = 20, seed = 1)
  corpus$authorships$institution_id <- "I1"
  res <- sm_count(corpus, level = "institution")
  expect_equal(nrow(res), 1L)
  expect_identical(res$entity_id, "I1")
})

test_that("C2: sm_count(institution) warns + 0 rows when no institution data", {
  corpus <- sm_example_corpus(n_works = 10, seed = 1)
  corpus$authorships$institution_id <- NA_character_
  corpus$authorships$raw_affiliation <- NA_character_
  expect_warning(res <- sm_count(corpus, level = "institution"),
                 "No institution data")
  expect_equal(nrow(res), 0L)
})

# ---- C3: large-graph precompute, opt-in cap --------------------------------

test_that("C3: a ~2000-node graph builds with precompute and keeps all nodes", {
  skip_on_cran()
  skip_if_not_installed("ggraph")
  big <- sm_example_corpus(n_works = 2000, n_authors = 1500, seed = 1)
  p <- sm_plot_citation_network(big, top_n = 2000, precompute = TRUE)
  expect_s3_class(p, "ggplot")
  expect_false(inherits(p, "ggraph"))
  # re-printing must not invoke heavy layout again (coords are materialised)
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("C3: node cap is opt-in (off by default, no message)", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 60, seed = 1)
  expect_no_message(
    sm_plot_citation_network(corpus, top_n = 60, precompute = TRUE)
  )
  # explicit cap engages with a message
  expect_message(
    sm_plot_citation_network(corpus, top_n = 60, max_nodes = 10,
                             precompute = TRUE),
    "capping"
  )
})

# ---- D1: materialise -------------------------------------------------------

test_that("D1: sm_materialise joins a cached metrics tibble into works", {
  corpus <- sm_example_corpus(n_works = 10, seed = 1)
  metrics <- tibble::tibble(work_id = corpus$works$work_id,
                            cnci = runif(10, 0.5, 2))
  out <- suppressMessages(sm_materialise(corpus, sources = list(works = metrics)))
  expect_true(is_sm_corpus(out))
  expect_true("cnci" %in% names(out$works))
  expect_equal(nrow(out$works), 10L)
})

test_that("D1: overwrite=FALSE only fills NA; overwrite=TRUE replaces", {
  corpus <- sm_example_corpus(n_works = 10, seed = 1)
  corpus$works$cited_by_count[1:3] <- NA_integer_
  enr <- tibble::tibble(work_id = corpus$works$work_id,
                        cited_by_count = rep(999L, 10))
  fill <- suppressMessages(sm_materialise(corpus, sources = list(works = enr)))
  expect_equal(fill$works$cited_by_count[1], 999L)              # was NA -> filled
  expect_equal(fill$works$cited_by_count[4],
               corpus$works$cited_by_count[4])                  # populated kept
  ow <- suppressMessages(
    sm_materialise(corpus, sources = list(works = enr), overwrite = TRUE))
  expect_equal(ow$works$cited_by_count[4], 999L)
})

test_that("D1: NULL/empty source element does not corrupt types; missing key warns", {
  corpus <- sm_example_corpus(n_works = 8, seed = 1)
  metrics <- tibble::tibble(work_id = corpus$works$work_id, cnci = 1.0)
  out <- suppressMessages(
    sm_materialise(corpus, sources = list(works = metrics, sources = NULL)))
  expect_type(out$works$cnci, "double")

  bad <- tibble::tibble(id = 1:8, x = 1:8)
  expect_warning(sm_materialise(corpus, sources = list(works = bad)), "key")
})

test_that("D1: .sm_bind_rows returns the template instead of a logical degenerate", {
  tmpl <- tibble::tibble(a = integer(), b = character())
  out <- .sm_bind_rows(list(NULL, NULL), template = tmpl)
  expect_equal(nrow(out), 0L)
  expect_type(out$a, "integer")
  expect_type(out$b, "character")
})

# ---- E1 / F1: self-citation ------------------------------------------------

sc_corpus <- function() {
  works <- tibble::tibble(work_id = paste0("W", 1:4), title = paste("T", 1:4),
                          year = c(2018L, 2019L, 2020L, 2021L),
                          doi = paste0("10.1/", 1:4),
                          cited_by_count = c(10L, 5L, 3L, 2L))
  aus <- tibble::tibble(
    work_id = c("W1", "W2", "W3", "W4", "W2"),
    author_id = c("A1", "A1", "A2", "A3", "A2"),
    position = c(1L, 1L, 1L, 1L, 2L))
  refs <- tibble::tibble(work_id = c("W2", "W3", "W4"), ref_index = 1:3,
                         cited_work_id = c("W1", "W1", "W2"),
                         cited_doi = NA_character_, cited_raw = NA_character_)
  suppressMessages(sm_corpus_from_tables(
    list(works = works, authorships = aus, references = refs)))
}

test_that("E1: sm_self_citation identifies reference-overlap self-citations", {
  sc <- sm_self_citation(sc_corpus(), level = "author")
  expect_s3_class(sc, "sm_self_citation")
  a1 <- sc$by_entity[sc$by_entity$entity_id == "A1", ]
  expect_equal(a1$n_self_citations, 1L)        # W2 -> W1, both A1
  expect_named(sc$by_entity, c("entity_id", "n_citations_received",
                               "n_self_citations", "self_citation_share"))
})

test_that("F1: self-citation provenance names the shared author and works", {
  sc <- sm_self_citation(sc_corpus(), level = "author")
  expect_named(sc$provenance,
               c("citing_work_id", "cited_work_id", "shared_author_id"))
  expect_equal(nrow(sc$provenance), 1L)
  expect_identical(sc$provenance$citing_work_id, "W2")
  expect_identical(sc$provenance$cited_work_id, "W1")
  expect_identical(sc$provenance$shared_author_id, "A1")
})

test_that("E1: institution level uses shared_institution_id provenance column", {
  corpus <- sc_corpus()
  corpus$authorships$institution_id <- c("I1", "I1", "I2", "I3", "I2")
  sc <- sm_self_citation(corpus, level = "institution")
  expect_true("shared_institution_id" %in% names(sc$provenance))
})

test_that("E1: empty references fast-exit with a warning and typed columns", {
  corpus <- sc_corpus()
  corpus$references <- corpus$references[0, ]
  expect_warning(sc <- sm_self_citation(corpus), "reference network")
  expect_equal(nrow(sc$by_entity), 0L)
  expect_named(sc$provenance,
               c("citing_work_id", "cited_work_id", "shared_author_id"))
})

# ---- E2: self-corrected indices --------------------------------------------

test_that("E2: self_corrected h-index is <= uncorrected and reduces as expected", {
  # A1 has two works each cited twice; W2 self-cites W1 -> corrected W1 = 1
  works <- tibble::tibble(work_id = c("W1", "W2"), title = c("a", "b"),
                          year = c(2018L, 2019L), doi = c("10.1/1", "10.1/2"),
                          cited_by_count = c(2L, 2L))
  aus <- tibble::tibble(work_id = c("W1", "W2"), author_id = c("A1", "A1"),
                        position = c(1L, 1L))
  refs <- tibble::tibble(work_id = "W2", ref_index = 1L, cited_work_id = "W1",
                         cited_doi = NA_character_, cited_raw = NA_character_)
  corpus <- suppressMessages(sm_corpus_from_tables(
    list(works = works, authorships = aus, references = refs)))
  unc <- sm_metric_h_index(corpus, "author")
  cor <- sm_metric_h_index(corpus, "author", self_corrected = TRUE)
  expect_lte(cor$h_index[cor$author_id == "A1"],
             unc$h_index[unc$author_id == "A1"])
  expect_equal(cor$h_index[cor$author_id == "A1"], 1L)
})

test_that("E2: self_corrected errors for non-author/institution levels", {
  corpus <- sc_corpus()
  expect_error(sm_metric_h_index(corpus, level = "source",
                                 self_corrected = TRUE),
               "only available")
})

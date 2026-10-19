# Tests for R/metric-fnci.R (sm_metric_fnci and .assign_field).

test_that("sm_metric_fnci rejects a non-corpus input", {
  expect_error(sm_metric_fnci(list()), class = "rlang_error")
})

test_that("sm_metric_fnci validates the classification argument", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_metric_fnci(corpus, classification = "scopus"),
    class = "rlang_error"
  )
})

test_that("sm_metric_fnci returns an empty tibble for an empty corpus", {
  corpus <- sm_example_corpus(n_works = 0, n_authors = 2,
                              with_embeddings = FALSE, seed = 2)
  out <- sm_metric_fnci(corpus)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("work_id", "field", "year", "cited_by_count",
                      "field_mean", "fnci"))
})

test_that("openalex_concepts classification yields numeric FNCI values", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 12,
                              with_embeddings = FALSE, seed = 3)
  out <- sm_metric_fnci(corpus, classification = "openalex_concepts")
  expect_equal(nrow(out), nrow(corpus$works))
  expect_true(all(corpus$works$work_id %in% out$work_id))
  expect_true(is.numeric(out$fnci))
  expect_true(is.numeric(out$field_mean))
  # At least some finite FNCI values are produced.
  expect_true(any(is.finite(out$fnci)))
  # cited_by_count is carried through correctly.
  expect_equal(
    out$cited_by_count[match(corpus$works$work_id, out$work_id)],
    corpus$works$cited_by_count
  )
})

test_that("FNCI is computed as cited_by_count / field-year mean", {
  # Build a tiny controlled corpus: a single field, single year, known counts.
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  corpus$works$year <- 2020L
  corpus$works$cited_by_count <- c(0L, 10L, 20L, 10L)  # mean = 10
  corpus$works$field <- "F"

  out <- sm_metric_fnci(corpus, classification = "manual")
  ord <- match(corpus$works$work_id, out$work_id)
  expect_equal(out$field_mean[ord], rep(10, 4))
  expect_equal(out$fnci[ord], c(0, 1, 2, 1))
})

test_that("manual classification errors when no field column exists", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 5)
  expect_false("field" %in% names(corpus$works))
  expect_error(
    sm_metric_fnci(corpus, classification = "manual"),
    "field"
  )
})

test_that("openalex_concepts with empty concepts gives unclassified field", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 6)
  corpus$concepts <- corpus$concepts[0, ]
  out <- sm_metric_fnci(corpus, classification = "openalex_concepts")
  expect_true(all(out$field == "unclassified"))
})

test_that("mesh classification falls back to unclassified without MeSH terms", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE, seed = 7)
  # Synthetic concepts use vocabulary "openalex", not mesh/medline.
  expect_message(
    out <- sm_metric_fnci(corpus, classification = "mesh"),
    "No MeSH terms"
  )
  expect_true(all(out$field == "unclassified"))
})

test_that("mesh classification uses MeSH concepts when present", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 8)
  corpus$concepts <- tibble::tibble(
    work_id = corpus$works$work_id,
    concept_id = "M1",
    concept_name = "Neoplasms",
    level = 1L,
    score = 0.9,
    vocabulary = "mesh"
  )
  out <- sm_metric_fnci(corpus, classification = "mesh")
  expect_true(all(out$field == "Neoplasms"))
})

test_that("mesh classification finds MeSH concepts under other spellings", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 8)
  # Direct assignment bypasses sm_corpus(), so the spelling stays as written.
  corpus$concepts <- tibble::tibble(
    work_id = corpus$works$work_id,
    concept_id = "M1",
    concept_name = "Neoplasms",
    level = NA_integer_,
    score = 1,
    vocabulary = c("MeSH Terms", "MEDLINE", " mesh", "MeSH")
  )
  out <- sm_metric_fnci(corpus, classification = "mesh")
  expect_true(all(out$field == "Neoplasms"))
})

test_that("mesh classification with empty concepts gives unclassified field", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 9)
  corpus$concepts <- corpus$concepts[0, ]
  out <- sm_metric_fnci(corpus, classification = "mesh")
  expect_true(all(out$field == "unclassified"))
})

test_that("FNCI is NA when the field-year mean is zero", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 10)
  corpus$works$year <- 2021L
  corpus$works$cited_by_count <- c(0L, 0L, 0L)  # mean = 0
  corpus$works$field <- "Z"
  out <- sm_metric_fnci(corpus, classification = "manual")
  expect_true(all(is.na(out$fnci)))
})

test_that("the default result keeps its six columns", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 12,
                              with_embeddings = FALSE, seed = 3)
  out <- suppressMessages(sm_metric_fnci(corpus))
  expect_named(out, c("work_id", "field", "year", "cited_by_count",
                      "field_mean", "fnci"))
})

test_that("a factor field is reported by its labels", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE, seed = 4)
  corpus$works$year <- 2020L
  corpus$works$cited_by_count <- c(1L, 3L, 2L, 6L)
  corpus$works$field <- factor(c("Gamma", "Beta", "Gamma", "Beta"))
  out <- suppressMessages(sm_metric_fnci(corpus, classification = "manual"))
  out <- out[match(corpus$works$work_id, out$work_id), ]
  expect_identical(out$field, c("Gamma", "Beta", "Gamma", "Beta"))
  expect_equal(out$field_mean, c(1.5, 4.5, 1.5, 4.5))
})

# ---- small cells, fallback baselines, several categories, types ------------

fnci_corpus <- function(field, year, cites, type = "Article") {
  n <- max(lengths(list(field, year, cites, type)))
  works <- tibble::tibble(
    work_id = sprintf("W%02d", seq_len(n)),
    title = paste("Synthetic work", seq_len(n)),
    year = rep_len(as.integer(year), n),
    type = rep_len(type, n),
    cited_by_count = rep_len(as.integer(cites), n),
    field = rep_len(field, n)
  )
  scimapR::sm_corpus(works = works)
}

# Let a test focus on one message: drop the small-cell one.
quiet_cells <- function(expr) {
  suppressMessages(expr, classes = "scimapR_fnci_small_cells")
}

count_class <- function(expr, class) {
  n <- 0L
  withCallingHandlers(expr, condition = function(cnd) {
    if (inherits(cnd, class)) {
      n <<- n + 1L
      rlang::cnd_muffle(cnd)
    }
  })
  n
}

test_that("sm_metric_fnci informs once when many works sit in small cells", {
  small <- fnci_corpus(paste("Field", 1:12), 2020, 1:12)
  expect_identical(
    count_class(sm_metric_fnci(small, classification = "manual"),
                "scimapR_fnci_small_cells"),
    1L
  )
  expect_message(sm_metric_fnci(small, classification = "manual"),
                 "100%", class = "scimapR_fnci_small_cells")
  expect_no_message(
    sm_metric_fnci(small, classification = "manual", min_cell = 3),
    class = "scimapR_fnci_small_cells"
  )
  # 12 works in one cell and 3 alone: 20% in small cells, no message
  large <- fnci_corpus(c(rep("Field 1", 12), paste("Field", 2:4)), 2020,
                       1:15)
  expect_no_message(sm_metric_fnci(large, classification = "manual"),
                    class = "scimapR_fnci_small_cells")
})

test_that("min_cell falls back from field-year to field +/- 1 year to year", {
  corpus <- fnci_corpus(
    field = c("A", "A", "A", "A", "B", "C", NA, "D", "A", "A"),
    year = c(2020, 2020, 2020, 2021, 2021, 2021, 2020, 2015, NA, 2020),
    cites = c(2, 4, 6, 8, 3, 1, 10, 5, 4, NA)
  )
  out <- sm_metric_fnci(corpus, classification = "manual", min_cell = 3)
  expect_named(out, c("work_id", "field", "year", "cited_by_count",
                      "field_mean", "fnci", "n_cell", "baseline"))
  out <- out[match(corpus$works$work_id, out$work_id), ]
  expect_s3_class(out$baseline, "factor")
  expect_identical(levels(out$baseline),
                   c("field_year", "field_year_pm1", "year", "none"))
  expect_identical(
    as.character(out$baseline),
    c("field_year", "field_year", "field_year", "field_year_pm1", "year",
      "year", "year", "none", NA, "field_year")
  )
  expect_equal(out$field_mean, c(4, 4, 4, 5, 4, 4, 5.5, NA, NA, 4))
  expect_equal(out$fnci, c(0.5, 1, 1.5, 1.6, 0.75, 0.25, 1.8182, NA, NA, NA))
  expect_identical(out$n_cell, c(3L, 3L, 3L, 4L, 3L, 3L, 4L, 1L, NA, 3L))
  expect_identical(out$field[7], "unclassified")
})

test_that("min_cell = 1 reproduces the default field-year baselines", {
  corpus <- fnci_corpus(c("A", "A", "B", "B", "B"),
                        c(2020, 2020, 2020, 2021, 2021), c(1, 3, 5, 2, 4))
  default <- suppressMessages(sm_metric_fnci(corpus, "manual"))
  one <- sm_metric_fnci(corpus, "manual", min_cell = 1)
  expect_equal(one[names(default)], default)
  expect_true(all(one$baseline == "field_year"))
})

test_that("min_cell averages the baselines of several categories", {
  corpus <- fnci_corpus(
    field = c("A; B", "A", "B", "A; D", "A", "E;F", "G"),
    year = c(2020, 2020, 2020, 2021, 2021, 2025, 2025),
    cites = c(9, 1, 11, 4, 6, 3, 5)
  )
  out <- sm_metric_fnci(corpus, classification = "manual", min_cell = 2)
  out <- out[match(corpus$works$work_id, out$work_id), ]
  # W01: A (mean 5) and B (mean 10) both reach a field-year cell, so the
  # baseline is their average 7.5 (not the average of the two ratios)
  expect_equal(out$field_mean, c(7.5, 5, 10, 5, 5, 4, 4))
  expect_equal(out$fnci, c(1.2, 0.2, 1.1, 0.8, 1.2, 0.75, 1.25))
  expect_identical(
    as.character(out$baseline),
    c("field_year", "field_year", "field_year", "field_year", "field_year",
      "year", "year")
  )
  expect_identical(out$n_cell, c(2L, 2L, 2L, 2L, 2L, 2L, 2L))
  expect_identical(out$field[c(1, 6)], c("A; B", "E;F"))
  # without min_cell the field string is one category, as before
  default <- suppressMessages(sm_metric_fnci(corpus, "manual"))
  expect_identical(default$fnci[default$work_id == "W01"], 1)
})

test_that("min_cell and by_type keep a typed 0-row result", {
  corpus <- sm_corpus(works = .empty_works())
  out <- sm_metric_fnci(corpus, min_cell = 5)
  expect_named(out, c("work_id", "field", "year", "cited_by_count",
                      "field_mean", "fnci", "n_cell", "baseline"))
  expect_type(out$n_cell, "integer")
  expect_identical(levels(out$baseline),
                   c("field_year", "field_year_pm1", "year", "none"))
  out <- sm_metric_fnci(corpus, min_cell = 5, by_type = TRUE)
  expect_named(out, c("work_id", "field", "year", "cited_by_count",
                      "field_mean", "fnci", "doc_type", "n_cell",
                      "baseline"))
  expect_type(out$doc_type, "character")
})

test_that("sm_metric_fnci validates min_cell and by_type", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 4,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_metric_fnci(corpus, min_cell = 0), "min_cell")
  expect_error(sm_metric_fnci(corpus, min_cell = c(2, 3)), "min_cell")
  expect_error(sm_metric_fnci(corpus, min_cell = "3"), "min_cell")
  expect_error(sm_metric_fnci(corpus, by_type = NA), "by_type")
})

test_that(".normalise_doc_type maps reader types to article and review", {
  raw <- c("Article", "journal-article", "JOUR", "research-article",
           "Review", "review article", "Article; Proceedings Paper",
           "Review; Early Access", " Editorial Material ", "letter",
           "Proceedings Paper", NA, "")
  expect_identical(
    .normalise_doc_type(raw),
    c(rep("article", 4), "review", "review", "article", "review",
      rep(NA_character_, 5))
  )
  example <- sm_example_corpus(n_works = 60, seed = 1)$works$type
  expect_setequal(unique(example), c("journal-article", "review", "letter"))
  expect_identical(.normalise_doc_type(example) == "article",
                   ifelse(example == "letter", NA,
                          example == "journal-article"))
})

test_that("by_type splits cells by document type; other types get NA", {
  corpus <- fnci_corpus(
    field = "F", year = 2020, cites = c(2, 4, 10, 20, 3),
    type = c("Article", "Article", "Review", "Review",
             "Editorial Material")
  )
  expect_identical(
    count_class(quiet_cells(sm_metric_fnci(corpus, "manual", by_type = TRUE)),
                "scimapR_fnci_other_types"),
    1L
  )
  expect_message(
    out <- quiet_cells(sm_metric_fnci(corpus, "manual", by_type = TRUE)),
    "Editorial Material", class = "scimapR_fnci_other_types"
  )
  out <- out[match(corpus$works$work_id, out$work_id), ]
  expect_identical(out$doc_type, c("article", "article", "review", "review",
                                   NA))
  expect_equal(out$field_mean, c(3, 3, 15, 15, NA))
  expect_equal(out$fnci, c(0.6667, 1.3333, 0.6667, 1.3333, NA))

  # the type stays part of the cell at every fallback level
  corpus <- fnci_corpus(
    field = c("A", "B", "C", "D", "E"), year = 2020,
    cites = c(2, 4, 10, 20, 30),
    type = c("Article", "Article", "Review", "Review", "Review")
  )
  out <- sm_metric_fnci(corpus, "manual", min_cell = 2, by_type = TRUE)
  out <- out[match(corpus$works$work_id, out$work_id), ]
  expect_identical(as.character(out$baseline), rep("year", 5))
  expect_equal(out$field_mean, c(3, 3, 20, 20, 20))
  expect_identical(out$n_cell, c(2L, 2L, 3L, 3L, 3L))
})

# ---- MeSH fields -------------------------------------------------------------

mesh_corpus <- function(headings, score = NA_real_) {
  ids <- sprintf("W%02d", seq_along(headings))
  works <- tibble::tibble(work_id = ids, title = paste("Work", ids),
                          year = 2020L, cited_by_count = 1L)
  concepts <- tibble::tibble(
    work_id = rep(ids, lengths(headings)),
    concept_id = NA_character_,
    concept_name = unlist(headings),
    level = NA_integer_,
    score = score,
    vocabulary = "mesh"
  )
  scimapR::sm_corpus(works = works, concepts = concepts)
}

test_that("mesh classification skips check tags when headings are unscored", {
  corpus <- mesh_corpus(list(
    c("Adult", "Breast Neoplasms", "Female", "Humans"),
    c("Aged", "Breast Neoplasms", "Humans"),
    c("Aged, 80 and over", "Humans", "Male"),
    c("History, 20th Century", "Mice")
  ))
  expect_message(
    out <- quiet_cells(sm_metric_fnci(corpus, classification = "mesh")),
    class = "scimapR_fnci_mesh_unscored"
  )
  out <- out[match(corpus$works$work_id, out$work_id), ]
  expect_identical(out$field, c("Breast Neoplasms", "Breast Neoplasms",
                                "unclassified", "unclassified"))
})

test_that("unscored MeSH works take their most frequent heading", {
  corpus <- mesh_corpus(list(
    c("Antibodies, Viral", "Zoonoses"),
    c("Rodent Diseases", "Zoonoses"),
    c("Hantavirus Infections", "Zoonoses"),
    c("Antibodies, Viral", "Hantavirus Infections", "Zoonoses")
  ))
  out <- suppressMessages(sm_metric_fnci(corpus, classification = "mesh"))
  expect_true(all(out$field == "Zoonoses"))
})

test_that("a study-design heading shared by every work is never the field", {
  corpus <- mesh_corpus(list(
    c("Adult", "Breast Neoplasms", "Female", "Humans",
      "Retrospective Studies"),
    c("Aged", "Breast Neoplasms", "Humans", "Prognosis",
      "Retrospective Studies"),
    c("Aged", "Heart Failure", "Humans", "Male", "Retrospective Studies"),
    c("Heart Failure", "Humans", "Middle Aged", "Retrospective Studies",
      "Risk Factors"),
    c("Humans", "Retrospective Studies", "Schizophrenia", "Young Adult"),
    c("Humans", "Retrospective Studies", "Treatment Outcome")
  ))
  expect_message(
    out <- quiet_cells(sm_metric_fnci(corpus, classification = "mesh")),
    "Retrospective Studies", class = "scimapR_fnci_mesh_unscored"
  )
  out <- out[match(corpus$works$work_id, out$work_id), ]
  expect_identical(out$field, c("Breast Neoplasms", "Breast Neoplasms",
                                "Heart Failure", "Heart Failure",
                                "Schizophrenia", "unclassified"))
})

test_that("major-topic scores pick a major topic, ties by corpus frequency", {
  # scores as the PubMed readers record them: 1 = major topic, 0 = not
  corpus <- mesh_corpus(
    list(
      c("Antineoplastic Agents", "Breast Neoplasms", "Humans",
        "Retrospective Studies"),
      c("Breast Neoplasms", "Humans", "Retrospective Studies"),
      c("Heart Failure", "Humans", "Retrospective Studies", "Risk Factors")
    ),
    score = c(1, 1, 0, 0,
              1, 0, 1,
              1, 0, 0, 0)
  )
  expect_no_message(
    out <- quiet_cells(sm_metric_fnci(corpus, classification = "mesh")),
    class = "scimapR_fnci_mesh_unscored"
  )
  out <- out[match(corpus$works$work_id, out$work_id), ]
  # W01 has two major topics; Breast Neoplasms is the one more works carry
  expect_identical(out$field,
                   c("Breast Neoplasms", "Breast Neoplasms", "Heart Failure"))
})

test_that("scored MeSH headings keep the highest score without a message", {
  corpus <- mesh_corpus(list(c("Humans", "Zoonoses"),
                             c("Neoplasms", "Zoonoses")),
                        score = c(0.9, 0.2, 0.8, 0.3))
  expect_no_message(
    out <- quiet_cells(sm_metric_fnci(corpus, classification = "mesh")),
    class = "scimapR_fnci_mesh_unscored"
  )
  out <- out[match(corpus$works$work_id, out$work_id), ]
  expect_identical(out$field, c("Zoonoses", "Neoplasms"))
})

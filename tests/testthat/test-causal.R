# Tests for Part C: ITS, DiD, synthetic control.

test_that("sm_its fits a segmented regression and returns tidy coefficients", {
  corpus <- sm_example_corpus(n_works = 200, seed = 1)
  its <- sm_its(corpus, intervention_year = 2020, outcome = "count")
  expect_s3_class(its, "sm_its")
  expect_s3_class(its$model, "glm")
  expect_identical(its$family, "poisson")
  expect_named(its$coefficients,
               c("term", "estimate", "std.error", "conf.low", "conf.high",
                 "statistic", "p.value"))
  expect_setequal(its$coefficients$term,
                  c("(Intercept)", "time", "intervention", "time_since"))
  expect_named(its$series, c("year", "observed", "fitted", "counterfactual"))
})

test_that("sm_its counterfactual equals fitted in the pre-period", {
  corpus <- sm_example_corpus(n_works = 200, seed = 1)
  its <- sm_its(corpus, intervention_year = 2020, outcome = "count")
  pre <- dplyr::filter(its$series, .data$year < 2020)
  expect_equal(pre$fitted, pre$counterfactual, tolerance = 1e-8)
})

test_that("sm_its excludes citation-immature years for cnci", {
  corpus <- sm_example_corpus(n_works = 200, seed = 1)
  its <- sm_its(corpus, intervention_year = 2019, outcome = "cnci", lag = 2)
  max_year <- max(corpus$works$year, na.rm = TRUE)
  expect_true(all(its$provisional_years > max_year - 2))
  expect_false(any(its$series$year %in% its$provisional_years))
})

test_that("sm_its respects a custom family", {
  corpus <- sm_example_corpus(n_works = 100, seed = 1)
  its <- sm_its(corpus, intervention_year = 2020, outcome = "count",
                family = "gaussian")
  expect_identical(its$family, "gaussian")
})

test_that("sm_its errors with too few years", {
  corpus <- sm_example_corpus(n_works = 10, year_range = c(2020L, 2021L),
                              seed = 1)
  expect_error(sm_its(corpus, intervention_year = 2021, outcome = "count"),
               "Too few")
})

test_that("sm_its autoplot returns a ggplot", {
  corpus <- sm_example_corpus(n_works = 100, seed = 1)
  its <- sm_its(corpus, intervention_year = 2020, outcome = "count")
  expect_s3_class(ggplot2::autoplot(its), "ggplot")
  expect_s3_class(summary(its), "tbl_df")
})

# ---- DiD --------------------------------------------------------------------

did_corpus <- function() {
  corpus <- sm_example_corpus(n_works = 150, seed = 1)
  corpus$authorships$institution_name <- rep(
    c("Inst A", "Inst B"), length.out = nrow(corpus$authorships))
  corpus
}

test_that("sm_did estimates the interaction term", {
  corpus <- did_corpus()
  did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
                intervention_year = 2020, outcome = "count")
  expect_s3_class(did, "sm_did")
  expect_true(grepl(":", did$did_estimate$term))
  expect_named(did$did_estimate,
               c("term", "estimate", "std.error", "conf.low", "conf.high",
                 "p.value"))
  expect_true(all(c("control", "treated") %in% levels(did$series$group)))
})

test_that("sm_did autoplot and summary work", {
  corpus <- did_corpus()
  did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
                intervention_year = 2020, outcome = "count")
  expect_s3_class(ggplot2::autoplot(did), "ggplot")
  expect_s3_class(summary(did), "tbl_df")
})

test_that("sm_did errors when a group resolves to no works", {
  corpus <- sm_example_corpus(n_works = 20, seed = 1)
  # institution columns exist (all NA), so unknown labels resolve to 0 works
  expect_error(
    sm_did(corpus, treated = "X", control = "Y", intervention_year = 2020),
    "Both groups must contain works"
  )
})

# ---- synthetic control ------------------------------------------------------

test_that("sm_synth errors gracefully without tidysynth", {
  skip_if(rlang::is_installed("tidysynth"))
  corpus <- did_corpus()
  expect_snapshot(
    sm_synth(corpus, treated = "Inst A", donors = "Inst B",
             intervention_year = 2020, outcome = "count"),
    error = TRUE
  )
})

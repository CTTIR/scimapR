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

# ---- yearly series ----------------------------------------------------------

# A corpus with one work per element of `years`; with `group`, every
# authorship of work i belongs to the institution group[i].
year_corpus <- function(years, group = NULL) {
  corpus <- sm_example_corpus(n_works = length(years), seed = 1)
  corpus$works$year <- as.integer(years)
  if (!is.null(group)) {
    a <- corpus$authorships
    corpus$authorships$institution_name <-
      group[match(a$work_id, corpus$works$work_id)]
  }
  corpus
}

test_that("a share_q1 year without quartiles is dropped and reported", {
  corpus <- year_corpus(rep(2016:2020, each = 4))
  corpus$works$quartile <- rep(c("Q1", "Q2", "Q1", NA), 5)
  corpus$works$quartile[corpus$works$year == 2018L] <- NA
  res <- .sm_yearly_outcome(corpus, "share_q1")
  expect_named(res, c("series", "dropped_years"))
  expect_identical(res$dropped_years, 2018L)
  expect_identical(res$series$year, c(2016L, 2017L, 2019L, 2020L))
  # the share is over works with a quartile; n_works counts every work
  expect_equal(res$series$value, rep(2 / 3, 4))
  expect_identical(res$series$n_works, rep(4L, 4))
})

test_that("the count outcome counts years without works as zero", {
  # 3, 0, 4, 0, 5 works in 2016-2020 are five yearly counts, not three
  corpus <- year_corpus(rep(c(2016L, 2018L, 2020L), c(3, 4, 5)))
  res <- .sm_yearly_outcome(corpus, "count")
  expect_identical(res$series$year, 2016:2020)
  expect_identical(res$series$value, c(3, 0, 4, 0, 5))
  expect_identical(res$series$n_works, c(3L, 0L, 4L, 0L, 5L))
  expect_identical(res$dropped_years, integer())
  its <- sm_its(corpus, intervention_year = 2018, outcome = "count",
                family = "quasipoisson")
  expect_identical(its$series$observed, c(3, 0, 4, 0, 5))
  expect_identical(its$dropped_years, integer())
  # a group's counts run over the corpus years, too
  ids <- corpus$works$work_id[corpus$works$year == 2018L]
  res <- .sm_yearly_outcome(corpus, "count", work_ids = ids)
  expect_identical(res$series$value, c(0, 0, 4, 0, 0))
})

test_that("sm_its drops a year without a finite outcome, warning once", {
  withr::local_seed(11)
  corpus <- year_corpus(rep(2015:2024, each = 6))
  corpus$works$quartile <- sample(c("Q1", "Q2", "Q3"), 60, replace = TRUE)
  corpus$works$quartile[corpus$works$year == 2024L] <- NA
  expect_warning(its <- sm_its(corpus, 2020, "share_q1"), "2024",
                 class = "scimapR_dropped_years")
  expect_length(testthat::capture_warnings(sm_its(corpus, 2020, "share_q1")),
                1L)
  expect_identical(its$dropped_years, 2024L)
  expect_identical(its$series$year, 2015:2023)
  # fitted, observed and counterfactual come from the same modelled years
  expect_equal(its$series$fitted, unname(stats::fitted(its$model)))
  expect_equal(its$series$observed, unname(its$model$y))
  out <- cli::cli_fmt(print(its))
  expect_true(any(grepl("Dropped (no usable data): 2024", out,
                        fixed = TRUE)))
})

test_that("sm_its drops a year whose impact values are all infinite", {
  withr::local_seed(12)
  corpus <- year_corpus(rep(2015:2024, each = 5))
  corpus$metadata$last_refresh <- as.POSIXct("2026-06-30", tz = "UTC")
  corpus$works$cnci <- stats::runif(50, 0.5, 2)
  corpus$works$cnci[corpus$works$year == 2017L] <- Inf
  # a single infinite value is left out of its year's mean
  corpus$works$cnci[corpus$works$year == 2019L][1] <- Inf
  expect_warning(its <- sm_its(corpus, 2020, "cnci"), "2017",
                 class = "scimapR_dropped_years")
  expect_identical(its$dropped_years, 2017L)
  expect_identical(its$provisional_years, integer())
  y2019 <- corpus$works$cnci[corpus$works$year == 2019L][-1]
  expect_equal(its$series$observed[its$series$year == 2019L], mean(y2019))
})

test_that("sm_its reports unusable and citation-immature years apart", {
  # A copy without fwci, so the impact stays the FNCI derived from
  # cited_by_count whatever impact columns the resolver reads.
  fix <- realuse_corpus()
  fix$works$fwci <- NULL
  fix$works$cited_by_count[fix$works$year == 2019L] <- NA
  expect_warning(its <- sm_its(fix, 2021, "cnci", lag = 2), "2019",
                 class = "scimapR_dropped_years")
  # last_refresh is in 2026, so 2025 and 2026 are citation-immature
  expect_identical(its$dropped_years, 2019L)
  expect_identical(its$provisional_years, c(2025L, 2026L))
  expect_identical(its$series$year, c(2016:2018, 2020:2024))
  out <- cli::cli_fmt(print(its))
  expect_true(any(grepl("Dropped (no usable data): 2019", out,
                        fixed = TRUE)))
  expect_true(any(grepl("citation-immature", out, fixed = TRUE)))

  # a citation-immature year without usable impact counts as dropped only
  fix$works$cited_by_count[fix$works$year == 2026L] <- NA
  expect_warning(its <- sm_its(fix, 2021, "cnci", lag = 2), "2026",
                 class = "scimapR_dropped_years")
  expect_identical(its$dropped_years, c(2019L, 2026L))
  expect_identical(its$provisional_years, 2025L)
})

test_that("sm_its counts the years left after the citation-immature cut", {
  corpus <- sm_example_corpus(n_works = 100, year_range = c(2020L, 2024L),
                              seed = 1)
  corpus$metadata$last_refresh <- as.POSIXct("2024-06-30", tz = "UTC")
  # five years, of which 2023 and 2024 are citation-immature: three remain
  expect_message(
    expect_error(sm_its(corpus, 2022, "cnci", lag = 2), "Too few"),
    class = "scimapR_fnci_small_cells"
  )
})

test_that("sm_its needs two years before and two from the intervention", {
  corpus <- sm_example_corpus(n_works = 200, seed = 1)
  corpus$metadata$last_refresh <- as.POSIXct("2024-06-30", tz = "UTC")
  # 2023 and 2024 are citation-immature, so no year from 2023 on is left
  expect_message(
    expect_error(sm_its(corpus, 2023, "cnci", lag = 2),
                 "0 from it on"),
    class = "scimapR_fnci_small_cells"
  )
  expect_error(sm_its(corpus, 2016, "count"), "1 before 2016")
  expect_error(sm_its(corpus, 2024, "count"), "Too few")
  expect_error(sm_its(corpus, 2030, "count"), "Too few")
  expect_error(sm_its(corpus, 2010, "count"), "Too few")
  its <- sm_its(corpus, 2017, "count")
  expect_setequal(its$coefficients$term,
                  c("(Intercept)", "time", "intervention", "time_since"))
})

test_that("a model with aliased segment terms aborts", {
  df <- data.frame(value = c(1, 3, 2, 4), time = 0:3,
                   intervention = 0L, time_since = 0L)
  fit <- stats::glm(value ~ time + intervention + time_since, data = df)
  expect_error(.sm_check_identified(fit, "ITS"), "intervention")
})

test_that("ITS intervals use the quantiles of their p-values", {
  corpus <- sm_example_corpus(n_works = 200, seed = 1)
  # Gaussian: estimated dispersion, so t on the residual degrees of freedom
  its <- sm_its(corpus, 2020, "count", family = "gaussian")
  cf <- its$coefficients
  rdf <- stats::df.residual(its$model)
  half <- stats::qt(0.975, rdf) * cf$std.error
  expect_equal(cf$conf.high - cf$estimate, half)
  expect_equal(cf$estimate - cf$conf.low, half)
  expect_equal(cf$p.value, 2 * stats::pt(-abs(cf$statistic), rdf))
  # Poisson fixes the dispersion at 1: normal quantiles, as for its z values
  cf <- sm_its(corpus, 2020, "count")$coefficients
  half <- stats::qnorm(0.975) * cf$std.error
  expect_equal(cf$conf.high - cf$estimate, half)
})

test_that("an overdispersed Poisson count model warns", {
  counts <- c(2, 30, 3, 25, 4, 40, 5, 35, 6, 45)
  corpus <- year_corpus(rep(2015:2024, counts))
  expect_warning(its <- sm_its(corpus, 2020, "count"), "quasipoisson",
                 class = "scimapR_overdispersion")
  expect_no_warning(
    quasi <- sm_its(corpus, 2020, "count", family = "quasipoisson")
  )
  expect_identical(quasi$family, "quasipoisson")
  expect_equal(quasi$coefficients$estimate, its$coefficients$estimate)
  expect_true(all(quasi$coefficients$std.error >
                    its$coefficients$std.error))
  # counts close to a smooth trend do not warn
  expect_no_warning(sm_its(sm_example_corpus(n_works = 200, seed = 1),
                           2020, "count"))
})

test_that("an ITS on 4 years warns when its dispersion is estimated", {
  # 4 coefficients on 4 years: a Gaussian fit leaves no residual degrees of
  # freedom, so its standard errors, intervals and p-values are NaN
  withr::local_seed(13)
  corpus <- year_corpus(rep(2019:2022, each = 10))
  corpus$works$quartile <- sample(c("Q1", "Q2"), 40, replace = TRUE)
  expect_warning(its <- sm_its(corpus, 2021, "share_q1"),
                 "no residual degrees of freedom",
                 class = "scimapR_no_residual_df")
  expect_equal(stats::df.residual(its$model), 0)
  expect_true(all(is.finite(its$coefficients$estimate)))
  expect_true(all(is.nan(its$coefficients$std.error)))
  expect_true(all(is.nan(its$coefficients$conf.low)))
  expect_warning(sm_its(corpus, 2021, "count", family = "quasipoisson"),
                 class = "scimapR_no_residual_df")
  # Poisson fixes the dispersion, so its standard errors stay finite
  expect_no_warning(its <- sm_its(corpus, 2021, "count"))
  expect_true(all(is.finite(its$coefficients$std.error)))
  # a fifth year leaves one residual degree of freedom
  corpus <- year_corpus(rep(2019:2023, each = 10))
  corpus$works$quartile <- sample(c("Q1", "Q2"), 50, replace = TRUE)
  expect_no_warning(its <- sm_its(corpus, 2021, "share_q1"))
  expect_true(all(is.finite(its$coefficients$std.error)))
  expect_true(all(is.finite(its$coefficients$p.value)))
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

test_that("the causal functions need a single intervention year", {
  corpus <- did_corpus()
  # fractional, missing or out-of-range years, and values whose internal
  # numbers are no years (TRUE is 1, a factor its level code, a date days)
  bad <- list(NA, NA_integer_, NA_real_, Inf, 2020.5, TRUE, c(2019, 2021),
              "2020.5", "a year", factor("2020"), as.Date("2020-01-01"),
              1e10)
  for (iy in bad) {
    expect_error(sm_its(corpus, iy, "count"), "single year")
    expect_error(
      sm_did(corpus, treated = "Inst A", control = "Inst B",
             intervention_year = iy, outcome = "count"),
      "single year"
    )
  }
  # text holding a whole number is read as that year
  expect_identical(sm_its(corpus, "2020", "count")$intervention_year, 2020L)
  did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
                intervention_year = "2020", outcome = "count")
  expect_identical(did$intervention_year, 2020L)
  skip_if_not_installed("tidysynth")
  for (iy in list(2020.5, TRUE, c(2019, 2021))) {
    expect_error(
      sm_synth(corpus, treated = "Inst A", donors = "Inst B",
               intervention_year = iy, outcome = "count"),
      "single year"
    )
  }
})

test_that("sm_did intervals use the quantiles of their p-values", {
  did <- sm_did(did_corpus(), treated = "Inst A", control = "Inst B",
                intervention_year = 2020, outcome = "count")
  d <- did$did_estimate
  half <- stats::qt(0.975, stats::df.residual(did$model)) * d$std.error
  expect_equal(d$conf.high - d$estimate, half)
  expect_equal(d$estimate - d$conf.low, half)
})

test_that("sm_did drops a control year without a finite outcome", {
  withr::local_seed(21)
  years <- rep(2015:2024, each = 6)
  group <- rep(c("Inst A", "Inst B"), 30)
  corpus <- year_corpus(years, group)
  corpus$works$quartile <- sample(c("Q1", "Q2", "Q3"), 60, replace = TRUE)
  corpus$works$quartile[group == "Inst B" & years == 2018L] <- NA
  expect_warning(
    did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
                  intervention_year = 2020, outcome = "share_q1"),
    "control: 2018", class = "scimapR_dropped_years"
  )
  expect_false(any(is.nan(did$series$value)))
  expect_identical(as.character(did$dropped_years$group), "control")
  expect_identical(did$dropped_years$year, 2018L)
  control <- did$series[did$series$group == "control", ]
  treated <- did$series[did$series$group == "treated", ]
  expect_identical(control$year, setdiff(2015:2024, 2018L))
  expect_identical(treated$year, 2015:2024)
  # the model is fitted on exactly the reported series
  expect_identical(length(stats::fitted(did$model)), nrow(did$series))
  out <- cli::cli_fmt(print(did))
  expect_true(any(grepl("Dropped (no usable data): control: 2018", out,
                        fixed = TRUE)))
})

test_that("sm_did needs years before and after the intervention per group", {
  withr::local_seed(22)
  years <- c(rep(2015:2024, each = 2), rep(2020:2024, each = 2))
  group <- rep(c("Inst A", "Inst B"), c(20, 10))
  corpus <- year_corpus(years, group)
  corpus$works$quartile <- sample(c("Q1", "Q2"), 30, replace = TRUE)
  expect_error(
    sm_did(corpus, treated = "Inst A", control = "Inst B",
           intervention_year = 2020, outcome = "share_q1"),
    "Too few yearly observations for the DiD control group"
  )
  # a group left without any usable year aborts the same way
  corpus$works$quartile[group == "Inst B"] <- NA
  expect_error(
    sm_did(corpus, treated = "Inst A", control = "Inst B",
           intervention_year = 2020, outcome = "share_q1"),
    "Too few"
  )
  # counts: the control group's years without works are zeros
  did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
                intervention_year = 2020, outcome = "count")
  control <- did$series[did$series$group == "control", ]
  expect_identical(control$year, 2015:2024)
  expect_identical(control$value, rep(c(0, 2), each = 5))
  expect_identical(nrow(did$dropped_years), 0L)
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

synth_units <- c("Inst A", "Inst B", "Inst C")

synth_corpus <- function() {
  withr::local_seed(31)
  years <- rep(2015:2024, each = 6)
  corpus <- year_corpus(years, rep(synth_units, 20))
  corpus$works$quartile <- sample(c("Q1", "Q2", "Q3"), 60, replace = TRUE)
  corpus
}

test_that("the synthetic-control panel stays balanced", {
  corpus <- synth_corpus()
  unit <- rep(synth_units, 20)
  # Inst B: no quartile in 2017; Inst C: no work at all in 2021
  corpus$works$quartile[unit == "Inst B" & corpus$works$year == 2017L] <- NA
  corpus$works$year[unit == "Inst C" & corpus$works$year == 2021L] <- 2022L
  res <- .sm_synth_panel(corpus, synth_units, "share_q1", 2020L)
  panel <- res$panel
  expect_named(panel, c("unit", "year", "value"))
  expect_false(any(c(2017L, 2021L) %in% panel$year))
  expect_true(all(is.finite(panel$value)))
  expect_identical(as.vector(table(panel$unit)), rep(8L, 3))
  expect_identical(res$dropped_years$unit, c("Inst B", "Inst C"))
  expect_identical(res$dropped_years$year, c(2017L, 2021L))

  # counts: years without works are zeros, so nothing leaves the panel
  res <- .sm_synth_panel(corpus, synth_units, "count", 2020L)
  expect_identical(nrow(res$panel), 30L)
  expect_identical(res$panel$value[res$panel$unit == "Inst C" &
                                     res$panel$year == 2021L], 0)
  expect_identical(nrow(res$dropped_years), 0L)
})

test_that("the synthetic-control panel needs two pre-intervention years", {
  corpus <- synth_corpus()
  unit <- rep(synth_units, 20)
  corpus$works$quartile[unit == "Inst B" &
                          corpus$works$year %in% 2016:2019] <- NA
  expect_error(
    .sm_synth_panel(corpus, synth_units, "share_q1", 2020L),
    "Too few yearly observations for the synthetic-control panel"
  )
  expect_error(
    .sm_synth_panel(corpus, c("Inst A", "Nowhere"), "count", 2020L),
    "Nowhere"
  )
})

test_that("sm_synth warns about the years it drops from the panel", {
  skip_if_not_installed("tidysynth")
  corpus <- synth_corpus()
  unit <- rep(synth_units, 20)
  corpus$works$quartile[unit == "Inst B" & corpus$works$year == 2017L] <- NA
  expect_warning(
    synth <- suppressMessages(
      sm_synth(corpus, treated = "Inst A", donors = c("Inst B", "Inst C"),
               intervention_year = 2020, outcome = "share_q1"),
      classes = "cliMessage"
    ),
    "Inst B: 2017", class = "scimapR_dropped_years"
  )
  expect_false(2017L %in% synth$panel$year)
  expect_false(any(is.nan(synth$panel$value)))
  expect_identical(synth$dropped_years$year, 2017L)
  out <- cli::cli_fmt(print(synth))
  expect_true(any(grepl("Inst B: 2017", out, fixed = TRUE)))
})

# ---- small FNCI cells -------------------------------------------------------

count_small_cells <- function(expr) {
  n <- 0L
  withCallingHandlers(expr, scimapR_fnci_small_cells = function(cnd) {
    n <<- n + 1L
    rlang::cnd_muffle(cnd)
  })
  n
}

test_that("cnci outcomes pass on the small-cell FNCI message once", {
  corpus <- did_corpus()
  expect_message(
    sm_its(corpus, intervention_year = 2019, outcome = "cnci"),
    class = "scimapR_fnci_small_cells"
  )
  # sm_did() derives the FNCI once per group; the message appears once
  expect_identical(
    count_small_cells(sm_did(corpus, treated = "Inst A", control = "Inst B",
                             intervention_year = 2020, outcome = "cnci")),
    1L
  )
  expect_identical(
    count_small_cells(sm_did(corpus, treated = "Inst A", control = "Inst B",
                             intervention_year = 2020, outcome = "count")),
    0L
  )
})

test_that("sm_synth passes on the small-cell FNCI message once", {
  skip_if_not_installed("tidysynth")
  corpus <- sm_example_corpus(n_works = 150, seed = 1)
  units <- c("Inst A", "Inst B", "Inst C")
  n_rows <- nrow(corpus$authorships)
  corpus$authorships$institution_name <- rep_len(units, n_rows)
  expect_identical(
    count_small_cells(suppressMessages(
      sm_synth(corpus, treated = "Inst A", donors = c("Inst B", "Inst C"),
               intervention_year = 2020, outcome = "cnci"),
      classes = "cliMessage"
    )),
    1L
  )
})

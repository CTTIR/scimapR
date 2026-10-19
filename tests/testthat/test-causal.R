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

# ---- leadership: focal institutions and lead roles ---------------------------

lead_unit <- "Armed Forces Hospital Northtown"
lead_control <- "Federal Armed Forces Institute of Microbiology"

# A corpus by hand: per work its year, and per authorship row the work,
# author, position, corresponding flag and institution label
lead_corpus <- function(rows) {
  works <- unique(rows[c("work_id", "year")])
  sm_corpus(
    works = tibble::as_tibble(works),
    authors = tibble::tibble(author_id = unique(rows$author_id),
                             orcid = NA_character_,
                             display_name = unique(rows$author_id)),
    authorships = tibble::tibble(
      work_id = rows$work_id, author_id = rows$author_id,
      position = rows$position, is_corresponding = rows$corr,
      institution_id = rows$institution_id %||% NA_character_,
      raw_affiliation = NA_character_, country_code = NA_character_,
      institution_match = rows$label
    )
  )
}

test_that("the default leadership series equals the earlier formula", {
  # Every fixture work has a known corresponding author, so the default
  # series is unchanged: per year the share of works with a flagged
  # author, over all works (works without authorships counted as not led).
  fix <- realuse_corpus()
  a <- fix$authorships
  has <- tapply(a$is_corresponding %in% TRUE, a$work_id, any)
  has <- unname(has[fix$works$work_id])
  has[is.na(has)] <- FALSE
  old_value <- tapply(has, fix$works$year, mean)
  old_n <- tapply(has, fix$works$year, length)
  res <- .sm_yearly_outcome(fix, "leadership")
  expect_identical(res$series$year, as.integer(names(old_value)))
  expect_equal(res$series$value, as.vector(old_value))
  expect_identical(res$series$n_works, as.vector(old_n))
  expect_identical(res$dropped_years, integer())
  its <- sm_its(fix, 2021, "leadership")
  expect_equal(its$series$observed, as.vector(old_value))
})

test_that("works with an unknown corresponding author leave the denominator", {
  fix <- realuse_corpus()
  unknown <- fix$works$work_id[fix$works$year == 2020L][1:5]
  fix$authorships$is_corresponding[fix$authorships$work_id %in% unknown] <- NA
  n_2020 <- sum(fix$works$year == 2020L)
  res <- .sm_yearly_outcome(fix, "leadership")$series
  expect_identical(res$n_works[res$year == 2020L], n_2020 - 5L)
  expect_identical(res$value[res$year == 2020L], 1)
  # with a focal institution as well, and in each DiD series
  m <- suppressMessages(sm_affiliation_match(fix, realuse_dict()))
  res <- .sm_yearly_outcome(m, "leadership", institutions = lead_unit)$series
  expect_identical(res$n_works[res$year == 2020L], n_2020 - 5L)
  did <- sm_did(m, lead_unit, lead_control, 2021, "leadership")
  a <- m$authorships
  group <- unique(a$work_id[a$institution_match %in% lead_unit])
  known <- setdiff(group, unknown)
  n_known <- table(m$works$year[m$works$work_id %in% known])
  treated <- did$series[did$series$group == "treated", ]
  expect_identical(treated$n_works, as.vector(n_known))
  # any_lead keeps them: an unknown corresponding author does not lead
  res <- .sm_yearly_outcome(m, "leadership", institutions = lead_unit,
                            lead_role = "any_lead")$series
  expect_identical(res$n_works[res$year == 2020L], n_2020)
})

test_that("a year without a known corresponding author is dropped", {
  fix <- realuse_corpus()
  y2017 <- fix$works$work_id[fix$works$year == 2017L]
  fix$authorships$is_corresponding[fix$authorships$work_id %in% y2017] <- NA
  expect_warning(its <- sm_its(fix, 2021, "leadership"), "2017",
                 class = "scimapR_dropped_years")
  expect_identical(its$dropped_years, 2017L)
  expect_false(2017L %in% its$series$year)
})

test_that("leadership aborts when no work has a known lead", {
  # as for corpora from readers without corresponding-author data, instead
  # of dropping every year and reporting too few yearly observations
  m <- realuse_matched()
  m$authorships$is_corresponding <- NA
  expect_error(sm_its(m, 2021, "leadership"), "lead_role = \"first\"",
               class = "scimapR_leadership_unknown")
  expect_error(sm_its(m, 2021, "leadership", institutions = lead_unit),
               class = "scimapR_leadership_unknown")
  expect_error(sm_did(m, lead_unit, lead_control, 2021, "leadership"),
               class = "scimapR_leadership_unknown")
  # the position roles still know who leads
  its <- sm_its(m, 2021, "leadership", institutions = lead_unit,
                lead_role = "first")
  expect_s3_class(its, "sm_its")
  m$authorships$position <- NA_integer_
  expect_error(sm_its(m, 2021, "leadership", institutions = lead_unit,
                      lead_role = "first"),
               "known author position", class = "scimapR_leadership_unknown")
})

test_that("leadership counts the works led from the focal institution", {
  # hand computation on the matched fixture: per year, the works with an
  # authorship row in the role at the focal unit, over all works
  m <- realuse_matched()
  a <- m$authorships
  at_unit <- a$institution_match %in% lead_unit
  first <- a$position == stats::ave(a$position, a$work_id, FUN = min)
  last <- a$position == stats::ave(a$position, a$work_id, FUN = max)
  rows <- list(corresponding = a$is_corresponding, first = first,
               last = last, first_or_last = first | last,
               any_lead = first | last | a$is_corresponding)
  value <- list()
  for (role in names(rows)) {
    led <- unique(a$work_id[rows[[role]] & at_unit])
    hand <- tapply(m$works$work_id %in% led, m$works$year, mean)
    res <- .sm_yearly_outcome(m, "leadership", institutions = lead_unit,
                              lead_role = role)$series
    expect_equal(res$value, as.vector(hand), info = role)
    expect_identical(res$n_works, as.vector(table(m$works$year)),
                     info = role)
    value[[role]] <- res$value
  }
  expect_true(all(value$first <= value$first_or_last))
  expect_true(all(value$last <= value$first_or_last))
  expect_true(all(value$first_or_last <= value$any_lead))
  expect_true(all(value$corresponding <= value$any_lead))
})

test_that("an author leads from any of their affiliation rows", {
  # W1: the first author has a focal and another row; W2: the second,
  # corresponding author is focal
  rows <- data.frame(
    work_id = c("W1", "W1", "W1", "W2", "W2"), year = 2020L,
    author_id = c("A1", "A1", "A2", "A1", "A2"),
    position = c(1L, 1L, 2L, 1L, 2L),
    corr = c(TRUE, TRUE, FALSE, FALSE, TRUE),
    label = c("Other", "Focal", "Other", "Other", "Focal"),
    stringsAsFactors = FALSE
  )
  corpus <- lead_corpus(rows)
  share <- function(role) {
    .sm_yearly_outcome(corpus, "leadership", institutions = "Focal",
                       lead_role = role)$series$value
  }
  expect_identical(share("first"), 0.5)
  expect_identical(share("last"), 0.5)
  expect_identical(share("corresponding"), 1)
})

test_that("focal labels match any institution label column", {
  # institution_match labels only some rows; the focal label is the name
  # of an institution id, as group membership in sm_did() finds it
  rows <- data.frame(
    work_id = c("W1", "W1", "W2"), year = 2020L,
    author_id = c("A1", "A2", "A1"), position = c(1L, 2L, 1L),
    corr = c(FALSE, TRUE, TRUE), label = c("Matched Unit", NA, NA),
    institution_id = c(NA, "I1", "I2"), stringsAsFactors = FALSE
  )
  corpus <- lead_corpus(rows)
  corpus$institutions <- tibble::tibble(
    institution_id = c("I1", "I2"), ror = NA_character_,
    display_name = c("Named Univ", "Other Univ"), country_code = NA,
    region = NA, income_tier = NA, type = NA
  )
  share <- function(inst) {
    .sm_yearly_outcome(corpus, "leadership", institutions = inst)$series$value
  }
  expect_identical(share("Named Univ"), 0.5)
  expect_identical(share("I1"), 0.5)
  expect_identical(share(c("Named Univ", "Other Univ")), 1)
  its_def <- .sm_leadership_def(corpus, "corresponding", "Named Univ")
  expect_identical(its_def$label_column, "institution_match")
})

test_that("the leadership arguments are checked", {
  m <- realuse_matched()
  expect_error(sm_its(m, 2021, "leadership", lead_role = "last"),
               "needs focal institutions")
  expect_error(sm_did(m, lead_unit, lead_control, 2021, "leadership",
                      lead_role = "first"),
               "institution_aware")
  expect_warning(sm_its(m, 2021, "count", institutions = lead_unit),
                 class = "scimapR_leadership_ignored")
  expect_warning(sm_its(m, 2021, "count", lead_role = "first"),
                 class = "scimapR_leadership_ignored")
  expect_warning(sm_did(m, lead_unit, lead_control, 2021, "count",
                        institution_aware = TRUE),
                 class = "scimapR_leadership_ignored")
  expect_error(sm_its(m, 2021, "leadership", institutions = NA_character_),
               "character vector")
  # a label that no authorship carries: warning with the nearest labels
  expect_warning(
    sm_its(m, 2021, "leadership",
           institutions = c(lead_unit, "Armed Forces Hospital Nortown")),
    "nearest labels Armed Forces Hospital Northtown",
    class = "scimapR_unknown_institutions"
  )
  expect_error(
    suppressWarnings(sm_its(m, 2021, "leadership", institutions = "Nowhere"),
                     classes = "scimapR_unknown_institutions"),
    class = "scimapR_no_focal_works"
  )
  # positional calls keep their meaning: family is still the 4th argument
  expect_identical(sm_its(m, 2021, "count", "quasipoisson")$family,
                   "quasipoisson")
})

test_that("print methods state the leadership definition", {
  m <- realuse_matched()
  text <- function(x) paste(cli::cli_fmt(print(x)), collapse = " ")
  its <- sm_its(m, 2021, "leadership", institutions = lead_unit,
                lead_role = "first")
  expect_identical(its$leadership$lead_role, "first")
  expect_identical(its$leadership$institutions, lead_unit)
  expect_identical(its$leadership$label_column, "institution_match")
  expect_match(text(its), paste("Leadership: works whose first author is",
                                "at Armed Forces Hospital Northtown"))
  expect_match(text(sm_its(m, 2021, "leadership")),
               "among the works whose corresponding author is known")
  expect_null(sm_its(m, 2021, "count")$leadership)
  did <- sm_did(m, lead_unit, lead_control, 2021, "leadership",
                institution_aware = TRUE)
  expect_match(text(did), "one of the group's own institutions")
})

# ---- DiD and synthetic control: institution-aware series --------------------

test_that("institution-aware DiD series use each group's own labels", {
  m <- realuse_matched()
  a <- m$authorships
  share <- function(label) {
    works <- unique(a$work_id[a$institution_match %in% label])
    led <- unique(a$work_id[a$is_corresponding &
                              a$institution_match %in% label])
    year <- m$works$year[match(works, m$works$work_id)]
    as.vector(tapply(works %in% led, year, mean))
  }
  did <- sm_did(m, lead_unit, lead_control, 2021, "leadership",
                institution_aware = TRUE)
  s <- did$series
  expect_equal(s$value[s$group == "treated"], share(lead_unit))
  expect_equal(s$value[s$group == "control"], share(lead_control))
  expect_identical(did$leadership$institutions,
                   list(treated = lead_unit, control = lead_control))
  # without institution_aware every group work has a corresponding author
  plain <- sm_did(m, lead_unit, lead_control, 2021, "leadership")
  expect_true(all(plain$series$value == 1))
  expect_false(plain$leadership$institution_aware)
})

test_that("institution-aware synthetic-control units use their own label", {
  m <- realuse_matched()
  units <- c(lead_unit, lead_control)
  res <- suppressWarnings(
    .sm_synth_panel(m, units, "leadership", 2021L, institution_aware = TRUE),
    classes = "scimapR_dropped_years"
  )
  a <- m$authorships
  for (u in units) {
    works <- unique(a$work_id[a$institution_match %in% u])
    led <- unique(a$work_id[a$is_corresponding & a$institution_match %in% u])
    year <- m$works$year[match(works, m$works$work_id)]
    hand <- tapply(works %in% led, year, mean)
    p <- res$panel[res$panel$unit == u, ]
    expect_equal(p$value, as.vector(hand[as.character(p$year)]), info = u)
  }
  skip_if_not_installed("tidysynth")
  synth <- suppressWarnings(suppressMessages(
    sm_synth(m, lead_unit, lead_control, 2021, "leadership",
             institution_aware = TRUE),
    classes = "cliMessage"
  ), classes = "scimapR_dropped_years")
  expect_identical(synth$leadership$institutions, units)
  out <- paste(cli::cli_fmt(print(synth)), collapse = " ")
  expect_match(out, "the unit's own institution")
})

# ---- DiD: works of both groups ----------------------------------------------

test_that("sm_did reports the works of both groups", {
  # did_corpus() alternates the labels across authorship rows, so most
  # works belong to both groups
  corpus <- did_corpus()
  a <- corpus$authorships
  in_a <- unique(a$work_id[a$institution_name == "Inst A"])
  in_b <- unique(a$work_id[a$institution_name == "Inst B"])
  shared <- intersect(in_a, in_b)
  expect_gt(length(shared), 100L)
  expect_warning(
    did <- sm_did(corpus, "Inst A", "Inst B", 2020, "count"),
    "belong to both", class = "scimapR_did_shared_works"
  )
  expect_setequal(did$shared_works$work_id, shared)
  expect_true(all(did$shared_works$series == "both"))
  expect_identical(did$shared, "keep")
  # an explicit policy does not warn; "keep" gives the same estimate
  expect_no_warning(
    keep <- sm_did(corpus, "Inst A", "Inst B", 2020, "count", shared = "keep")
  )
  expect_equal(keep$did_estimate, did$did_estimate)
  out <- paste(cli::cli_fmt(print(keep)), collapse = " ")
  expect_match(out, paste0("Shared works: ", length(shared),
                           " \\(", length(shared), " in both series\\)"))
})

test_that("sm_did can leave shared works out or give them to their lead", {
  corpus <- did_corpus()
  a <- corpus$authorships
  in_a <- unique(a$work_id[a$institution_name == "Inst A"])
  in_b <- unique(a$work_id[a$institution_name == "Inst B"])
  shared <- intersect(in_a, in_b)
  n_series <- function(did, g) sum(did$series$value[did$series$group == g])

  ex <- sm_did(corpus, "Inst A", "Inst B", 2020, "count", shared = "exclude")
  expect_identical(n_series(ex, "treated"), as.double(length(in_a) -
                                                        length(shared)))
  expect_identical(n_series(ex, "control"), as.double(length(in_b) -
                                                        length(shared)))
  expect_true(all(ex$shared_works$series == "none"))

  # by the first author: a shared work goes to the group of its first
  # author's rows, and leaves both series when they are in both groups
  lead <- sm_did(corpus, "Inst A", "Inst B", 2020, "count", shared = "lead",
                 lead_role = "first")
  pos1 <- stats::ave(a$position, a$work_id, FUN = min)
  first <- a[a$work_id %in% shared & a$position == pos1, ]
  by_a <- unique(first$work_id[first$institution_name == "Inst A"])
  by_b <- unique(first$work_id[first$institution_name == "Inst B"])
  to_a <- setdiff(by_a, by_b)
  to_b <- setdiff(by_b, by_a)
  got <- lead$shared_works
  expect_setequal(got$work_id[got$series == "treated"], to_a)
  expect_setequal(got$work_id[got$series == "control"], to_b)
  expect_identical(n_series(lead, "treated"),
                   as.double(length(in_a) - length(shared) + length(to_a)))
  expect_identical(n_series(lead, "control"),
                   as.double(length(in_b) - length(shared) + length(to_b)))
})

test_that("sm_did aborts when the groups share a label", {
  corpus <- did_corpus()
  expect_error(
    sm_did(corpus, c("Inst A", "Inst B"), "Inst B", 2020, "count"),
    "share the label"
  )
})

# ---- DiD and synthetic control: citation-immature years ---------------------

test_that("sm_did and sm_synth leave out citation-immature cnci years", {
  # as sm_its() does: with last_refresh in 2024 and lag 2, 2023 and 2024
  # are citation-immature; before, sm_did() and sm_synth() kept them
  corpus <- did_corpus()
  corpus$metadata$last_refresh <- as.POSIXct("2024-06-30", tz = "UTC")
  did <- suppressMessages(
    sm_did(corpus, "Inst A", "Inst B", 2020, "cnci", shared = "keep"),
    classes = "scimapR_fnci_small_cells"
  )
  expect_identical(did$provisional_years, c(2023L, 2024L))
  expect_false(any(did$series$year %in% c(2023L, 2024L)))
  expect_identical(did$lag, 2L)
  out <- paste(cli::cli_fmt(print(did)), collapse = " ")
  expect_match(out, "Excluded (citation-immature): 2023 and 2024",
               fixed = TRUE)
  did0 <- suppressMessages(
    sm_did(corpus, "Inst A", "Inst B", 2020, "cnci", lag = 0,
           shared = "keep"),
    classes = "scimapR_fnci_small_cells"
  )
  expect_identical(did0$provisional_years, integer())
  expect_true(2024L %in% did0$series$year)
  # other outcomes keep every year
  expect_identical(
    sm_did(corpus, "Inst A", "Inst B", 2020, "count",
           shared = "keep")$provisional_years,
    integer()
  )

  synth <- synth_corpus()
  synth$metadata$last_refresh <- as.POSIXct("2024-06-30", tz = "UTC")
  res <- suppressMessages(
    .sm_synth_panel(synth, synth_units, "cnci", 2020L, lag = 2L),
    classes = "scimapR_fnci_small_cells"
  )
  expect_identical(res$provisional_years, c(2023L, 2024L))
  expect_false(any(res$panel$year %in% c(2023L, 2024L)))
})

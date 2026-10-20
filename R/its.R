# Part C1: interrupted time series (ITS) for policy evaluation.

#' Compute a yearly outcome series from a corpus
#'
#' @description
#' Aggregates one of several outcomes to a per-year series. Shared by
#' [sm_its()], [sm_did()] and [sm_synth()].
#'
#' For `"count"` the series runs over every year from the first to the last
#' publication year of the whole corpus, and a year without works counts 0.
#' For the other outcomes, a year with works but without a usable value is
#' dropped and returned in `dropped_years` (see
#' `.sm_drop_unusable_years()`). The helper never warns: its callers warn
#' once each, naming the group or unit.
#'
#' For `"leadership"` (`.sm_leadership_series()`), `n_works` counts the
#' works with a known lead status, the denominator of the share.
#'
#' @param corpus An `sm_corpus`.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`.
#' @param work_ids Optional character vector restricting to a subset of works.
#' @param institutions,lead_role Focal institutions (or `NULL`) and the
#'   author role that leads a work, for `"leadership"`.
#' @param min_cell For `"cnci"`: passed to [sm_metric_fnci()] when the
#'   impact is derived from citation counts.
#' @param call Caller environment.
#' @return A list: `series` (a tibble with columns `year` (integer), `value`,
#'   `n_works`), `dropped_years` (sorted integer vector) and
#'   `impact_source` (the label of the impact values for `"cnci"`, else
#'   `NA`).
#' @noRd
.sm_yearly_outcome <- function(corpus, outcome, work_ids = NULL,
                               institutions = NULL,
                               lead_role = "corresponding",
                               min_cell = NULL,
                               call = rlang::caller_env()) {
  works <- corpus$works
  corpus_years <- as.integer(works$year[!is.na(works$year)])
  if (!is.null(work_ids)) {
    works <- dplyr::filter(works, .data$work_id %in% work_ids)
  }
  works <- dplyr::filter(works, !is.na(.data$year))
  works$year <- as.integer(works$year)

  if (outcome == "count") {
    # Every corpus year is observed, so a year without works is a real 0.
    grid <- if (length(corpus_years) == 0L) {
      integer()
    } else {
      seq.int(min(corpus_years), max(corpus_years))
    }
    n <- tabulate(match(works$year, grid), nbins = length(grid))
    series <- tibble::tibble(year = grid, value = as.double(n), n_works = n)
    return(list(series = series, dropped_years = integer(),
                impact_source = NA_character_))
  }

  empty <- tibble::tibble(year = integer(), value = double(),
                          n_works = integer())
  if (nrow(works) == 0L) {
    return(list(series = empty, dropped_years = integer(),
                impact_source = NA_character_))
  }

  impact_source <- NA_character_
  series <- switch(outcome,
    share_q1 = {
      qcol <- intersect(c("quartile", "jif_quartile", "sjr_quartile"),
                        names(works))
      if (length(qcol) == 0L) {
        cli::cli_abort(c(
          "Outcome {.val share_q1} needs a journal-quartile column.",
          "i" = "Add a {.field quartile} column (values like {.val Q1}) to {.code corpus$works}."
        ), call = call)
      }
      qc <- qcol[1]
      works %>%
        dplyr::group_by(.data$year) %>%
        dplyr::summarise(
          n_works = dplyr::n(),
          value = mean(toupper(.data[[qc]]) == "Q1", na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::arrange(.data$year)
    },
    cnci = {
      res <- .resolve_impact_values(corpus, min_cell = min_cell, call = call)
      impact_source <- res$source
      # works without a finite impact value stay out of the yearly mean
      res$values$value[!is.finite(res$values$value)] <- NA_real_
      works %>%
        dplyr::select("work_id", "year") %>%
        dplyr::inner_join(res$values, by = "work_id") %>%
        dplyr::filter(!is.na(.data$value)) %>%
        dplyr::group_by(.data$year) %>%
        dplyr::summarise(
          n_works = dplyr::n(),
          value = mean(.data$value, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::arrange(.data$year)
    },
    leadership = .sm_leadership_series(corpus, works, institutions,
                                       lead_role, call = call)
  )
  out <- .sm_drop_unusable_years(series, works$year)
  out$impact_source <- impact_source
  out
}

#' Drop the years of a yearly series that have no usable outcome
#'
#' A year is unusable when its `value` is missing or not finite (a share over
#' works that all lack the information) or when no work enters it
#' (`n_works == 0`). A year in `years` (the years with works) that is absent
#' from `series` is unusable too: the impact outcome leaves works without a
#' value out before it aggregates. Not for the count outcome, whose years
#' without works are real zeros.
#'
#' @param series A yearly tibble with `year`, `value` and `n_works`.
#' @param years Years with at least one work.
#' @return A list: `series` without the unusable years and `dropped_years`
#'   (sorted integer vector).
#' @noRd
.sm_drop_unusable_years <- function(series, years) {
  series$year <- as.integer(series$year)
  unusable <- !is.finite(series$value) | series$n_works %in% 0L
  dropped <- union(setdiff(as.integer(years), series$year),
                   series$year[unusable])
  list(
    series = series[!unusable, , drop = FALSE],
    dropped_years = sort(as.integer(dropped))
  )
}

#' Check `intervention_year` and return it as one integer year
#'
#' Shared by [sm_its()], [sm_did()] and [sm_synth()]. Accepts one whole
#' number, or text holding one (such as `"2020"`). Fractional, missing and
#' infinite years abort, and so do logical values, factors and dates, whose
#' internal numbers are not years.
#' @noRd
.sm_intervention_year <- function(x, call = rlang::caller_env()) {
  year <- if (is.character(x)) suppressWarnings(as.numeric(x)) else x
  ok <- is.numeric(year) && rlang::is_integerish(year, n = 1, finite = TRUE)
  # a whole number beyond the integer range becomes NA here
  year <- if (ok) suppressWarnings(as.integer(year)) else NA_integer_
  if (is.na(year)) {
    cli::cli_abort(c(
      "{.arg intervention_year} must be a single year.",
      "i" = "Give it as one whole number, such as {.code 2020}."
    ), call = call)
  }
  year
}

#' Abort unless enough years remain to fit a yearly model
#'
#' Called after every exclusion. At least 4 distinct years are required,
#' with `min_pre` of them before `intervention_year` and `min_post` from it
#' on.
#'
#' @param years Years that enter the fit.
#' @param what Completes "Too few yearly observations ...", for example
#'   `"to fit an ITS"`. Fixed text, never data.
#' @param notes Plain-text lines (such as the excluded years) shown as info
#'   bullets. Their braces are escaped, so labels from the data stay text.
#' @noRd
.sm_check_years <- function(years, intervention_year, what, min_pre = 1L,
                            min_post = 1L, notes = character(),
                            call = rlang::caller_env()) {
  years <- unique(years)
  n <- length(years)
  n_pre <- sum(years < intervention_year)
  n_post <- n - n_pre
  if (n >= 4L && n_pre >= min_pre && n_post >= min_post) {
    return(invisible(NULL))
  }
  cli::cli_abort(c(
    paste0("Too few yearly observations ", what, ": {n} usable year{?s}, ",
           "{n_pre} before {intervention_year} and {n_post} from it on."),
    "i" = paste0("At least 4 distinct years are needed: {min_pre} or more ",
                 "before {.arg intervention_year} and {min_post} or more ",
                 "from it on."),
    stats::setNames(.sm_cli_escape(notes), rep("i", length(notes)))
  ), call = call)
}

#' Abort when a fitted model has aliased (inestimable) terms
#'
#' `coef(summary(fit))` silently omits aliased terms, so a level or slope
#' change that the years cannot identify would vanish from the results.
#' @noRd
.sm_check_identified <- function(fit, what, call = rlang::caller_env()) {
  aliased <- names(which(is.na(stats::coef(fit))))
  if (length(aliased) == 0L) return(invisible(NULL))
  cli::cli_abort(c(
    "The {what} model cannot estimate {.field {aliased}}.",
    "i" = paste0("The years used do not separate these terms; check ",
                 "{.arg intervention_year} against the years of the series.")
  ), call = call)
}

#' Warn when a model with an estimated dispersion has no residual df
#'
#' With as many years as coefficients (4 in an ITS), a family that estimates
#' its dispersion (Gaussian, quasi families) fits the years exactly, and
#' summary.glm() returns NaN standard errors, so the intervals and p-values
#' are NaN too. Families that fix the dispersion (Poisson, binomial) keep
#' their standard errors.
#' @noRd
.sm_check_residual_df <- function(fit, what) {
  fixed <- fit$family$family %in% c("poisson", "binomial")
  if (fixed || stats::df.residual(fit) > 0) return(invisible(NULL))
  cli::cli_warn(c(
    paste0("The {what} model has no residual degrees of freedom: its ",
           "{length(stats::coef(fit))} coefficients fit the ",
           "{stats::nobs(fit)} years exactly."),
    "i" = paste0("Its standard errors, confidence intervals and p-values ",
                 "are NaN; they need more years than coefficients.")
  ), class = "scimapR_no_residual_df")
}

#' Warn when a Poisson count model is overdispersed
#'
#' Pearson's statistic over the residual degrees of freedom estimates the
#' dispersion; when it exceeds 1 significantly (chi-squared test, p < 0.05),
#' the Poisson standard errors are too small.
#' @noRd
.sm_check_overdispersion <- function(fit) {
  if (!identical(fit$family$family, "poisson")) return(invisible(NULL))
  rdf <- stats::df.residual(fit)
  if (rdf < 1) return(invisible(NULL))
  pearson <- sum(stats::residuals(fit, type = "pearson")^2)
  p <- stats::pchisq(pearson, rdf, lower.tail = FALSE)
  if (!is.finite(p) || p >= 0.05) return(invisible(NULL))
  cli::cli_warn(c(
    paste0("The Poisson model is overdispersed (dispersion ",
           "{round(pearson / rdf, 2)}), so its standard errors and ",
           "confidence intervals are too narrow."),
    "i" = paste0("Refit with {.code family = \"quasipoisson\"} to scale ",
                 "them by the estimated dispersion.")
  ), class = "scimapR_overdispersion")
}

#' "unit: year, year" lines for grouped series, in order of first appearance
#' @noRd
.sm_unit_years <- function(unit, year) {
  unit <- as.character(unit)
  keys <- unique(unit)
  vapply(keys, function(k) {
    paste0(k, ": ", paste(sort(year[unit == k]), collapse = ", "))
  }, character(1), USE.NAMES = FALSE)
}

#' Warn once about years dropped from grouped series (sm_did, sm_synth)
#' @param header cli template naming the method; may use `{outcome}`.
#' @noRd
.sm_warn_dropped_units <- function(unit, year, outcome, header) {
  lines <- .sm_unit_years(unit, year)
  cli::cli_warn(c(
    header,
    stats::setNames(.sm_cli_escape(lines), rep("*", length(lines)))
  ), class = "scimapR_dropped_years")
}

#' Resolve a per-work impact (CNCI) series from common locations
#'
#' @description
#' Searches the corpus for impact data in a documented order and uses the first
#' populated source: (1) a precomputed impact column on `works`: `cnci`, then
#' `fwci` (OpenAlex), then `fnci`, `rcr`, `cnci_value`, `ncs`, `mncs` and
#' `field_citation_ratio`; (2) a dedicated `corpus$metrics` table
#' (`cnci`/`fnci`/`value` column keyed by `work_id`); (3)
#' `works$cited_by_count`, from which a field-normalised impact (FNCI) is
#' derived via [sm_metric_fnci()] (with `min_cell`). If none is populated it
#' raises an informative error (class `scimapR_no_impact_data`) naming the
#' exact columns inspected -- instead of letting the downstream series
#' collapse to "0 observations". Shared by sm_its(), sm_did(), sm_synth()
#' and sm_metric_summary().
#'
#' @return A list with `values` (tibble of `work_id`, `value`) and `source`
#'   (a human-readable label of the location used).
#' @noRd
.resolve_impact_values <- function(corpus, min_cell = NULL,
                                   call = rlang::caller_env()) {
  works <- corpus$works
  checked <- character()

  # documented impact column names searched on `works` and a metrics table
  impact_cols <- c("cnci", "fwci", "fnci", "rcr", "cnci_value", "ncs",
                   "mncs", "field_citation_ratio")
  labels <- c(fwci = "works$fwci (OpenAlex)")

  # 1. a precomputed impact column on works (cnci preferred, then siblings)
  wcol <- intersect(impact_cols, names(works))
  for (col in wcol) {
    checked <- c(checked, paste0("works$", col))
    if (any(!is.na(works[[col]]))) {
      return(list(
        values = tibble::tibble(work_id = works$work_id,
                                value = as.numeric(works[[col]])),
        source = if (col %in% names(labels)) {
          labels[[col]]
        } else {
          paste0("works$", col)
        }
      ))
    }
  }
  if (length(wcol) == 0L) checked <- c(checked, "works$cnci", "works$fwci")

  # 2. dedicated metrics table, if the corpus carries one
  checked <- c(checked, "corpus$metrics")
  metrics <- corpus[["metrics"]]
  if (!is.null(metrics) && is.data.frame(metrics) &&
      "work_id" %in% names(metrics)) {
    mcol <- intersect(c(impact_cols, "value"), names(metrics))
    if (length(mcol) > 0L && any(!is.na(metrics[[mcol[1]]]))) {
      return(list(
        values = tibble::tibble(work_id = as.character(metrics$work_id),
                                value = as.numeric(metrics[[mcol[1]]])),
        source = paste0("corpus$metrics$", mcol[1])
      ))
    }
  }

  # 3. derive a normalised impact from citation counts
  checked <- c(checked, "works$cited_by_count")
  if ("cited_by_count" %in% names(works) &&
      any(!is.na(works$cited_by_count))) {
    fnci <- sm_metric_fnci(corpus, min_cell = min_cell, call = call)
    if (any(!is.na(fnci$fnci))) {
      return(list(
        values = tibble::tibble(work_id = fnci$work_id, value = fnci$fnci),
        source = "works$cited_by_count (field-normalised)"
      ))
    }
  }

  cli::cli_abort(c(
    "Outcome {.val cnci} has no usable impact data in this corpus.",
    "i" = "Looked for, in order: {.field {checked}}.",
    "i" = paste0(
      "Populate {.code works$cnci}, {.code works$fwci} (e.g. with ",
      "{.fn sm_enrich_openalex_impact}), a {.code corpus$metrics} table, ",
      "or {.code works$cited_by_count}; enrich citations (e.g. ",
      "{.fn sm_enrich_opencitations}) or supply impact via ",
      "{.fn sm_metric_summary}."
    )
  ), class = "scimapR_no_impact_data", call = call)
}

#' Print the impact source of a cnci result (nothing when it is NA)
#' @noRd
.sm_print_impact_source <- function(source) {
  if (is.null(source) || is.na(source)) return(invisible(NULL))
  cli::cli_text("{.strong Impact source:} ", .sm_cli_escape(source))
  invisible(NULL)
}

#' Default GLM family for an outcome
#' @noRd
.sm_outcome_family <- function(outcome, family) {
  if (!is.null(family)) {
    if (is.character(family)) return(get(family, mode = "function")())
    if (inherits(family, "family")) return(family)
    if (is.function(family)) return(family())
  }
  switch(outcome,
    count = stats::poisson(),
    stats::gaussian()
  )
}

#' Interrupted time series for a corpus outcome
#'
#' @description
#' A turnkey interrupted time series (ITS): aggregates the chosen `outcome` to a
#' yearly series, fits a segmented regression with a level shift and a slope
#' change at `intervention_year`, and derives the counterfactual (the
#' pre-intervention trend projected forward).
#'
#' @param corpus An `sm_corpus`.
#' @param intervention_year Year at which the intervention takes effect: one
#'   whole number such as `2020`, or text holding one.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`.
#'   The expected source columns are:
#'   \describe{
#'     \item{`"count"`}{Works per year (uses `works$year`).}
#'     \item{`"share_q1"`}{Share of Q1-journal works among the works with a
#'       quartile; needs a journal-quartile column on `works` (`quartile`,
#'       `jif_quartile`, or `sjr_quartile`).}
#'     \item{`"cnci"`}{Mean field-normalised citation impact per year. Impact is
#'       resolved from the first populated of `works$cnci`, `works$fwci`
#'       (OpenAlex; see [sm_enrich_openalex_impact()]), the other impact
#'       columns `fnci`, `rcr`, `cnci_value`, `ncs`, `mncs` and
#'       `field_citation_ratio`, a `corpus$metrics` table
#'       (`cnci`/`fnci`/`value` keyed by `work_id`), or
#'       `works$cited_by_count` (from which FNCI is derived via
#'       [sm_metric_fnci()], with `min_cell`). If none is populated, an
#'       informative error (class `scimapR_no_impact_data`) names the
#'       columns inspected. [sm_metric_summary()] (`metric = "cnci"`)
#'       resolves impact in the same order, and the result names the source
#'       used (`impact_source`). Works without a finite impact value are
#'       left out of the yearly mean.}
#'     \item{`"leadership"`}{Share of works led through the author role
#'       `lead_role` (by default the corresponding author,
#'       `authorships$is_corresponding`), by one of `institutions` when
#'       they are given; see Details.}
#'   }
#' @param family Optional GLM family (a `family` object, generator function, or
#'   name). Defaults to Poisson for `"count"` and Gaussian otherwise; document
#'   your choice when overriding. A Poisson fit warns when the counts are
#'   overdispersed; `"quasipoisson"` then scales the standard errors.
#' @param lag Citation-maturity lag in years (default `2`). For citation-based
#'   outcomes (`"cnci"`), the most recent `lag` years are citation-immature and
#'   are excluded from the fit; this is reported in the print method.
#' @param institutions For `outcome = "leadership"`: `NULL` (default) or a
#'   character vector of focal institution labels. A work then counts as
#'   led when an authorship in the role `lead_role` belongs to one of them,
#'   that is when its `institution_match`, `institution_name` or
#'   `institution_id`, or the name of that id in `corpus$institutions`, is
#'   one of the labels (run [sm_affiliation_match()] first). A label that
#'   no authorship carries gives a warning naming the nearest labels; when
#'   none is found, `sm_its()` aborts.
#' @param lead_role For `outcome = "leadership"`: the author role that leads
#'   a work. `"corresponding"` (default) is an author with
#'   `is_corresponding = TRUE`, `"first"` and `"last"` are the authors with
#'   the lowest and the highest `position` of the work, `"first_or_last"`
#'   either, and `"any_lead"` the first, last or corresponding author.
#'   Roles other than `"corresponding"` need `institutions`.
#' @param min_cell For `outcome = "cnci"`: `NULL` (default) or a positive
#'   integer, passed to [sm_metric_fnci()] when the impact is derived from
#'   `works$cited_by_count`, so that works in field-year cells with fewer
#'   works fall back to larger baselines. Not used when the corpus carries
#'   stored impact values.
#' @param call Caller environment for error reporting.
#'
#' @details
#' The yearly series is built first. For `"count"` it runs over every year
#' from the first to the last publication year of the corpus, and a year
#' without works counts 0, so filter the corpus to the analysis window
#' beforehand. For the other outcomes a year with works but no usable value
#' is dropped with a warning and listed in `dropped_years`: no work of the
#' year has a journal quartile (`"share_q1"`) or a finite impact value
#' (`"cnci"`). For `"cnci"` the citation-immature years are excluded after
#' that and listed in `provisional_years`, so no year is in both.
#'
#' For `"leadership"` the share of a year is over the works whose lead is
#' known, and that number of works weights the year in the fit. A work
#' whose authorships all have `is_corresponding = NA` (unknown, as the
#' readers of sources without corresponding-author data record it; see
#' [sm_corpus()]) leaves the denominator for
#' `lead_role = "corresponding"`, with or without `institutions`; up to
#' scimapR 0.4.0 it counted as not led. So does a work without
#' authorships, and for the position roles a work whose positions are all
#' `NA`. For `"any_lead"` an unknown corresponding author counts as not
#' leading, so the work stays in the denominator. A year in which no work
#' has a known lead is dropped with a warning, and `sm_its()` aborts when
#' no work has one. With `institutions` the denominator is every work of
#' the year with a known lead, not only the works with an authorship at
#' the focal institutions.
#'
#' A focal label is compared with every label column of an authorship row
#' (`institution_match`, `institution_name`, `institution_id` and the name
#' of that id), as group membership in [sm_did()] and [sm_synth()] is, so
#' a row with `institution_match` "A" and `institution_name` "B" belongs to
#' both "A" and "B". [sm_count()] instead labels each row by the first of
#' these columns with a value. The print method names the column that
#' labels the institutions of the corpus (`leadership$label_column`).
#'
#' At least 4 years must remain after these exclusions, with 2 or more before
#' `intervention_year` and 2 or more from it on, so that the pre-trend, the
#' level change and the slope change can all be estimated; otherwise
#' `sm_its()` aborts. With only 4 years the 4 coefficients fit the series
#' exactly: a family that estimates its dispersion (Gaussian, quasi
#' families) then has no residual degrees of freedom, so its standard
#' errors, intervals and p-values are `NaN` and `sm_its()` warns. Families
#' that fix the dispersion, such as the Poisson default for `"count"`, keep
#' their standard errors.
#'
#' The confidence intervals are Wald intervals on the reference distribution
#' of the p-values: t with the residual degrees of freedom when the family
#' estimates its dispersion (Gaussian and quasi families), normal when the
#' family fixes it (Poisson, binomial). The standard errors treat the yearly
#' values as independent; no correction for autocorrelation is applied.
#'
#' @return An `sm_its` S3 object with components: `model` (the fitted `glm`),
#'   `coefficients` (tidy tibble: `term`, `estimate`, `std.error`, `conf.low`,
#'   `conf.high`, `statistic`, `p.value`), `series` (tibble: `year`,
#'   `observed`, `fitted`, `counterfactual`), and metadata (`outcome`,
#'   `intervention_year`, `family`, `lag`, `provisional_years`,
#'   `dropped_years`, `leadership`). `dropped_years` (integer) lists the
#'   years left out for lack of a usable value, `provisional_years`
#'   (integer) the citation-immature years excluded after them.
#'   `leadership` holds the definition used for `outcome = "leadership"`, a
#'   list of `lead_role`, `institution_aware` (`FALSE`), `institutions`
#'   (the focal labels or `NULL`) and `label_column` (the column that
#'   labels the institutions of the corpus, `institution_match`,
#'   `institution_name` or `institution_id`, the first with a value; `NA`
#'   without `institutions`), and is `NULL` for the other outcomes.
#'   `impact_source` (character) names where the impact values of
#'   `outcome = "cnci"` come from, such as `"works$fwci (OpenAlex)"` or
#'   `"works$cited_by_count (field-normalised)"`; `NA` for the other
#'   outcomes.
#'
#' @family causal
#' @seealso [sm_did()], [sm_citation_maturity()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 200, seed = 1)
#' its <- sm_its(corpus, intervention_year = 2020, outcome = "count")
#' its
#' \donttest{
#' ggplot2::autoplot(its)
#' }
#'
#' # share of works whose corresponding author is at a focal unit
#' fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
#' dict <- readr::read_csv(
#'   sm_example_files("example_realuse_affiliation_dict.csv"),
#'   col_types = "ccc"
#' )
#' fix <- sm_affiliation_match(fix, dict)
#' lead <- sm_its(fix, intervention_year = 2021, outcome = "leadership",
#'                institutions = "Armed Forces Hospital Northtown")
#' lead$series
sm_its <- function(corpus,
                   intervention_year,
                   outcome = c("count", "share_q1", "cnci", "leadership"),
                   family = NULL,
                   lag = NULL,
                   institutions = NULL,
                   lead_role = c("corresponding", "first", "last",
                                 "first_or_last", "any_lead"),
                   min_cell = NULL,
                   call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  outcome <- rlang::arg_match(outcome, error_call = call)
  .check_min_cell(min_cell, call = call)
  given <- c("institutions", "lead_role")[c(!is.null(institutions),
                                            !missing(lead_role))]
  lead_role <- rlang::arg_match(lead_role, error_call = call)
  intervention_year <- .sm_intervention_year(intervention_year, call = call)
  lag <- as.integer(lag %||% 2L)
  leadership <- NULL
  if (.sm_check_leadership_args(outcome, lead_role, given,
                                focal = !is.null(institutions),
                                focal_arg = "institutions", call = call)) {
    leadership <- .sm_leadership_def(corpus, lead_role, institutions)
  } else {
    institutions <- NULL
  }

  yearly <- .sm_yearly_outcome(corpus, outcome, institutions = institutions,
                               lead_role = lead_role, min_cell = min_cell,
                               call = call)
  series <- yearly$series
  dropped_years <- yearly$dropped_years

  # citation-maturity exclusion for citation-based outcomes, using the same
  # cutoff rule as sm_citation_maturity() (Part D1). It runs after the
  # unusable years are dropped, so the two sets never share a year.
  provisional_years <- integer()
  if (outcome == "cnci") {
    cutoff <- .maturity_cutoff(corpus, lag)
    if (!is.na(cutoff)) {
      provisional_years <- series$year[series$year > cutoff]
      if (length(provisional_years) > 0L) {
        series <- dplyr::filter(series, !(.data$year %in% provisional_years))
      }
    }
  }

  notes <- character()
  if (length(dropped_years) > 0L) {
    notes <- paste0("Dropped for lack of usable ", outcome, " data: ",
                    paste(dropped_years, collapse = ", "), ".")
  }
  if (length(provisional_years) > 0L) {
    notes <- c(notes, paste0("Excluded as citation-immature: ",
                             paste(provisional_years, collapse = ", "), "."))
  }
  .sm_check_years(series$year, intervention_year, "to fit an ITS",
                  min_pre = 2L, min_post = 2L, notes = notes, call = call)
  if (length(dropped_years) > 0L) {
    cli::cli_warn(c(
      paste0("Dropped {length(dropped_years)} year{?s} with no usable ",
             "{.val {outcome}} data: {dropped_years}."),
      "i" = "The ITS is fitted on the other years; see {.field dropped_years}."
    ), class = "scimapR_dropped_years")
  }

  df <- series
  df$time <- df$year - min(df$year)
  df$intervention <- as.integer(df$year >= intervention_year)
  df$time_since <- pmax(0L, df$year - intervention_year)

  fam <- .sm_outcome_family(outcome, family)

  fit <- stats::glm(value ~ time + intervention + time_since,
                    data = df, family = fam,
                    weights = if (outcome %in% c("share_q1", "leadership")) {
                      df$n_works
                    } else {
                      NULL
                    })
  .sm_check_identified(fit, "ITS", call = call)
  .sm_check_residual_df(fit, "ITS")
  .sm_check_overdispersion(fit)

  coefs <- .sm_tidy_glm(fit)

  # counterfactual: pre-intervention trend projected across all years; the
  # fitted values come from the same modelled rows, so all columns align
  cf_data <- df
  cf_data$intervention <- 0L
  cf_data$time_since <- 0L
  counterfactual <- as.numeric(stats::predict(fit, newdata = cf_data,
                                              type = "response"))
  fitted_vals <- as.numeric(stats::predict(fit, newdata = df,
                                           type = "response"))

  out_series <- tibble::tibble(
    year = df$year,
    observed = df$value,
    fitted = fitted_vals,
    counterfactual = counterfactual
  )

  structure(
    list(
      model = fit,
      coefficients = coefs,
      series = out_series,
      outcome = outcome,
      intervention_year = intervention_year,
      family = fam$family,
      lag = lag,
      provisional_years = provisional_years,
      dropped_years = dropped_years,
      leadership = leadership,
      impact_source = yearly$impact_source
    ),
    class = "sm_its"
  )
}

#' Tidy a glm into a coefficient tibble with Wald CIs (no broom dependency)
#'
#' The interval uses the reference distribution of the p-values:
#' summary.glm() tests with t on the residual degrees of freedom when the
#' dispersion is estimated (Gaussian, quasi families) and with z when the
#' family fixes it (Poisson, binomial).
#' @noRd
.sm_tidy_glm <- function(fit, conf_level = 0.95) {
  sm <- stats::coef(summary(fit))
  est <- sm[, 1]
  se <- sm[, 2]
  prob <- 1 - (1 - conf_level) / 2
  rdf <- stats::df.residual(fit)
  q <- if (!identical(colnames(sm)[3], "t value")) {
    stats::qnorm(prob)
  } else if (rdf > 0) {
    stats::qt(prob, df = rdf)
  } else {
    NaN
  }
  tibble::tibble(
    term = rownames(sm),
    estimate = unname(est),
    std.error = unname(se),
    conf.low = unname(est - q * se),
    conf.high = unname(est + q * se),
    statistic = unname(sm[, 3]),
    p.value = unname(sm[, 4])
  )
}

#' @rdname sm_its
#' @param x An `sm_its` object.
#' @param ... Ignored.
#' @return `print` returns `x` invisibly.
#' @export
print.sm_its <- function(x, ...) {
  cli::cli_h1("<sm_its>")
  cli::cli_text("{.strong Outcome:} {x$outcome}   {.strong Family:} {x$family}")
  cli::cli_text("{.strong Intervention year:} {x$intervention_year}")
  if (!is.null(x$leadership)) {
    cli::cli_text("{.strong Leadership:} ",
                  .sm_cli_escape(.sm_leadership_text(x$leadership)))
  }
  .sm_print_impact_source(x$impact_source)
  if (length(x$dropped_years) > 0L) {
    cli::cli_text("{.strong Dropped (no usable data):} {x$dropped_years}")
  }
  if (length(x$provisional_years) > 0L) {
    cli::cli_text("{.strong Excluded (citation-immature):} {x$provisional_years}")
  }
  cli::cli_text("")
  cli::cli_h3("Segmented regression coefficients")
  cf <- x$coefficients
  labels <- c(
    "(Intercept)" = "Baseline level",
    "time" = "Pre-trend (slope)",
    "intervention" = "Level change",
    "time_since" = "Slope change"
  )
  for (i in seq_len(nrow(cf))) {
    lab <- labels[cf$term[i]]
    lab <- if (is.na(lab)) cf$term[i] else lab
    cli::cli_text(
      "  {lab}: {round(cf$estimate[i], 4)} [{round(cf$conf.low[i], 4)}, {round(cf$conf.high[i], 4)}]  (p = {format.pval(cf$p.value[i], digits = 2)})"
    )
  }
  invisible(x)
}

#' @rdname sm_its
#' @param object An `sm_its` object.
#' @return `summary` returns the tidy coefficient tibble.
#' @export
summary.sm_its <- function(object, ...) {
  object$coefficients
}

#' @rdname sm_its
#' @param object An `sm_its` object.
#' @return `autoplot` returns a `ggplot`.
#' @importFrom ggplot2 autoplot
#' @export
autoplot.sm_its <- function(object, ...) {
  s <- object$series
  iy <- object$intervention_year
  s$segment <- ifelse(s$year < iy, "pre", "post")
  pal <- sm_palette_qualitative(2)

  post <- dplyr::filter(s, .data$year >= iy)

  p <- ggplot2::ggplot(s, ggplot2::aes(.data$year)) +
    ggplot2::geom_vline(xintercept = iy - 0.5, linetype = "dotted",
                        colour = "grey40") +
    ggplot2::geom_point(ggplot2::aes(y = .data$observed),
                        colour = pal[1], size = 2) +
    ggplot2::geom_line(ggplot2::aes(y = .data$fitted, group = .data$segment),
                       colour = pal[2], linewidth = 1)

  if (nrow(post) > 0L) {
    p <- p + ggplot2::geom_line(
      data = post,
      ggplot2::aes(y = .data$counterfactual),
      linetype = "dashed", colour = "grey30", linewidth = 0.8
    )
  }

  p +
    sm_theme() +
    ggplot2::labs(
      title = paste0("Interrupted time series: ", object$outcome),
      subtitle = paste0("Intervention at ", iy,
                        " (dashed = counterfactual)"),
      x = "Year", y = object$outcome
    )
}

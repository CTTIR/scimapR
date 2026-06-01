# Part C1: interrupted time series (ITS) for policy evaluation.

#' Compute a yearly outcome series from a corpus
#'
#' @description
#' Aggregates one of several outcomes to a per-year series. Shared by
#' [sm_its()] and [sm_did()].
#'
#' @param corpus An `sm_corpus`.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`.
#' @param work_ids Optional character vector restricting to a subset of works.
#' @param call Caller environment.
#' @return A tibble with columns `year`, `value`, `n_works`.
#' @noRd
.sm_yearly_outcome <- function(corpus, outcome, work_ids = NULL,
                               call = rlang::caller_env()) {
  works <- corpus$works
  if (!is.null(work_ids)) {
    works <- dplyr::filter(works, .data$work_id %in% work_ids)
  }
  works <- dplyr::filter(works, !is.na(.data$year))

  empty <- tibble::tibble(year = integer(), value = double(),
                          n_works = integer())
  if (nrow(works) == 0L) return(empty)

  switch(outcome,
    count = {
      works %>%
        dplyr::count(.data$year, name = "n_works") %>%
        dplyr::mutate(value = as.double(.data$n_works)) %>%
        dplyr::arrange(.data$year) %>%
        dplyr::select("year", "value", "n_works")
    },
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
      fnci <- sm_metric_fnci(corpus, call = call)
      fnci <- dplyr::filter(fnci, .data$work_id %in% works$work_id)
      fnci %>%
        dplyr::filter(!is.na(.data$fnci)) %>%
        dplyr::group_by(.data$year) %>%
        dplyr::summarise(
          n_works = dplyr::n(),
          value = mean(.data$fnci, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::arrange(.data$year)
    },
    leadership = {
      a <- corpus$authorships
      a <- dplyr::filter(a, .data$work_id %in% works$work_id)
      lead <- a %>%
        dplyr::group_by(.data$work_id) %>%
        dplyr::summarise(
          has_lead = any(.data$is_corresponding %in% TRUE),
          .groups = "drop"
        )
      works %>%
        dplyr::select("work_id", "year") %>%
        dplyr::left_join(lead, by = "work_id") %>%
        dplyr::mutate(has_lead = ifelse(is.na(.data$has_lead), FALSE,
                                        .data$has_lead)) %>%
        dplyr::group_by(.data$year) %>%
        dplyr::summarise(
          n_works = dplyr::n(),
          value = mean(.data$has_lead),
          .groups = "drop"
        ) %>%
        dplyr::arrange(.data$year)
    }
  )
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
#' @param intervention_year Integer year at which the intervention takes effect.
#' @param outcome One of `"count"` (works per year), `"share_q1"` (share of
#'   Q1-journal works; needs a `quartile` column), `"cnci"` (mean
#'   field-normalised citation impact per year), `"leadership"` (share of works
#'   with a corresponding/leadership author).
#' @param family Optional GLM family (a `family` object, generator function, or
#'   name). Defaults to Poisson for `"count"` and Gaussian otherwise; document
#'   your choice when overriding.
#' @param lag Citation-maturity lag in years (default `2`). For citation-based
#'   outcomes (`"cnci"`), the most recent `lag` years are citation-immature and
#'   are excluded from the fit; this is reported in the print method.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_its` S3 object with components: `model` (the fitted `glm`),
#'   `coefficients` (tidy tibble: `term`, `estimate`, `std.error`, `conf.low`,
#'   `conf.high`, `statistic`, `p.value`), `series` (tibble: `year`,
#'   `observed`, `fitted`, `counterfactual`), and metadata (`outcome`,
#'   `intervention_year`, `family`, `lag`, `provisional_years`).
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
sm_its <- function(corpus,
                   intervention_year,
                   outcome = c("count", "share_q1", "cnci", "leadership"),
                   family = NULL,
                   lag = NULL,
                   call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  outcome <- rlang::arg_match(outcome, error_call = call)
  if (!rlang::is_integerish(intervention_year, n = 1)) {
    cli::cli_abort("{.arg intervention_year} must be a single year.",
                   call = call)
  }
  intervention_year <- as.integer(intervention_year)
  lag <- as.integer(lag %||% 2L)

  series <- .sm_yearly_outcome(corpus, outcome, call = call)
  if (nrow(series) < 4L) {
    cli::cli_abort(c(
      "Too few yearly observations to fit an ITS ({nrow(series)} found).",
      "i" = "At least 4 distinct years are required."
    ), call = call)
  }

  # citation-maturity exclusion for citation-based outcomes, using the same
  # cutoff rule as sm_citation_maturity() (Part D1).
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

  coefs <- .sm_tidy_glm(fit)

  # counterfactual: pre-intervention trend projected across all years
  cf_data <- df
  cf_data$intervention <- 0L
  cf_data$time_since <- 0L
  counterfactual <- as.numeric(stats::predict(fit, newdata = cf_data,
                                              type = "response"))
  fitted_vals <- as.numeric(stats::predict(fit, type = "response"))

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
      provisional_years = provisional_years
    ),
    class = "sm_its"
  )
}

#' Tidy a glm into a coefficient tibble with Wald CIs (no broom dependency)
#' @noRd
.sm_tidy_glm <- function(fit, conf_level = 0.95) {
  sm <- stats::coef(summary(fit))
  est <- sm[, 1]
  se <- sm[, 2]
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  tibble::tibble(
    term = rownames(sm),
    estimate = unname(est),
    std.error = unname(se),
    conf.low = unname(est - z * se),
    conf.high = unname(est + z * se),
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

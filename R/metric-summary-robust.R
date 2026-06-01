# Part E1: robust impact summaries.

#' Robust summary of a heavy-tailed impact metric
#'
#' @description
#' Summarises a work-level impact metric robustly. Citation-based metrics are
#' heavy-tailed, so the mean is a poor central estimate; this function reports
#' the median with a bootstrap confidence interval and the proportion of papers
#' in the global top 10% by citations (`%PP(top 10%)`), alongside the mean for
#' comparison.
#'
#' @param corpus An `sm_corpus`.
#' @param metric Which work-level metric to summarise: `"citations"`
#'   (`cited_by_count`), `"cnci"` (field-normalised citation impact via
#'   [sm_metric_fnci()]), or `"rcr"` ([sm_metric_rcr()]).
#' @param robust Logical (default `TRUE`). When `TRUE`, report the median with a
#'   bootstrap CI and `pp_top10`. When `FALSE`, report only `n`, `mean`, and
#'   `median` (no resampling).
#' @param n_boot Number of bootstrap resamples for the median CI (default
#'   `2000`).
#' @param conf Confidence level for the bootstrap interval (default `0.95`).
#' @param top_pct Top-fraction threshold for `pp_top10` (default `0.1`, i.e.
#'   the top 10% of works by citation count within the corpus).
#' @param seed Optional integer seed for reproducible bootstrap resampling. When
#'   supplied, the RNG state is saved and restored so the call has no global
#'   side effect (mirroring scimapR's reproducibility guarantees).
#' @param call Caller environment for error reporting.
#'
#' @return A one-row tibble: `metric`, `n`, `mean`, `median`, and -- when
#'   `robust = TRUE` -- `median_ci_low`, `median_ci_high`, `pp_top10`,
#'   `n_boot`. Type-stable: an empty corpus returns a one-row tibble with `n = 0`
#'   and `NA` statistics.
#'
#' @details
#' The bootstrap uses base-R resampling by default; if the optional \pkg{boot}
#' package is installed it is used instead (percentile interval). `pp_top10` is
#' computed against the within-corpus citation distribution (the global top-10%
#' threshold is the upper `top_pct` quantile of `cited_by_count`).
#'
#' @family counting
#' @seealso [sm_summary_works()], [sm_count()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 100, seed = 1)
#' sm_metric_summary(corpus, metric = "citations", seed = 1)
sm_metric_summary <- function(corpus,
                              metric = c("citations", "cnci", "rcr"),
                              robust = TRUE,
                              n_boot = 2000L,
                              conf = 0.95,
                              top_pct = 0.1,
                              seed = NULL,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  metric <- rlang::arg_match(metric, error_call = call)
  .check_flag(robust, call = call)
  n_boot <- .check_positive_int(n_boot, call = call)

  empty <- tibble::tibble(
    metric = metric, n = 0L, mean = NA_real_, median = NA_real_,
    median_ci_low = NA_real_, median_ci_high = NA_real_,
    pp_top10 = NA_real_, n_boot = if (robust) n_boot else NA_integer_
  )
  if (!robust) empty <- empty[, c("metric", "n", "mean", "median")]

  vals <- .metric_values(corpus, metric, call = call)
  vals <- vals[!is.na(vals)]
  if (length(vals) == 0L) return(empty)

  cites <- suppressWarnings(as.numeric(corpus$works$cited_by_count))
  cites <- cites[!is.na(cites)]
  pp_top10 <- if (length(cites) > 0L) {
    thr <- stats::quantile(cites, probs = 1 - top_pct, names = FALSE,
                           type = 7)
    round(mean(cites >= thr), 4)
  } else {
    NA_real_
  }

  base <- tibble::tibble(
    metric = metric,
    n = length(vals),
    mean = round(mean(vals), 4),
    median = round(stats::median(vals), 4)
  )
  if (!robust) return(base)

  ci <- .bootstrap_median_ci(vals, n_boot = n_boot, conf = conf, seed = seed)
  tibble::tibble(
    metric = metric,
    n = length(vals),
    mean = base$mean,
    median = base$median,
    median_ci_low = round(ci[1], 4),
    median_ci_high = round(ci[2], 4),
    pp_top10 = pp_top10,
    n_boot = n_boot
  )
}

#' Extract a work-level metric vector
#' @noRd
.metric_values <- function(corpus, metric, call = rlang::caller_env()) {
  switch(metric,
    citations = suppressWarnings(as.numeric(corpus$works$cited_by_count)),
    cnci = sm_metric_fnci(corpus, call = call)$fnci,
    rcr = {
      r <- sm_metric_rcr(corpus, call = call)
      rcr_col <- intersect(c("rcr", "expected_rate"), names(r))[1]
      if (is.na(rcr_col)) r[[ncol(r)]] else r[[rcr_col]]
    }
  )
}

#' Bootstrap percentile CI for the median
#'
#' Uses the optional \pkg{boot} package when available, otherwise base-R
#' resampling. RNG state is saved/restored when `seed` is supplied.
#' @noRd
.bootstrap_median_ci <- function(x, n_boot = 2000L, conf = 0.95, seed = NULL) {
  if (length(x) < 2L) return(c(NA_real_, NA_real_))
  alpha <- (1 - conf) / 2
  probs <- c(alpha, 1 - alpha)

  old_seed <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv())
  } else {
    NULL
  }
  on.exit({
    if (!is.null(seed)) {
      if (!is.null(old_seed)) {
        assign(".Random.seed", old_seed, envir = globalenv())
      } else {
        rm(".Random.seed", envir = globalenv())
      }
    }
  }, add = TRUE)
  if (!is.null(seed)) set.seed(seed)

  if (rlang::is_installed("boot")) {
    bo <- boot::boot(x, statistic = function(d, i) stats::median(d[i]),
                     R = n_boot)
    qs <- stats::quantile(bo$t, probs = probs, names = FALSE, na.rm = TRUE)
    return(qs)
  }

  n <- length(x)
  meds <- numeric(n_boot)
  for (b in seq_len(n_boot)) {
    meds[b] <- stats::median(x[sample.int(n, n, replace = TRUE)])
  }
  stats::quantile(meds, probs = probs, names = FALSE, na.rm = TRUE)
}

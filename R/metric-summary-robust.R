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
#'   (`cited_by_count`), `"cnci"` (field-normalised citation impact,
#'   resolved as in [sm_its()]: a stored impact column such as `works$cnci`
#'   or `works$fwci`, a `corpus$metrics` table, else the FNCI that
#'   [sm_metric_fnci()] derives from citation counts), `"rcr"`
#'   ([sm_metric_rcr()]) or `"fwci"` (OpenAlex's field-weighted citation
#'   impact, `works$fwci`; see [sm_enrich_openalex_impact()]).
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
#' @param min_cell For `metric = "cnci"`: `NULL` (default) or a positive
#'   integer, passed to [sm_metric_fnci()] when the impact is derived from
#'   citation counts, as in [sm_its()].
#' @param call Caller environment for error reporting.
#'
#' @return A one-row tibble: `metric`, `n`, `mean`, `median`, and -- when
#'   `robust = TRUE` -- `median_ci_low`, `median_ci_high`, `pp_top10`,
#'   `n_boot`. Type-stable: an empty corpus, or for `"cnci"` a corpus
#'   without usable impact data, returns a one-row tibble with `n = 0` and
#'   `NA` statistics. The attribute `impact_source` (character) names where
#'   the values come from: for `"cnci"` the same label as the
#'   `impact_source` of [sm_its()] (such as `"works$fwci (OpenAlex)"`), for
#'   `"fwci"` `"works$fwci (OpenAlex)"`, for `"citations"`
#'   `"works$cited_by_count"` and for `"rcr"` `"sm_metric_rcr()"`; it is
#'   `NA` on the `n = 0` row. For `"cnci"` and `"fwci"` a message (class
#'   `scimapR_impact_source`) names the source too.
#'
#' @details
#' The bootstrap uses base-R resampling by default; if the optional \pkg{boot}
#' package is installed it is used instead (percentile interval). `pp_top10` is
#' computed against the within-corpus citation distribution (the global top-10%
#' threshold is the upper `top_pct` quantile of `cited_by_count`).
#'
#' For `"cnci"` and `"fwci"` only works with a finite value count, and for
#' `"cnci"` only works of `corpus$works` (a `corpus$metrics` table may hold
#' others). `metric = "fwci"` aborts (class `scimapR_no_fwci`) when the
#' works have no `fwci` value.
#'
#' @family counting
#' @seealso [sm_summary_works()], [sm_count()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 100, seed = 1)
#' sm_metric_summary(corpus, metric = "citations", seed = 1)
#'
#' # the real-use fixture carries OpenAlex's FWCI, which "cnci" then uses
#' fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
#' s <- sm_metric_summary(fix, metric = "cnci", robust = FALSE)
#' attr(s, "impact_source")
sm_metric_summary <- function(corpus,
                              metric = c("citations", "cnci", "rcr", "fwci"),
                              robust = TRUE,
                              n_boot = 2000L,
                              conf = 0.95,
                              top_pct = 0.1,
                              seed = NULL,
                              min_cell = NULL,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  metric <- rlang::arg_match(metric, error_call = call)
  .check_flag(robust, call = call)
  n_boot <- .check_positive_int(n_boot, call = call)
  .check_min_cell(min_cell, call = call)

  empty <- tibble::tibble(
    metric = metric, n = 0L, mean = NA_real_, median = NA_real_,
    median_ci_low = NA_real_, median_ci_high = NA_real_,
    pp_top10 = NA_real_, n_boot = if (robust) n_boot else NA_integer_
  )
  if (!robust) empty <- empty[, c("metric", "n", "mean", "median")]
  attr(empty, "impact_source") <- NA_character_
  if (nrow(corpus$works) == 0L) return(empty)

  resolved <- .metric_values(corpus, metric, min_cell = min_cell, call = call)
  if (is.null(resolved)) return(empty)
  if (metric %in% c("cnci", "fwci")) {
    cli::cli_inform(
      c("i" = "Impact source: {.field {resolved$source}}."),
      class = "scimapR_impact_source"
    )
  }
  vals <- resolved$values
  vals <- if (metric %in% c("cnci", "fwci")) {
    vals[is.finite(vals)]
  } else {
    vals[!is.na(vals)]
  }
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
  if (!robust) {
    attr(base, "impact_source") <- resolved$source
    return(base)
  }

  ci <- .bootstrap_median_ci(vals, n_boot = n_boot, conf = conf, seed = seed)
  out <- tibble::tibble(
    metric = metric,
    n = length(vals),
    mean = base$mean,
    median = base$median,
    median_ci_low = round(ci[1], 4),
    median_ci_high = round(ci[2], 4),
    pp_top10 = pp_top10,
    n_boot = n_boot
  )
  attr(out, "impact_source") <- resolved$source
  out
}

#' Extract a work-level metric vector and name its source
#'
#' `"cnci"` goes through the impact resolver of sm_its(); a corpus without
#' usable impact data gives `NULL` (the summary's `n = 0` row) instead of
#' the resolver's error.
#' @return A list: `values` (numeric) and `source` (character), or `NULL`.
#' @noRd
.metric_values <- function(corpus, metric, min_cell = NULL,
                           call = rlang::caller_env()) {
  works <- corpus$works
  switch(metric,
    citations = list(
      values = suppressWarnings(as.numeric(works$cited_by_count)),
      source = "works$cited_by_count"
    ),
    cnci = {
      res <- tryCatch(
        .resolve_impact_values(corpus, min_cell = min_cell, call = call),
        scimapR_no_impact_data = function(cnd) NULL
      )
      if (is.null(res)) return(NULL)
      keep <- res$values$work_id %in% works$work_id
      list(values = res$values$value[keep], source = res$source)
    },
    fwci = {
      fwci <- if ("fwci" %in% names(works)) {
        suppressWarnings(as.numeric(works$fwci))
      }
      if (is.null(fwci) || !any(is.finite(fwci))) {
        cli::cli_abort(c(
          paste0("Metric {.val fwci} needs a {.field fwci} column with ",
                 "values in {.code corpus$works}."),
          "i" = paste0("Add OpenAlex's FWCI with ",
                       "{.fn sm_enrich_openalex_impact}, or use ",
                       "{.code metric = \"cnci\"}.")
        ), class = "scimapR_no_fwci", call = call)
      }
      list(values = fwci, source = "works$fwci (OpenAlex)")
    },
    rcr = {
      r <- sm_metric_rcr(corpus, call = call)
      rcr_col <- intersect(c("rcr", "expected_rate"), names(r))[1]
      list(values = if (is.na(rcr_col)) r[[ncol(r)]] else r[[rcr_col]],
           source = "sm_metric_rcr()")
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

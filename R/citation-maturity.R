# Part D1: citation maturity flagging.

#' Determine the most recent citation-mature year for a corpus
#'
#' The "as-of" year is taken from `metadata$last_refresh` when available,
#' otherwise from the maximum publication year. Works published after
#' `as_of - lag` are citation-immature. Returns the cutoff year (the last
#' year considered mature), or `NA_integer_` if no years are present.
#' @noRd
.maturity_cutoff <- function(corpus, lag = 2L) {
  lag <- as.integer(lag)
  years <- corpus$works$year
  years <- years[!is.na(years)]

  as_of <- NA_integer_
  lr <- corpus$metadata$last_refresh
  if (!is.null(lr) && !is.na(lr)) {
    as_of <- suppressWarnings(as.integer(format(as.Date(lr), "%Y")))
  }
  if (is.na(as_of)) {
    if (length(years) == 0L) return(NA_integer_)
    as_of <- max(years)
  }
  as_of - lag
}

#' Flag citation-immature recent years
#'
#' @description
#' Adds citation-maturity flags to the `works` table so that downstream
#' trend and impact functions can shade or exclude recent, citation-immature
#' years instead of treating their (artificially low) citation counts as final.
#'
#' Works published within the most recent `lag` years -- relative to the
#' corpus's "as-of" date (`metadata$last_refresh` if present, else the maximum
#' publication year) -- are flagged provisional.
#'
#' @param corpus An `sm_corpus`.
#' @param lag Integer number of recent years to treat as citation-immature
#'   (default `2`).
#' @param call Caller environment for error reporting.
#'
#' @return The `corpus` with two logical columns added to `works`:
#'   `citation_mature` (`TRUE` when the year is mature) and `cnci_provisional`
#'   (the negation; `TRUE` when citation-based indicators should be treated as
#'   provisional). Type-stable: an empty corpus gains the columns with 0 rows.
#'
#' @family counting
#' @seealso [sm_its()], [sm_metric_fnci()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 20, seed = 1)
#' corpus <- sm_citation_maturity(corpus, lag = 2)
#' table(corpus$works$cnci_provisional)
sm_citation_maturity <- function(corpus, lag = 2L, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  lag <- .check_positive_int(lag + 1L, call = call) - 1L  # allow lag = 0

  works <- corpus$works
  if (nrow(works) == 0L) {
    works$citation_mature <- logical()
    works$cnci_provisional <- logical()
    corpus$works <- works
    return(corpus)
  }

  cutoff <- .maturity_cutoff(corpus, lag)
  mature <- if (is.na(cutoff)) {
    rep(NA, nrow(works))
  } else {
    works$year <= cutoff
  }
  works$citation_mature <- mature
  works$cnci_provisional <- !mature
  corpus$works <- works
  corpus
}

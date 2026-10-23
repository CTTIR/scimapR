#' Open access status audit
#'
#' @description
#' Audits the open-access (OA) status distribution of works in a corpus.
#' Uses the statuses of [sm_oa_statuses()]; every recognised status except
#' `closed` is open. Missing and unrecognised values are unknown.
#' The open percentage uses all works as the denominator and agrees with
#' [sm_summary_works()] to one decimal place.
#'
#' The result includes counts and percentages for each OA category, as
#' well as a coverage metric.
#'
#' @param corpus An `sm_corpus` object.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_oa` S3 object containing:
#' \describe{
#'   \item{distribution}{Tibble with columns `oa_status`, `count`, `pct`,
#'     and logical `is_open` (`NA` for unknown statuses).}
#'   \item{pct_open}{Percentage of works with an open status in
#'     [sm_oa_statuses()].}
#'   \item{coverage}{Proportion of works with a known OA status.}
#'   \item{n_works}{Total number of works.}
#' }
#'
#' @family audit
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' oa <- sm_audit_oa(corpus)
#' print(oa)
sm_audit_oa <- function(corpus,
                        call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  n_works <- nrow(corpus$works)

  if (n_works == 0L) {
    return(.empty_audit_oa())
  }

  oa_vals <- .normalize_oa_status(corpus$works$oa_status)
  open <- .oa_is_open(oa_vals)

  # Distribution
  dist <- tibble::tibble(oa_status = oa_vals) |>
    dplyr::mutate(
      oa_status = dplyr::if_else(is.na(.data$oa_status), "unknown",
                                  .data$oa_status)
    ) |>
    dplyr::count(.data$oa_status) |>
    dplyr::mutate(pct = round(100 * .data$n / sum(.data$n), 1)) |>
    dplyr::rename(count = "n") |>
    dplyr::arrange(dplyr::desc(.data$count))

  dist$is_open <- .oa_is_open(dist$oa_status)
  pct_open <- round(100 * sum(open %in% TRUE) / n_works, 1)
  coverage <- sum(!is.na(open)) / n_works

  structure(
    list(
      distribution = dist,
      pct_open = pct_open,
      coverage = round(coverage, 3),
      n_works = n_works
    ),
    class = "sm_audit_oa"
  )
}

#' Empty OA audit result
#' @noRd
.empty_audit_oa <- function() {
  structure(
    list(
      distribution = tibble::tibble(
        oa_status = character(),
        count = integer(),
        pct = double(),
        is_open = logical()
      ),
      pct_open = 0.0,
      coverage = 0.0,
      n_works = 0L
    ),
    class = "sm_audit_oa"
  )
}

#' Open access status audit
#'
#' @description
#' Audits the open-access (OA) status distribution of works in a corpus.
#' Uses the `oa_status` column in the works table, which may have values
#' such as `"gold"`, `"green"`, `"hybrid"`, `"bronze"`, or `"closed"`.
#'
#' The result includes counts and percentages for each OA category, as
#' well as a coverage metric.
#'
#' @param corpus An `sm_corpus` object.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_oa` S3 object containing:
#' \describe{
#'   \item{distribution}{Tibble with columns `oa_status`, `count`, `pct`.}
#'   \item{pct_open}{Percentage of works that are open access (gold, green,
#'     hybrid, or bronze).}
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

  oa_vals <- corpus$works$oa_status

  # Distribution
  dist <- tibble::tibble(oa_status = oa_vals) %>%
    dplyr::mutate(
      oa_status = dplyr::if_else(is.na(.data$oa_status), "unknown",
                                  .data$oa_status)
    ) %>%
    dplyr::count(.data$oa_status) %>%
    dplyr::mutate(pct = round(100 * .data$n / sum(.data$n), 1)) %>%
    dplyr::rename(count = .data$n) %>%
    dplyr::arrange(dplyr::desc(.data$count))

  # OA percentage (anything that is not closed or unknown)
  open_statuses <- c("gold", "green", "hybrid", "bronze")
  n_open <- sum(tolower(oa_vals) %in% open_statuses, na.rm = TRUE)
  pct_open <- round(100 * n_open / n_works, 1)

  # Coverage
  n_known <- sum(!is.na(oa_vals))
  coverage <- n_known / n_works

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
        pct = double()
      ),
      pct_open = 0.0,
      coverage = 0.0,
      n_works = 0L
    ),
    class = "sm_audit_oa"
  )
}

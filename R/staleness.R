#' Check corpus staleness
#'
#' @description
#' Inspects each work in a corpus and reports how long ago it was last
#' refreshed. Works with `last_refreshed` older than 30 days are flagged
#' as stale. This is useful before calling [sm_refresh()] to preview which
#' works would be updated.
#'
#' @param corpus An `sm_corpus` object.
#' @param threshold_days Numeric. Number of days after which a work is
#'   considered stale. Defaults to 30.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns:
#' \describe{
#'   \item{work_id}{Work identifier.}
#'   \item{last_refreshed}{POSIXct timestamp of last refresh.}
#'   \item{age_days}{Number of days since last refresh.}
#'   \item{is_stale}{Logical; `TRUE` if `age_days > threshold_days`.}
#' }
#'
#' @family refresh
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_staleness(corpus)
sm_staleness <- function(corpus,
                         threshold_days = 30,
                         call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  if (nrow(corpus$works) == 0L) {
    return(tibble::tibble(
      work_id = character(),
      last_refreshed = as.POSIXct(character()),
      age_days = double(),
      is_stale = logical()
    ))
  }

  now <- Sys.time()

  result <- tibble::tibble(
    work_id = corpus$works$work_id,
    last_refreshed = corpus$works$last_refreshed,
    age_days = as.double(
      difftime(now, corpus$works$last_refreshed, units = "days")
    ),
    is_stale = .data$age_days > threshold_days
  )

  # Handle NA last_refreshed as stale

  result$age_days[is.na(result$last_refreshed)] <- Inf
  result$is_stale[is.na(result$last_refreshed)] <- TRUE

  n_stale <- sum(result$is_stale, na.rm = TRUE)
  n_total <- nrow(result)

  cli::cli_inform(c(
    "i" = "{n_stale} of {n_total} work{?s} {?is/are} stale (>{threshold_days} days)."
  ))

  result
}

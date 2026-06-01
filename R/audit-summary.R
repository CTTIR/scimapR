#' Combined equity audit summary
#'
#' @description
#' Runs all available equity audits (geographic, gender, funding, OA status)
#' on a corpus and returns a combined summary. Individual audit results can
#' be passed as `...` arguments to avoid re-computation; any missing audits
#' are run with default parameters.
#'
#' @param corpus An `sm_corpus` object.
#' @param ... Optional pre-computed audit objects (e.g., `sm_audit_geographic`,
#'   `sm_audit_gender`, `sm_audit_funding`, `sm_audit_oa`). If provided,
#'   these are included directly rather than being re-run.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_summary` S3 object containing:
#' \describe{
#'   \item{geographic}{An `sm_audit_geographic` result.}
#'   \item{gender}{An `sm_audit_gender` result.}
#'   \item{funding}{An `sm_audit_funding` result.}
#'   \item{oa}{An `sm_audit_oa` result.}
#'   \item{overview}{A one-row tibble summarising coverage across all audits.}
#' }
#'
#' @family audit
#' @export
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus()
#' summary_audit <- sm_audit_summary(corpus)
#' print(summary_audit)
#' }
sm_audit_summary <- function(corpus,
                             ...,
                             call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  dots <- list(...)

  # Extract pre-computed audits from dots
  geo <- .extract_audit(dots, "sm_audit_geographic")
  gender <- .extract_audit(dots, "sm_audit_gender")
  funding <- .extract_audit(dots, "sm_audit_funding")
  oa <- .extract_audit(dots, "sm_audit_oa")

  # Run missing audits, with a progress bar so long runs on large corpora
  # show motion rather than appearing to hang.
  cli::cli_progress_bar("Running equity audits", total = 4L,
                        .envir = environment())
  if (is.null(geo)) {
    geo <- sm_audit_geographic(corpus, call = call)
  }
  cli::cli_progress_update(.envir = environment())
  if (is.null(gender)) {
    gender <- sm_audit_gender(corpus, method = "manual", call = call)
  }
  cli::cli_progress_update(.envir = environment())
  if (is.null(funding)) {
    funding <- sm_audit_funding(corpus, call = call)
  }
  cli::cli_progress_update(.envir = environment())
  if (is.null(oa)) {
    oa <- sm_audit_oa(corpus, call = call)
  }
  cli::cli_progress_update(.envir = environment())
  cli::cli_progress_done(.envir = environment())

  # Build overview
  overview <- tibble::tibble(
    audit = c("geographic", "gender", "funding", "open_access"),
    coverage = c(
      geo$coverage,
      gender$coverage,
      funding$coverage,
      oa$coverage
    ),
    top_finding = c(
      if (nrow(geo$distribution) > 0L) {
        paste0(geo$distribution$group[1], " (",
               geo$distribution$pct[1], "%)")
      } else {
        "no data"
      },
      if (nrow(gender$distribution) > 0L) {
        paste0(gender$distribution$inferred_gender[1], " (",
               gender$distribution$pct[1], "%)")
      } else {
        "no data"
      },
      if (nrow(funding$funders) > 0L) {
        paste0(funding$funders$funder_name[1], " (",
               funding$funders$n_works[1], " works)")
      } else {
        "no data"
      },
      paste0(oa$pct_open, "% open access")
    )
  )

  structure(
    list(
      geographic = geo,
      gender = gender,
      funding = funding,
      oa = oa,
      overview = overview
    ),
    class = "sm_audit_summary"
  )
}

#' Extract a pre-computed audit from dots list
#' @noRd
.extract_audit <- function(dots, class_name) {
  for (d in dots) {
    if (inherits(d, class_name)) return(d)
  }
  NULL
}

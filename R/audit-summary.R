#' Combined equity audit summary
#'
#' @description
#' Runs all available equity audits (geographic, gender, funding, OA status)
#' on a corpus and returns a combined summary. Individual audit results can
#' be passed as `...` arguments to avoid re-computation; any missing audits
#' are run with default parameters, except that the gender audit uses
#' `method = "manual"` and audits that send web requests run only when
#' `online = TRUE`.
#'
#' @param corpus An `sm_corpus` object.
#' @param ... Optional pre-computed audit objects (e.g., `sm_audit_geographic`,
#'   `sm_audit_gender`, `sm_audit_funding`, `sm_audit_oa`). If provided,
#'   these are included directly rather than being re-run.
#' @param online Logical. Whether audits that send web requests may run.
#'   Only the funding audit does: [sm_audit_funding()] looks up every DOI on
#'   Crossref. With the default `FALSE`, a funding audit is included only
#'   when one is passed in `...`; otherwise it is reported as not run. Set
#'   `TRUE` to run it with its default Crossref source.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_summary` S3 object containing:
#' \describe{
#'   \item{geographic}{An `sm_audit_geographic` result.}
#'   \item{gender}{An `sm_audit_gender` result.}
#'   \item{funding}{An `sm_audit_funding` result. A funding audit that was
#'     not run has no funders, `source = "none"` and `coverage = NA`.}
#'   \item{oa}{An `sm_audit_oa` result.}
#'   \item{overview}{A tibble with one row per audit: `audit`, `coverage`
#'     (`NA` for an audit that was not run) and `top_finding`.}
#' }
#'
#' @family audit
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 50, n_authors = 20)
#' # The funding audit needs one Crossref request per DOI, so it is not run
#' # unless online = TRUE.
#' summary_audit <- sm_audit_summary(corpus)
#' summary_audit$overview
#'
#' # A precomputed audit is used as it is. This funding audit sends no
#' # request because its copy of the corpus has no DOIs.
#' no_doi <- corpus
#' no_doi$works$doi <- NA_character_
#' funding <- sm_audit_funding(no_doi)
#' summary_audit <- sm_audit_summary(corpus, funding)
#' print(summary_audit)
sm_audit_summary <- function(corpus,
                             ...,
                             online = FALSE,
                             call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  if (!rlang::is_bool(online)) {
    cli::cli_abort("{.arg online} must be {.code TRUE} or {.code FALSE}.",
                   call = call)
  }

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
  if (is.null(funding) && !online) {
    cli::cli_inform(c(
      "i" = paste("Skipped the funding audit, which sends one Crossref",
                  "request per DOI."),
      "i" = paste("Use {.code online = TRUE} to run it, or pass a",
                  "precomputed {.fn sm_audit_funding} result.")
    ))
    funding <- .not_run_audit_funding(nrow(corpus$works))
  }
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
      if (is.na(funding$coverage)) {
        "not run (needs online = TRUE)"
      } else if (nrow(funding$funders) > 0L) {
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

#' Funding audit that was not run: the shape of an empty audit, with no
#' source and unknown coverage
#' @noRd
.not_run_audit_funding <- function(n_works_total) {
  structure(
    list(
      funders = tibble::tibble(
        funder_name = character(),
        funder_doi = character(),
        n_works = integer(),
        pct = double()
      ),
      coverage = NA_real_,
      n_works_total = n_works_total,
      n_works_funded = NA_integer_,
      source = "none"
    ),
    class = "sm_audit_funding"
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

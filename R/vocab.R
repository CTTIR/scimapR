# B1: exported controlled vocabularies for the package's factor columns.
# These level sets are the single source of truth used both to factorise the
# emitted columns and for users to filter reliably.

#' @noRd
.aff_signal_levels <- function() {
  c("name_token", "email_domain", "postcode", "none")
}

#' @noRd
.aff_method_levels <- function() {
  c("pattern", "email_domain", "postcode", "none")
}

#' @noRd
.match_type_levels <- function() {
  c("doi", "title", "none")
}

#' Controlled vocabulary for affiliation match signals
#'
#' @description
#' The ordered set of values the `match_signal` column of
#' [sm_affiliation_match()] / [sm_affiliation_summary()] can take. Using this
#' helper (rather than hard-coding strings) means downstream filtering --- e.g.
#' separating institution-name matches from email-domain matches --- cannot
#' drift if the levels change.
#'
#' @param describe Logical; if `TRUE`, return a tibble of `level` + a short
#'   `description`. If `FALSE` (default), return the ordered character vector of
#'   levels (suitable for `factor(levels = )`).
#'
#' @return A character vector (ordered, highest matching priority first) or a
#'   tibble of `level`/`description`.
#'
#' @family affiliation
#' @seealso [sm_affiliation_match()], [sm_affiliation_methods()]
#' @export
#' @examples
#' sm_affiliation_signals()
#' sm_affiliation_signals(describe = TRUE)
sm_affiliation_signals <- function(describe = FALSE) {
  lv <- .aff_signal_levels()
  if (!isTRUE(describe)) return(lv)
  tibble::tibble(
    level = factor(lv, levels = lv),
    description = c(
      "Institution name token matched a dictionary pattern.",
      "Author email domain matched a dictionary email domain.",
      "Affiliation postcode matched a dictionary postcode (opt-in).",
      "No signal matched this authorship."
    )
  )
}

#' Controlled vocabulary for affiliation match methods
#'
#' @description
#' The set of values the `match_method` column of [sm_affiliation_match()] can
#' take.
#'
#' @param describe Logical; if `TRUE`, return a tibble of `level` +
#'   `description`, else the ordered character vector (default).
#' @return A character vector or a tibble.
#' @family affiliation
#' @seealso [sm_affiliation_signals()]
#' @export
#' @examples
#' sm_affiliation_methods()
sm_affiliation_methods <- function(describe = FALSE) {
  lv <- .aff_method_levels()
  if (!isTRUE(describe)) return(lv)
  tibble::tibble(
    level = factor(lv, levels = lv),
    description = c(
      "Dictionary regex pattern match.",
      "Email-domain fallback match.",
      "Postcode match (opt-in).",
      "No match."
    )
  )
}

#' Controlled vocabulary for coverage match types
#'
#' @description
#' The set of values the `match_type` column of [sm_coverage_audit()]'s
#' `matches` tibble (and [sm_reconcile()]'s) can take.
#'
#' @param describe Logical; if `TRUE`, return a tibble of `level` +
#'   `description`, else the ordered character vector (default).
#' @return A character vector or a tibble.
#' @family coverage
#' @seealso [sm_coverage_audit()], [sm_reconcile()]
#' @export
#' @examples
#' sm_match_types()
sm_match_types <- function(describe = FALSE) {
  lv <- .match_type_levels()
  if (!isTRUE(describe)) return(lv)
  tibble::tibble(
    level = factor(lv, levels = lv),
    description = c(
      "Matched by normalised DOI.",
      "Matched by fuzzy title similarity.",
      "No match."
    )
  )
}

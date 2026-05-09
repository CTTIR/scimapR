#' Validate corpus integrity
#'
#' @description
#' Check referential integrity across all corpus tables and report issues.
#'
#' @param corpus An `sm_corpus` object.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble of validation issues, or a 0-row tibble if clean.
#'
#' @family corpus
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' issues <- sm_validate(corpus)
#' nrow(issues)
sm_validate <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  issues <- tibble::tibble(
    table = character(),
    issue = character(),
    n_affected = integer()
  )

  orphan_auth <- setdiff(corpus$authorships$work_id, corpus$works$work_id)
  if (length(orphan_auth) > 0) {
    issues <- dplyr::bind_rows(issues, tibble::tibble(
      table = "authorships",
      issue = "work_id not in works",
      n_affected = length(orphan_auth)
    ))
  }

  orphan_ref <- setdiff(corpus$references$work_id, corpus$works$work_id)
  if (length(orphan_ref) > 0) {
    issues <- dplyr::bind_rows(issues, tibble::tibble(
      table = "references",
      issue = "work_id not in works",
      n_affected = length(orphan_ref)
    ))
  }

  orphan_con <- setdiff(corpus$concepts$work_id, corpus$works$work_id)
  if (length(orphan_con) > 0) {
    issues <- dplyr::bind_rows(issues, tibble::tibble(
      table = "concepts",
      issue = "work_id not in works",
      n_affected = length(orphan_con)
    ))
  }

  dup_wid <- sum(duplicated(corpus$works$work_id))
  if (dup_wid > 0) {
    issues <- dplyr::bind_rows(issues, tibble::tibble(
      table = "works",
      issue = "duplicate work_id",
      n_affected = as.integer(dup_wid)
    ))
  }

  issues
}

#' Validate corpus integrity
#'
#' @description
#' Check referential integrity across all corpus tables and report issues.
#' Checks work, author, source and institution links, duplicate lookup
#' IDs, and duplicate or orphan embedding row names.
#' A locked corpus with a stored hash is also checked for changed content.
#'
#' @param corpus An `sm_corpus` object.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with `table`, `issue` and `n_affected`, or a 0-row
#'   tibble with the same columns if clean. Missing links count distinct
#'   unresolved IDs; duplicates count surplus rows.
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

  yearly <- corpus$citations_by_year
  orphan_cby <- if (is.null(yearly)) {
    character()
  } else {
    setdiff(yearly$work_id, corpus$works$work_id)
  }
  if (length(orphan_cby) > 0) {
    issues <- dplyr::bind_rows(issues, tibble::tibble(
      table = "citations_by_year",
      issue = "work_id not in works",
      n_affected = length(orphan_cby)
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

  links <- list(
    c("authorships", "author_id", "authors"),
    c("authorships", "institution_id", "institutions"),
    c("works", "source_id", "sources")
  )
  for (link in links) {
    ids <- corpus[[link[1]]][[link[2]]]
    if (link[2] != "author_id") ids <- ids[!is.na(ids)]
    n <- length(setdiff(ids, corpus[[link[3]]][[link[2]]]))
    issues <- .validation_issue(issues, link[1],
                                paste(link[2], "not in", link[3]), n)
  }
  for (table in c("authors", "sources", "institutions")) {
    key <- paste0(sub("s$", "", table), "_id")
    issues <- .validation_issue(issues, table, paste("duplicate", key),
                                sum(duplicated(corpus[[table]][[key]])))
  }
  ids <- rownames(corpus$embeddings)
  issues <- .validation_issue(issues, "embeddings", "duplicate row name",
                              sum(duplicated(ids)))
  issues <- .validation_issue(issues, "embeddings", "row name not in works",
                              length(setdiff(ids, corpus$works$work_id)))
  .validation_issue(issues, "metadata", "content changed since sm_lock()",
                    as.integer(.lock_hash_mismatch(corpus)))
}

.validation_issue <- function(issues, table, issue, n) {
  if (n == 0L) return(issues)
  dplyr::bind_rows(issues, tibble::tibble(
    table = table, issue = issue, n_affected = as.integer(n)
  ))
}

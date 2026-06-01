#' Compare two corpora
#'
#' @description
#' `r lifecycle::badge("superseded")`
#'
#' Produces a detailed comparison between two `sm_corpus` objects, reporting
#' works added, removed, and changed; author differences; reference
#' differences; and screening changes. This is useful for auditing how a
#' corpus evolved between snapshots or after a refresh.
#'
#' This function compares strictly by internal `work_id`. For content-based
#' reconciliation across corpora that do not share identifiers (matching by
#' normalised DOI with a fuzzy title fallback), use [sm_reconcile()].
#'
#' @param corpus1 An `sm_corpus` object (the "before" state).
#' @param corpus2 An `sm_corpus` object (the "after" state).
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus_diff` S3 object (a list) with components:
#' \describe{
#'   \item{added}{Tibble of works in `corpus2` but not `corpus1`.}
#'   \item{removed}{Tibble of works in `corpus1` but not `corpus2`.}
#'   \item{changed}{Tibble of works present in both but with differing fields.}
#'   \item{summary}{A one-row summary tibble with counts.}
#'   \item{hash1}{Hash of `corpus1`.}
#'   \item{hash2}{Hash of `corpus2`.}
#' }
#'
#' @family reproducibility
#' @seealso [sm_reconcile()]
#' @export
#' @examples
#' \donttest{
#' c1 <- sm_example_corpus(seed = 1L)
#' c2 <- sm_example_corpus(seed = 2L)
#' d <- sm_diff_corpora(c1, c2)
#' print(d)
#' }
sm_diff_corpora <- function(corpus1,
                            corpus2,
                            call = rlang::caller_env()) {
  .check_sm_corpus(corpus1, arg = "corpus1", call = call)
  .check_sm_corpus(corpus2, arg = "corpus2", call = call)

  ids1 <- corpus1$works$work_id
  ids2 <- corpus2$works$work_id

  added_ids <- setdiff(ids2, ids1)
  removed_ids <- setdiff(ids1, ids2)
  common_ids <- intersect(ids1, ids2)

  # Added works
  added <- if (length(added_ids) > 0L) {
    dplyr::filter(corpus2$works, .data$work_id %in% added_ids)
  } else {
    .empty_works()
  }

  # Removed works
  removed <- if (length(removed_ids) > 0L) {
    dplyr::filter(corpus1$works, .data$work_id %in% removed_ids)
  } else {
    .empty_works()
  }

  # Changed works (compare common columns)
  changed <- .detect_changes(corpus1$works, corpus2$works, common_ids)

  # Author diff
  auth_added <- setdiff(corpus2$authors$author_id, corpus1$authors$author_id)
  auth_removed <- setdiff(corpus1$authors$author_id, corpus2$authors$author_id)

  # Reference diff
  ref_count1 <- nrow(corpus1$references)
  ref_count2 <- nrow(corpus2$references)

  # Screening diff
  scr_count1 <- nrow(corpus1$screening)
  scr_count2 <- nrow(corpus2$screening)

  summary_tbl <- tibble::tibble(
    works_added = length(added_ids),
    works_removed = length(removed_ids),
    works_changed = nrow(changed),
    works_unchanged = length(common_ids) - nrow(changed),
    authors_added = length(auth_added),
    authors_removed = length(auth_removed),
    refs_before = ref_count1,
    refs_after = ref_count2,
    screening_before = scr_count1,
    screening_after = scr_count2
 )

  hash1 <- tryCatch(sm_hash_corpus(corpus1), error = function(e) NA_character_)
  hash2 <- tryCatch(sm_hash_corpus(corpus2), error = function(e) NA_character_)

  result <- structure(
    list(
      added = added,
      removed = removed,
      changed = changed,
      summary = summary_tbl,
      hash1 = hash1,
      hash2 = hash2
    ),
    class = "sm_corpus_diff"
  )

  result
}

#' @rdname sm_diff_corpora
#' @param x An `sm_corpus_diff` object.
#' @param ... Ignored.
#' @export
print.sm_corpus_diff <- function(x, ...) {
  cli::cli_h1("<sm_corpus_diff>")

  s <- x$summary

  cli::cli_text("{.strong Works added:} {s$works_added}")
  cli::cli_text("{.strong Works removed:} {s$works_removed}")
  cli::cli_text("{.strong Works changed:} {s$works_changed}")
  cli::cli_text("{.strong Works unchanged:} {s$works_unchanged}")
  cli::cli_text("")
  cli::cli_text("{.strong Authors added:} {s$authors_added}")
  cli::cli_text("{.strong Authors removed:} {s$authors_removed}")
  cli::cli_text("{.strong References:} {s$refs_before} -> {s$refs_after}")
  cli::cli_text("{.strong Screening:} {s$screening_before} -> {s$screening_after}")
  cli::cli_text("")
  cli::cli_text("{.strong Hash (before):} {substr(x$hash1, 1, 12)}")
  cli::cli_text("{.strong Hash (after):}  {substr(x$hash2, 1, 12)}")

  invisible(x)
}

#' Detect field-level changes between two works tables
#' @noRd
.detect_changes <- function(works1, works2, common_ids) {
  if (length(common_ids) == 0L) {
    return(tibble::tibble(
      work_id = character(),
      field = character(),
      value_before = character(),
      value_after = character()
    ))
  }

  w1 <- dplyr::filter(works1, .data$work_id %in% common_ids)
  w2 <- dplyr::filter(works2, .data$work_id %in% common_ids)

  w1 <- dplyr::arrange(w1, .data$work_id)
  w2 <- dplyr::arrange(w2, .data$work_id)

  compare_cols <- intersect(names(w1), names(w2))
  compare_cols <- setdiff(compare_cols, c("work_id", "last_refreshed"))

  changes <- list()

  for (col in compare_cols) {
    v1 <- as.character(w1[[col]])
    v2 <- as.character(w2[[col]])
    differs <- !is.na(v1) & !is.na(v2) & v1 != v2 |
               is.na(v1) & !is.na(v2) |
               !is.na(v1) & is.na(v2)

    if (any(differs)) {
      changes[[col]] <- tibble::tibble(
        work_id = w1$work_id[differs],
        field = col,
        value_before = v1[differs],
        value_after = v2[differs]
      )
    }
  }

  if (length(changes) == 0L) {
    return(tibble::tibble(
      work_id = character(),
      field = character(),
      value_before = character(),
      value_after = character()
    ))
  }

  dplyr::bind_rows(changes)
}

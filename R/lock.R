#' Lock or unlock a corpus
#'
#' @description
#' Locking a corpus prevents mutation by [sm_refresh()] and other modifying
#' operations. This is useful for archival or when you want to guarantee
#' reproducibility after generating a [sm_certificate()].
#'
#' `sm_lock()` sets `metadata$is_locked = TRUE` with an optional reason.
#' `sm_unlock()` reverses the lock but requires explicit confirmation to
#' prevent accidental unlocking of archived corpora.
#'
#' @details
#' Merging, deduplication, materialisation, citation maturity, enrichment,
#' embedding changes, clustering, labelling, affiliation matching and
#' screening refuse locked inputs, as do refreshing and input registration.
#' Subsets remain locked but lose their stored lock hash. Merged corpora
#' are unlocked; unlock the inputs explicitly before merging.
#'
#' The lock records a content hash. [sm_certificate()] warns and
#' [sm_validate()] reports when direct edits changed that content.
#' Printing shows only the lock status and does not hash the corpus.
#' Earlier locked corpora without a stored hash are not checked.
#'
#' @param corpus An `sm_corpus` object.
#' @param reason Optional character string documenting why the corpus was
#'   locked (e.g., `"submitted for review"`, `"certificate generated"`).
#' @param confirm Logical. Must be `TRUE` to actually unlock. This safeguard
#'   prevents accidental unlocking of archived corpora.
#' @param call Caller environment for error reporting.
#'
#' @return A modified `sm_corpus` with updated lock status.
#'
#' @family refresh
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' locked <- sm_lock(corpus, reason = "archival snapshot")
#' locked$metadata$is_locked
#'
#' unlocked <- sm_unlock(locked, confirm = TRUE)
#' unlocked$metadata$is_locked
sm_lock <- function(corpus,
                    reason = NULL,
                    call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(reason, allow_null = TRUE, call = call)

  if (isTRUE(corpus$metadata$is_locked)) {
    cli::cli_inform(c("i" = "Corpus is already locked."))
    return(corpus)
  }

  corpus$metadata$is_locked <- TRUE
  corpus$metadata$locked_at <- Sys.time()
  corpus$metadata$lock_reason <- reason %||% NA_character_
  corpus$metadata$lock_hash <- sm_hash_corpus(corpus)

  cli::cli_inform(c(
    "v" = "Corpus locked.",
    "i" = if (!is.null(reason)) "Reason: {reason}"
  ))

  corpus
}

#' @rdname sm_lock
#' @export
sm_unlock <- function(corpus,
                      confirm = FALSE,
                      call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_flag(confirm, call = call)

  if (!isTRUE(corpus$metadata$is_locked)) {
    cli::cli_inform(c("i" = "Corpus is not locked."))
    return(corpus)
  }

  if (!isTRUE(confirm)) {
    cli::cli_abort(
      c(
        "Corpus is locked. Set {.arg confirm = TRUE} to unlock.",
        "i" = if (!is.na(corpus$metadata$lock_reason %||% NA_character_)) {
          paste0("Lock reason: ", corpus$metadata$lock_reason)
        }
      ),
      call = call
    )
  }

  corpus$metadata$is_locked <- FALSE
  corpus$metadata$locked_at <- NULL
  corpus$metadata$lock_reason <- NULL
  corpus$metadata$lock_hash <- NULL

  cli::cli_inform(c("v" = "Corpus unlocked."))

  corpus
}

#' Check whether a corpus is locked (internal helper)
#' @noRd
.check_corpus_unlocked <- function(corpus,
                                   call = rlang::caller_env()) {
  if (isTRUE(corpus$metadata$is_locked)) {
    cli::cli_abort(
      c(
        "Corpus is locked and cannot be modified.",
        "i" = "Use {.fun sm_unlock} with {.arg confirm = TRUE} to unlock.",
        "i" = if (!is.na(corpus$metadata$lock_reason %||% NA_character_)) {
          paste0("Lock reason: ", corpus$metadata$lock_reason)
        }
      ),
      call = call, class = "scimapR_corpus_locked"
    )
  }
  invisible(corpus)
}

.lock_hash_mismatch <- function(corpus, hash = sm_hash_corpus(corpus)) {
  isTRUE(corpus$metadata$is_locked) &&
    !is.null(corpus$metadata$lock_hash) &&
    !identical(corpus$metadata$lock_hash, hash)
}

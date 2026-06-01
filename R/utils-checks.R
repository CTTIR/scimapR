# Internal validation helpers

.check_file_exists <- function(path, call = rlang::caller_env()) {
  if (!fs::file_exists(path)) {
    cli::cli_abort("File not found: {.path {path}}", call = call)
  }
  invisible(path)
}

.check_flag <- function(x, arg = rlang::caller_arg(x),
                        call = rlang::caller_env()) {
  if (!rlang::is_bool(x)) {
    cli::cli_abort("{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
                   call = call)
  }
  invisible(x)
}

.check_sm_corpus <- function(x, arg = rlang::caller_arg(x),
                             call = rlang::caller_env()) {
  if (!is_sm_corpus(x)) {
    cli::cli_abort("{.arg {arg}} must be an {.cls sm_corpus} object.",
                   call = call)
  }
  invisible(x)
}

.check_string <- function(x, allow_null = FALSE, allow_empty = FALSE,
                          arg = rlang::caller_arg(x),
                          call = rlang::caller_env()) {
  if (is.null(x) && allow_null) return(invisible(x))
  if (!rlang::is_string(x)) {
    cli::cli_abort("{.arg {arg}} must be a single string.", call = call)
  }
  if (!allow_empty && !nzchar(x)) {
    cli::cli_abort("{.arg {arg}} must be a non-empty string.", call = call)
  }
  invisible(x)
}

.check_positive_int <- function(x, arg = rlang::caller_arg(x),
                                call = rlang::caller_env()) {
  if (!rlang::is_integerish(x, n = 1) || x < 1L) {
    cli::cli_abort("{.arg {arg}} must be a positive integer.", call = call)
  }
  invisible(as.integer(x))
}

.check_installed_soft <- function(pkg, reason = NULL,
                                  call = rlang::caller_env()) {
  rlang::check_installed(pkg, reason = reason, call = call)
}

#' Type-safe row-bind that never coerces NULL/0-row elements to logical
#'
#' `dplyr::bind_rows()` on a list containing `NULL` or a 0-row tibble whose
#' columns default to `logical` can silently corrupt column types. This helper
#' drops `NULL`/empty elements first and, if nothing remains, returns the typed
#' `template` (the package's 0-row-with-correct-columns convention) instead of a
#' degenerate logical-column tibble.
#'
#' @param parts A list of tibbles/data frames (may contain `NULL`).
#' @param template A typed 0-row tibble returned when no non-empty parts remain.
#' @noRd
.sm_bind_rows <- function(parts, template = NULL) {
  if (!is.list(parts)) parts <- list(parts)
  keep <- vapply(parts, function(x) {
    !is.null(x) && (is.data.frame(x)) && nrow(x) > 0L
  }, logical(1))
  parts <- parts[keep]
  if (length(parts) == 0L) {
    if (!is.null(template)) return(template)
    return(tibble::tibble())
  }
  dplyr::bind_rows(parts)
}

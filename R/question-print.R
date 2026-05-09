#' @rdname sm_question
#' @param x An `sm_question` object.
#' @param ... Ignored.
#' @return
#'   - `print()`: `x` invisibly.
#'   - `format()`: A single character string.
#' @export
print.sm_question <- function(x, ...) {
  cli::cli_h1("<sm_question>")

  # Two-column layout: field label + value
  cli::cli_text("{.strong ID:} {x$id}")
  cli::cli_text("{.strong Framework:} {x$framework}")
  cli::cli_text("{.strong Created:} {format(x$created, '%Y-%m-%d %H:%M:%S')}")
  cli::cli_text("")
  cli::cli_text("{.strong Question:}")
  cli::cli_text("  {x$text}")
  cli::cli_text("")

  # Structured fields
  fields <- list(
    "Population" = x$population,
    "Intervention" = x$intervention,
    "Comparison" = x$comparison,
    "Outcome" = x$outcome,
    "Exposure" = x$exposure,
    "Design" = x$design,
    "Timeframe" = x$timeframe
  )

  has_fields <- !vapply(fields, is.null, logical(1))
  if (any(has_fields)) {
    cli::cli_h3("Structured fields")
    for (nm in names(fields)[has_fields]) {
      cli::cli_text("  {.strong {nm}:} {fields[[nm]]}")
    }
    cli::cli_text("")
  }

  # Terms
  if (!is.null(x$include_terms) && length(x$include_terms) > 0L) {
    cli::cli_text("{.strong Include terms:} {paste(x$include_terms, collapse = ', ')}")
  }
  if (!is.null(x$exclude_terms) && length(x$exclude_terms) > 0L) {
    cli::cli_text("{.strong Exclude terms:} {paste(x$exclude_terms, collapse = ', ')}")
  }

  # Languages
  cli::cli_text("{.strong Languages:} {paste(x$languages, collapse = ', ')}")

  # Notes
  if (!is.null(x$notes) && nzchar(x$notes)) {
    cli::cli_text("{.strong Notes:} {x$notes}")
  }

  # Query strings
  cli::cli_h3("Query strings")
  for (db in names(x$query_strings)) {
    q <- x$query_strings[[db]]
    q_short <- if (nchar(q) > 80L) paste0(substr(q, 1, 77), "...") else q
    cli::cli_text("  {.strong {db}:} {q_short}")
  }

  invisible(x)
}

#' @rdname sm_question
#' @param x An `sm_question` object.
#' @param ... Ignored.
#' @export
format.sm_question <- function(x, ...) {
  paste0("<sm_question> [", x$framework, "] ", substr(x$text, 1, 60),
         if (nchar(x$text) > 60) "..." else "")
}

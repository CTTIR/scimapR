# Part F2: validating constructor from a relational set of data frames.

#' Built-in empty schema templates for the sm_corpus sub-tables
#' @noRd
.sm_schema_templates <- function() {
  list(
    works = .empty_works(),
    authors = .empty_authors(),
    authorships = .empty_authorships(),
    institutions = .empty_institutions(),
    sources = .empty_sources(),
    references = .empty_references(),
    concepts = .empty_concepts(),
    provenance = .empty_provenance(),
    screening = .empty_screening()
  )
}

#' Typed NA of the same class as a template column
#' @noRd
.na_like <- function(template_col, n) {
  if (is.list(template_col)) return(rep(list(character()), n))
  if (inherits(template_col, "Date")) return(rep(as.Date(NA), n))
  if (inherits(template_col, "POSIXct")) return(rep(as.POSIXct(NA), n))
  switch(class(template_col)[1],
    integer = rep(NA_integer_, n),
    numeric = rep(NA_real_, n),
    double = rep(NA_real_, n),
    logical = rep(NA, n),
    rep(NA_character_, n)
  )
}

#' Coerce a column to the class of a template column
#' @noRd
.coerce_like <- function(x, template_col) {
  if (is.list(template_col)) {
    if (is.list(x)) return(x)
    return(as.list(x))
  }
  if (inherits(template_col, "Date")) {
    return(tryCatch(as.Date(x), error = function(e) rep(as.Date(NA), length(x))))
  }
  if (inherits(template_col, "POSIXct")) {
    return(tryCatch(as.POSIXct(x),
                    error = function(e) rep(as.POSIXct(NA), length(x))))
  }
  switch(class(template_col)[1],
    integer = suppressWarnings(as.integer(x)),
    numeric = suppressWarnings(as.numeric(x)),
    double = suppressWarnings(as.numeric(x)),
    logical = as.logical(x),
    as.character(x)
  )
}

#' Coerce one table to its schema template
#' @noRd
.coerce_table <- function(df, template, table_name, .coerce,
                          call = rlang::caller_env()) {
  df <- tibble::as_tibble(df)
  n <- nrow(df)
  coerced <- character()
  filled <- character()

  for (col in names(template)) {
    if (col %in% names(df)) {
      if (.coerce) {
        target_cls <- class(template[[col]])[1]
        if (class(df[[col]])[1] != target_cls && !is.list(template[[col]])) {
          df[[col]] <- .coerce_like(df[[col]], template[[col]])
          coerced <- c(coerced, col)
        } else if (is.list(template[[col]]) && !is.list(df[[col]])) {
          df[[col]] <- .coerce_like(df[[col]], template[[col]])
          coerced <- c(coerced, col)
        }
      }
    } else {
      df[[col]] <- .na_like(template[[col]], n)
      filled <- c(filled, col)
    }
  }

  if (length(coerced) > 0L) {
    cli::cli_inform(c("i" = "{.field {table_name}}: coerced column{?s} {.field {coerced}} to the schema type."))
  }
  if (length(filled) > 0L) {
    cli::cli_inform(c("i" = "{.field {table_name}}: filled missing column{?s} {.field {filled}} with typed {.code NA}."))
  }

  # order template columns first, then any extras the user supplied
  extra <- setdiff(names(df), names(template))
  df[, c(names(template), extra), drop = FALSE]
}

#' Construct an sm_corpus from a relational set of tables
#'
#' @description
#' A documented, validating constructor that builds an `sm_corpus` from a named
#' list of data frames -- making non-OpenAlex/WoS tabular sources first-class
#' and side-stepping format-specific parsers. Required columns are validated
#' against the `sm_corpus` schema, column types are coerced (with informative
#' messages), absent optional tables are filled with correctly-typed 0-row
#' tibbles, and the result is validated before being returned.
#'
#' This is the recommended ingestion path for arbitrary tabular sources.
#'
#' @param tables A named list of data frames. Recognised names are `works`,
#'   `authors`, `authorships`, `institutions`, `sources`, `references`,
#'   `concepts`, `provenance`, `screening`. `works` is required (and must have,
#'   or be coercible to, a `work_id` column; if absent, work ids are generated).
#' @param schema Optional named list of empty template tibbles overriding the
#'   built-in schema (advanced use). Defaults to the standard `sm_corpus`
#'   schema.
#' @param .coerce Logical (default `TRUE`); coerce supplied columns to the
#'   schema's types. When `FALSE`, columns are used as-is (missing columns are
#'   still filled with typed `NA`).
#' @param metadata Optional list of corpus-level metadata.
#' @param call Caller environment for error reporting.
#'
#' @return A validated `sm_corpus` object.
#'
#' @family reporting
#' @family corpus
#' @seealso [sm_corpus()], [as_sm_corpus()]
#' @export
#' @examples
#' works <- data.frame(
#'   work_id = c("W1", "W2"),
#'   title = c("First", "Second"),
#'   year = c("2020", "2021"),   # character -> coerced to integer
#'   doi = c("10.1/a", "10.1/b")
#' )
#' authorships <- data.frame(
#'   work_id = c("W1", "W1", "W2"),
#'   author_id = c("A1", "A2", "A1"),
#'   position = c(1, 2, 1)
#' )
#' corpus <- sm_corpus_from_tables(list(works = works,
#'                                      authorships = authorships))
#' corpus
sm_corpus_from_tables <- function(tables,
                                  schema = NULL,
                                  .coerce = TRUE,
                                  metadata = list(),
                                  call = rlang::caller_env()) {
  if (!is.list(tables) || is.null(names(tables))) {
    cli::cli_abort("{.arg tables} must be a named list of data frames.",
                   call = call)
  }
  .check_flag(.coerce, call = call)

  templates <- schema %||% .sm_schema_templates()

  known <- names(templates)
  unknown <- setdiff(names(tables), known)
  if (length(unknown) > 0L) {
    cli::cli_warn(c(
      "!" = "Ignoring unrecognised table{?s}: {.field {unknown}}.",
      "i" = "Recognised tables: {.field {known}}."
    ))
  }

  if (!"works" %in% names(tables)) {
    cli::cli_abort(c(
      "{.arg tables} must include a {.field works} table.",
      "i" = "Recognised tables: {.field {known}}."
    ), call = call)
  }

  # coerce each provided table; fall back to the empty template otherwise
  built <- list()
  for (tn in known) {
    if (tn %in% names(tables) && !is.null(tables[[tn]])) {
      built[[tn]] <- .coerce_table(tables[[tn]], templates[[tn]], tn,
                                   .coerce, call = call)
    } else {
      built[[tn]] <- templates[[tn]]
    }
  }

  # ensure works has a work_id
  if (!"work_id" %in% names(built$works) ||
      all(is.na(built$works$work_id))) {
    built$works$work_id <- .generate_work_id(nrow(built$works))
    cli::cli_inform(c("i" = "Generated {.field work_id}s for the {.field works} table."))
  }

  corpus <- new_sm_corpus(
    works = built$works,
    authors = built$authors,
    authorships = built$authorships,
    institutions = built$institutions,
    sources = built$sources,
    references = built$references,
    concepts = built$concepts,
    provenance = built$provenance,
    screening = built$screening,
    metadata = metadata
  )

  validate_sm_corpus(corpus, call = call)
  corpus
}

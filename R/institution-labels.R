# Institution labels of authorship rows, shared by the affiliation breakdowns
# of sm_coverage_audit() and by sm_count(level = "institution").

#' Institution label columns of an authorships table, in precedence order
#'
#' `institution_match` (from [sm_affiliation_match()]) comes first, then
#' `institution_name` and `institution_id` (from [sm_attribute_institution()],
#' readers and ROR enrichment), and last `country_code` when
#' `country_fallback` is `TRUE`.
#' @noRd
.institution_label_columns <- function(country_fallback = TRUE) {
  cols <- c("institution_match", "institution_name", "institution_id")
  if (isTRUE(country_fallback)) c(cols, "country_code") else cols
}

#' Labels from one column of an authorships table
#'
#' One label per authorship row; blank values count as missing, and a column
#' the table lacks gives `NA` for every row. `institution_id` values are named
#' by the `display_name` of `institutions_tbl` when the table lists the id
#' with a name, and stay the raw id otherwise.
#' @noRd
.institution_column_labels <- function(authorships, institutions_tbl, column) {
  n <- nrow(authorships)
  if (!column %in% names(authorships)) {
    return(rep(NA_character_, n))
  }
  x <- as.character(authorships[[column]])
  x[!is.na(x) & !nzchar(trimws(x))] <- NA_character_
  named <- identical(column, "institution_id") &&
    is.data.frame(institutions_tbl) &&
    all(c("institution_id", "display_name") %in% names(institutions_tbl))
  if (named) {
    nm <- as.character(institutions_tbl$display_name)[
      match(x, as.character(institutions_tbl$institution_id))
    ]
    named <- !is.na(nm) & nzchar(trimws(nm))
    x[named] <- nm[named]
  }
  x
}

#' Resolve one institution label per authorship row
#'
#' Takes the first column of `.institution_label_columns()` that is usable,
#' that is present with at least one non-missing value, and labels every row
#' from it, so that all labels are of one kind; rows without a value in that
#' column get `NA`. Never messages: callers say which column was used.
#'
#' @param authorships An `authorships` table.
#' @param institutions_tbl The corpus `institutions` table (or `NULL`), used to
#'   name `institution_id` values.
#' @param country_fallback Whether `country_code` may serve as the last
#'   resort.
#' @return A list with `label` (a character vector, one per row) and `column`
#'   (the column used, or `NA_character_` when none is usable).
#' @noRd
.resolve_institution_labels <- function(authorships, institutions_tbl = NULL,
                                        country_fallback = TRUE) {
  for (col in .institution_label_columns(country_fallback)) {
    label <- .institution_column_labels(authorships, institutions_tbl, col)
    if (any(!is.na(label))) {
      return(list(label = label, column = col))
    }
  }
  list(label = rep(NA_character_, nrow(authorships)), column = NA_character_)
}

#' Resolve institution labels row by row
#'
#' Unlike `.resolve_institution_labels()`, each row takes the first of
#' `columns` that has a value in that row, so one table can mix kinds of
#' label. Used by `sm_count(level = "institution")`.
#' @return A list with `label` and `column` (the column each row's label came
#'   from, `NA` where no column has a value), both one per row.
#' @noRd
.institution_labels_by_row <- function(authorships, institutions_tbl,
                                       columns) {
  n <- nrow(authorships)
  label <- rep(NA_character_, n)
  column <- rep(NA_character_, n)
  for (col in columns) {
    todo <- is.na(label)
    if (!any(todo)) break
    x <- .institution_column_labels(authorships, institutions_tbl, col)
    use <- todo & !is.na(x)
    label[use] <- x[use]
    column[use] <- col
  }
  list(label = label, column = column)
}

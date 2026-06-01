#' Verify journal source coverage against an index by ISSN
#'
#' @description
#' Checks whether each supplied ISSN appears in a journal master list (e.g. the
#' Web of Science Master Journal List, a Scopus source list, or a DOAJ export).
#' Matching is by normalised ISSN and checks both print and electronic ISSNs.
#'
#' This function is deliberately offline and data-driven: it never scrapes or
#' hardcodes proprietary lists. You supply the master list via `reference_list`,
#' so the function is fully testable and reproducible.
#'
#' @param issn Character vector of ISSNs to check. Hyphenation and case are
#'   normalised automatically (e.g. `"15452786"` and `"1545-2786"` are
#'   equivalent; a lowercase `x` check digit is upper-cased).
#' @param index Which index the master list represents: `"wos"` (default),
#'   `"scopus"`, or `"doaj"`. This is a label echoed in the output; the actual
#'   matching is performed entirely against `reference_list`.
#' @param reference_list A data frame master list. Expected columns (matched
#'   case-insensitively):
#'   \describe{
#'     \item{title}{Journal title (aliases: `title`, `journal`,
#'       `journal_title`, `source_title`, `display_name`).}
#'     \item{ISSN columns}{One or more of `issn`, `issn_print`, `print_issn`,
#'       `issn_electronic`, `issn_online`, `eissn`, `issn_l`. Columns whose
#'       name indicates "electronic"/"online"/"eissn" are reported as
#'       `"electronic"`; print columns as `"print"`; a bare `issn`/`issn_l`
#'       column as `"unknown"`.}
#'   }
#'   A small synthetic example list ships at
#'   `system.file("extdata", "example_journal_index.csv", package = "scimapR")`.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row per input `issn` and columns:
#'   `issn` (the normalised input), `index`, `in_index` (logical),
#'   `matched_title` (character or `NA`), `matched_issn_type`
#'   (`"print"`/`"electronic"`/`"unknown"`/`NA`). Type-stable: an empty `issn`
#'   vector returns a 0-row tibble with these columns.
#'
#' @family coverage
#' @seealso [sm_coverage_audit()]
#' @export
#' @examples
#' ref <- utils::read.csv(
#'   system.file("extdata", "example_journal_index.csv", package = "scimapR"),
#'   stringsAsFactors = FALSE
#' )
#' sm_journal_in_index(c("1078-8956", "1546-170X", "9999-9999"),
#'                     index = "doaj", reference_list = ref)
sm_journal_in_index <- function(issn,
                                index = c("wos", "scopus", "doaj"),
                                reference_list = NULL,
                                call = rlang::caller_env()) {
  index <- rlang::arg_match(index, error_call = call)

  empty <- tibble::tibble(
    issn = character(), index = character(), in_index = logical(),
    matched_title = character(), matched_issn_type = character()
  )

  if (length(issn) == 0L) return(empty)
  if (!is.character(issn)) issn <- as.character(issn)

  if (is.null(reference_list)) {
    cli::cli_abort(c(
      "{.arg reference_list} is required.",
      "i" = "Supply a journal master list (e.g. a WoS/Scopus/DOAJ export).",
      "i" = "scimapR does not ship proprietary lists; a synthetic example is at {.code system.file(\"extdata\", \"example_journal_index.csv\", package = \"scimapR\")}."
    ), call = call)
  }
  if (!is.data.frame(reference_list)) {
    cli::cli_abort("{.arg reference_list} must be a data frame.", call = call)
  }

  norm_in <- .normalize_issn(issn)
  lookup <- .build_issn_lookup(reference_list, call = call)

  hit_idx <- match(norm_in, lookup$issn)
  in_index <- !is.na(hit_idx)

  tibble::tibble(
    issn = norm_in,
    index = index,
    in_index = in_index,
    matched_title = ifelse(in_index, lookup$title[hit_idx], NA_character_),
    matched_issn_type = ifelse(in_index, lookup$type[hit_idx], NA_character_)
  )
}

#' Normalise an ISSN to `NNNN-NNNX` form
#'
#' Strips non-alphanumerics, upper-cases the X check digit, inserts the hyphen,
#' and returns `NA_character_` for anything that is not a valid 8-character
#' ISSN. Vectorised.
#' @noRd
.normalize_issn <- function(x) {
  x <- toupper(gsub("[^0-9Xx]", "", as.character(x)))
  out <- ifelse(nchar(x) == 8L,
                paste0(substr(x, 1, 4), "-", substr(x, 5, 8)),
                NA_character_)
  valid <- grepl("^[0-9]{4}-[0-9]{3}[0-9X]$", out)
  ifelse(valid, out, NA_character_)
}

#' Build a normalised ISSN -> (title, type) lookup from a master list
#' @noRd
.build_issn_lookup <- function(reference_list, call = rlang::caller_env()) {
  nms <- names(reference_list)
  low <- tolower(nms)

  title_aliases <- c("title", "journal", "journal_title", "source_title",
                     "display_name", "publication_title")
  title_col <- nms[which(low %in% title_aliases)][1]
  titles <- if (!is.na(title_col)) {
    as.character(reference_list[[title_col]])
  } else {
    rep(NA_character_, nrow(reference_list))
  }

  issn_cols <- nms[grepl("issn|eissn", low)]
  if (length(issn_cols) == 0L) {
    cli::cli_abort(c(
      "No ISSN column found in {.arg reference_list}.",
      "i" = "Expected one of {.field issn}, {.field issn_print}, {.field issn_electronic}, {.field eissn}, {.field issn_l}."
    ), call = call)
  }

  issn_acc <- character()
  title_acc <- character()
  type_acc <- character()

  for (col in issn_cols) {
    lc <- tolower(col)
    type <- if (grepl("electronic|online|eissn|e_issn|e-issn", lc)) {
      "electronic"
    } else if (grepl("print|p_issn|p-issn", lc)) {
      "print"
    } else {
      "unknown"
    }
    vals <- .normalize_issn(reference_list[[col]])
    keep <- !is.na(vals)
    issn_acc <- c(issn_acc, vals[keep])
    title_acc <- c(title_acc, titles[keep])
    type_acc <- c(type_acc, rep(type, sum(keep)))
  }

  # de-duplicate, keeping the first occurrence per normalised ISSN
  keep <- !duplicated(issn_acc)
  list(issn = issn_acc[keep], title = title_acc[keep], type = type_acc[keep])
}

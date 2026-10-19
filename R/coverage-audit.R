#' Audit corpus coverage against a ground-truth reference
#'
#' @description
#' Computes recall, precision, and F1 of an `sm_corpus` against an external
#' ground-truth `reference` (a manual tracker, an ORCID works set, an
#' institutional-repository export, or another `sm_corpus`). This is the core
#' primitive for a coverage / completeness audit: "how much of what we *should*
#' have did we actually capture, and how much of what we captured is real?"
#'
#' Matching is by normalised DOI with a fuzzy-title fallback (see
#' [sm_reconcile()] for the shared matching engine). Full match provenance is
#' retained so every decision can be inspected.
#'
#' @param corpus An `sm_corpus` object (the corpus under audit).
#' @param reference The ground truth: an `sm_corpus` or a data frame with at
#'   least a DOI and/or title column (column names matched case-insensitively
#'   against `doi`/`di` and `title`/`ti`/`display_name`, the year against
#'   `year`/`py`/`publication_year`). A `Date` or date-time year column gives
#'   its calendar year, and a year outside 1000-2999 (such as a day count)
#'   counts as missing. Rows are identified by the first of the
#'   columns `ut` (Web of Science accession numbers), `id`, `work_id`,
#'   `reference_id` and `ref_id` whose values are unique and never missing,
#'   and otherwise by their position (`R000001`, ...), with a warning when
#'   such a column had to be passed over. In a data frame with Web of Science
#'   field tags (such as `DI`, `TI`, `PY` or `UT`) a column named `ID` holds
#'   the Keywords Plus and is never the identifier.
#' @param by Optional character vector of breakdown dimensions. A name is
#'   either one of the named dimensions `"year"`, `"source"` and
#'   `"affiliation"`, written in lower case (see Details), or a column: of
#'   the reference data frame
#'   (matched case-insensitively) or of the `works` table of an `sm_corpus`
#'   (the exact name first, then case-insensitively). Each name is resolved
#'   on both sides; a name found on one side only gives levels whose columns
#'   for the other side are `NA`. A name that is neither a named dimension
#'   nor a column on either side is an error listing the available columns.
#'   The breakdowns label each dimension with the name as given.
#' @param match Matching strategy: `"doi_then_title"` (default), `"doi"`, or
#'   `"title"`.
#' @param threshold Minimum Jaro-Winkler title similarity (`[0, 1]`) to accept
#'   a title match. Default `0.9`. When the optional `stringdist` package is
#'   not installed, the title fallback degrades to normalised exact matching.
#'   Titles only match between records published at most one year apart (when
#'   both years are known) and never between two records with different DOIs.
#' @param index_table Optional journal index master list (same contract as
#'   [sm_journal_in_index()]; document expected columns there). When supplied,
#'   the audit additionally reports, per corpus record, whether its journal is
#'   **indexable** -- so "is this journal in the index" and "is this record
#'   captured" are assessed together. When `NULL` (default) the result is
#'   identical to before.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_coverage` S3 object (a list) with components:
#'   \describe{
#'     \item{recall}{Reference records found in the corpus / total reference
#'       records. Each reference row is looked up on its own, so rows that
#'       report the same item (one paper reported by two units) are all
#'       found.}
#'     \item{precision}{Matched corpus records / total corpus records. Each
#'       corpus record pairs with at most one reference row.}
#'     \item{f1}{Harmonic mean of recall and precision.}
#'     \item{n_corpus, n_reference}{Integer record counts.}
#'     \item{n_matched}{Reference records found in the corpus (the numerator
#'       of recall).}
#'     \item{n_corpus_matched}{Corpus records paired with a reference record
#'       (the numerator of precision); equal to `n_matched` unless reference
#'       rows share a corpus record.}
#'     \item{n_corpus_only, n_reference_only}{Unmatched counts.}
#'     \item{matches}{Tibble with one row per corpus record: `corpus_id`,
#'       `reference_id`, `match_type` (`"doi"`/`"title"`/`"none"`),
#'       `match_score`. When `index_table` is supplied, also `issn`,
#'       `indexable` (logical), and `indexed_title`.}
#'     \item{reference_matches}{Tibble with one row per reference record:
#'       `reference_id`, `corpus_id` (the corpus record it was found in),
#'       `match_type` and `match_score`; the recall-side counterpart of
#'       `matches`.}
#'     \item{corpus_only}{Tibble of corpus records absent from the reference.}
#'     \item{reference_only}{Tibble of reference records absent from the
#'       corpus.}
#'     \item{breakdowns}{A single flat tibble (`dimension`, `level`,
#'       `n_reference`, `n_matched`, `recall`) across all `by` dimensions,
#'       from the reference side. Use [sm_coverage_breakdowns()] to
#'       access/filter it, also with the corpus-side counts and precision.}
#'     \item{breakdowns_nested}{The legacy named list of per-dimension tibbles
#'       (`slice`, `n_reference`, `n_matched`, `recall`). Retained for one
#'       release; prefer `breakdowns`.}
#'     \item{indexability}{When `index_table` is supplied, a summary tibble of
#'       indexable vs non-indexable record counts; otherwise `NULL`.}
#'   }
#'
#' @details
#' **Named dimensions.** `"year"` uses the publication years. `"source"` uses
#' the source names of an `sm_corpus` (`sources$display_name`, or
#' `works$source_id` when the corpus has no source table) and, in a data
#' frame, the first of the columns `source`, `source_title`, `journal`, `so`
#' and `source_id`, in this order (names matched case-insensitively); a
#' `source_id` column holds ids, whose levels do not join the names of the
#' corpus side. `"affiliation"` uses, in a data frame, the first of the
#' columns `affiliation`, `affiliations`, `institution`, `country` and
#' `country_code`, in this order. A data-frame cell holds one value, so an
#' item reported by two units takes two rows; a list column gives each of
#' its values. Missing and blank values have no level. A named dimension
#' that neither side can resolve gives a warning and no breakdown rows.
#' Only `"affiliation"` joins a tracker's units with the institutions of the
#' corpus: `by = "institution"` names the column itself, which the corpus
#' side has only if `works` has a column of that name.
#'
#' **Affiliation levels of a corpus.** For an `sm_corpus` (the corpus under
#' audit, or a reference given as one), `"affiliation"` labels the
#' authorships from the first of these `authorships` columns that has a
#' value in at least one row: `institution_match` (from
#' [sm_affiliation_match()]), `institution_name` (from
#' [sm_attribute_institution()]), `institution_id` (named by
#' `corpus$institutions$display_name` when that table lists the id, else
#' the id itself) and, as a last resort, `country_code`. One column serves
#' every row, so the levels of a side are all of one kind, and an authorship
#' without a value in that column has no level. A message names the column
#' used on each side, and a warning says when a side falls back to country
#' codes, whose levels do not join institution names. Because
#' [sm_attribute_institution()] runs [sm_affiliation_match()] first,
#' `institution_name` is used only when `institution_match` is absent or
#' empty; the Details of [sm_attribute_institution()] show how to break the
#' coverage down by its vocabulary instead.
#' `sm_count(level = "institution")` reads the same columns in the
#' same order, but row by row, and counts the raw affiliation string where
#' none has a value instead of falling back to countries; up to scimapR
#' 0.4.0 it used, for every row, the first of `institution_id`,
#' `institution_match` and the raw strings (matched with
#' [sm_affiliation_dict]) that had a value in any row.
#'
#' **Full counting.** A record belongs to every level of its values, so a
#' work with authors at two institutions counts in both slices, and the
#' per-level counts of a dimension can add up to more than `n_corpus` or
#' `n_reference`. The overall recall and precision count each record once.
#'
#' @family coverage
#' @seealso [sm_reconcile()], [sm_journal_in_index()],
#'   [sm_coverage_breakdowns()], [sm_affiliation_match()]
#' @export
#' @examplesIf rlang::is_installed("stringdist")
#' corpus <- sm_example_corpus(n_works = 30, seed = 1)
#' # Pretend the reference is the corpus minus a few works, plus an extra one
#' ref <- corpus$works[1:25, c("work_id", "doi", "title", "year")]
#' cov <- sm_coverage_audit(corpus, ref, by = "year")
#' cov
#'
#' # Any column of the reference or of the works is a dimension too
#' ref$unit <- rep(c("Unit A", "Unit B"), length.out = nrow(ref))
#' cov <- sm_coverage_audit(corpus, ref, by = c("unit", "type"), match = "doi")
#' sm_coverage_breakdowns(cov)
sm_coverage_audit <- function(corpus,
                              reference,
                              by = NULL,
                              match = c("doi_then_title", "doi", "title"),
                              threshold = 0.9,
                              index_table = NULL,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  match <- rlang::arg_match(match, error_call = call)
  by <- .coverage_check_by(by, call = call)

  corpus_frame <- .as_match_frame(corpus, what = "corpus", call = call)
  ref_frame <- .as_match_frame(reference, what = "reference", call = call)

  # dimension levels, resolved once per side and shared by all breakdowns
  dims <- .coverage_dims(by, corpus, corpus_frame, reference, ref_frame,
                         call = call)

  # precision pairs each corpus record with at most one reference row;
  # recall looks each reference row up on its own, so an item reported in
  # several rows (two units, one paper) is found for each of them
  pairs <- .sm_match_records(corpus_frame, ref_frame, match = match,
                             threshold = threshold)
  found <- .sm_match_each(ref_frame, corpus_frame, match = match,
                          threshold = threshold)

  n_corpus <- nrow(corpus_frame)
  n_reference <- nrow(ref_frame)
  corpus_matched <- seq_len(n_corpus) %in% pairs$a_row
  ref_matched <- found$matched
  n_matched <- sum(ref_matched)
  n_corpus_matched <- sum(corpus_matched)

  recall <- if (n_reference > 0L) n_matched / n_reference else NA_real_
  precision <- if (n_corpus > 0L) n_corpus_matched / n_corpus else NA_real_
  f1 <- if (!is.na(recall) && !is.na(precision) && (recall + precision) > 0) {
    2 * recall * precision / (recall + precision)
  } else {
    NA_real_
  }

  # provenance: one row per corpus record
  partner <- rep(NA_integer_, n_corpus)
  partner[pairs$a_row] <- pairs$b_row
  match_type <- rep("none", n_corpus)
  match_type[pairs$a_row] <- pairs$match_type
  match_score <- rep(NA_real_, n_corpus)
  match_score[pairs$a_row] <- pairs$match_score
  matches <- tibble::tibble(
    corpus_id = corpus_frame$id,
    reference_id = ref_frame$id[partner],
    # B1: controlled vocabulary as a factor with stable levels
    match_type = factor(match_type, levels = .match_type_levels()),
    match_score = match_score
  )

  reference_matches <- tibble::tibble(
    reference_id = ref_frame$id,
    corpus_id = corpus_frame$id[found$y_row],
    match_type = factor(found$match_type, levels = .match_type_levels()),
    match_score = found$match_score
  )

  corpus_only <- corpus_frame[!corpus_matched, ]
  reference_only <- ref_frame[!ref_matched, ]

  # ---- breakdowns: nested list (legacy) + flat tibble (preferred) ----
  breakdowns_nested <- list()
  for (dim in by) {
    breakdowns_nested[[dim]] <- .coverage_breakdown(dims[[dim]]$reference,
                                                    ref_matched)
  }
  breakdowns <- .flatten_breakdowns(breakdowns_nested)
  # stable long contract (A1): adds per-slice corpus counts, precision, f1
  breakdowns_tidy <- .coverage_breakdowns_tidy(dims, ref_matched,
                                               corpus_matched)

  # ---- C1: journal indexability (only when an index table is supplied) ----
  indexability <- NULL
  if (!is.null(index_table)) {
    idx <- .coverage_indexability(corpus, index_table, call = call)
    matches <- dplyr::left_join(matches, idx$by_record, by = "corpus_id")
    indexability <- idx$summary
  }

  structure(
    list(
      recall = round(recall, 4),
      precision = round(precision, 4),
      f1 = round(f1, 4),
      n_corpus = n_corpus,
      n_reference = n_reference,
      n_matched = n_matched,
      n_corpus_matched = n_corpus_matched,
      n_corpus_only = n_corpus - n_corpus_matched,
      n_reference_only = n_reference - n_matched,
      match = match,
      threshold = threshold,
      matches = matches,
      reference_matches = reference_matches,
      corpus_only = corpus_only,
      reference_only = reference_only,
      breakdowns = breakdowns,
      breakdowns_nested = breakdowns_nested,
      breakdowns_tidy = breakdowns_tidy,
      indexability = indexability
    ),
    class = "sm_coverage"
  )
}

#' Tidy per-slice coverage breakdowns with recall, precision, and F1 (A1)
#'
#' Reference-side slices drive recall; corpus-side slices drive precision; the
#' two are joined on `(dimension, level)`. This is the stable long contract
#' returned by [sm_coverage_breakdowns()] with `tidy = TRUE`.
#'
#' @param dims Resolved dimensions from `.coverage_dims()`.
#' @param ref_matched,corpus_matched Logical vectors, one per reference and
#'   corpus match-frame row.
#' @noRd
.coverage_breakdowns_tidy <- function(dims, ref_matched, corpus_matched) {
  empty <- tibble::tibble(
    dimension = character(), level = character(),
    n_reference = integer(), n_matched = integer(), recall = double(),
    n_corpus = integer(), precision = double(), f1 = double()
  )
  if (length(dims) == 0L) return(empty)

  out <- list()
  for (dim in names(dims)) {
    ref_long <- dims[[dim]]$reference$long
    cor_long <- dims[[dim]]$corpus$long

    ref_counts <- .coverage_level_counts(ref_long, ref_matched)
    rec <- tibble::tibble(
      level = ref_counts$level,
      n_reference = ref_counts$n,
      n_matched = ref_counts$n_matched,
      recall = round(ref_counts$n_matched / ref_counts$n, 4)
    )
    cor_counts <- .coverage_level_counts(cor_long, corpus_matched)
    pre <- tibble::tibble(
      level = cor_counts$level,
      n_corpus = cor_counts$n,
      precision = round(cor_counts$n_matched / cor_counts$n, 4)
    )

    if (nrow(rec) == 0L && nrow(pre) == 0L) next
    merged <- dplyr::full_join(rec, pre, by = "level") %>%
      dplyr::mutate(
        dimension = dim,
        f1 = dplyr::if_else(
          !is.na(.data$recall) & !is.na(.data$precision) &
            (.data$recall + .data$precision) > 0,
          round(2 * .data$recall * .data$precision /
                  (.data$recall + .data$precision), 4),
          NA_real_)
      ) %>%
      dplyr::select("dimension", "level", "n_reference", "n_matched",
                    "recall", "n_corpus", "precision", "f1") %>%
      dplyr::arrange(.data$level)
    out[[dim]] <- merged
  }
  if (length(out) == 0L) return(empty)
  dplyr::bind_rows(out)
}

#' Flatten the per-dimension breakdown list into one tibble
#' @noRd
.flatten_breakdowns <- function(nested) {
  empty <- tibble::tibble(
    dimension = character(), level = character(),
    n_reference = integer(), n_matched = integer(), recall = double()
  )
  if (length(nested) == 0L) return(empty)
  flat <- lapply(names(nested), function(d) {
    bd <- nested[[d]]
    if (nrow(bd) == 0L) return(NULL)
    tibble::tibble(
      dimension = d,
      level = as.character(bd$slice),
      n_reference = bd$n_reference,
      n_matched = bd$n_matched,
      recall = bd$recall
    )
  })
  flat <- flat[!vapply(flat, is.null, logical(1))]
  if (length(flat) == 0L) return(empty)
  dplyr::bind_rows(flat)
}

#' Assess journal indexability of corpus records against an index table (C1)
#'
#' Reuses [sm_journal_in_index()] so ISSN normalisation is not duplicated.
#' @noRd
.coverage_indexability <- function(corpus, index_table,
                                   call = rlang::caller_env()) {
  works <- corpus$works
  sources <- corpus$sources

  # resolve each work's source ISSN
  issn_by_source <- if (nrow(sources) > 0L && "issn_l" %in% names(sources)) {
    stats::setNames(as.character(sources$issn_l), sources$source_id)
  } else {
    character()
  }
  src_id <- if ("source_id" %in% names(works)) as.character(works$source_id) else rep(NA_character_, nrow(works))
  work_issn <- unname(issn_by_source[src_id])

  checked <- sm_journal_in_index(work_issn, reference_list = index_table,
                                 call = call)

  by_record <- tibble::tibble(
    corpus_id = as.character(works$work_id),
    issn = checked$issn,
    indexable = checked$in_index,
    indexed_title = checked$matched_title
  )

  summary <- by_record %>%
    dplyr::group_by(.data$indexable) %>%
    dplyr::summarise(n_records = dplyr::n(), .groups = "drop")

  list(by_record = by_record, summary = summary)
}

#' Coverage breakdowns as a flat tibble
#'
#' @description
#' Accessor returning the per-dimension coverage breakdowns of an
#' [sm_coverage_audit()] result as a single flat (long) tibble, optionally
#' filtered to one dimension.
#'
#' @details
#' This accessor honours the package's accessor return-type stability contract
#' (see [scimapR-stability]): with `tidy = TRUE` the column set is guaranteed
#' and will only change via a `lifecycle` deprecation.
#'
#' The recall columns (`n_reference`, `n_matched`, `recall`) come from the
#' reference side and the precision columns (`n_corpus`, `precision`) from
#' the corpus side, joined on `(dimension, level)`. A level found on the
#' reference side only has `n_corpus`, `precision` and `f1` `NA`; a level
#' found on the corpus side only has `n_reference`, `n_matched`, `recall` and
#' `f1` `NA`. Under full counting (see the Details of [sm_coverage_audit()])
#' the per-level counts of a dimension can add up to more than the record
#' totals. `tidy = FALSE`, `print()` and `autoplot()` show the same
#' reference-side counts.
#'
#' @param x An `sm_coverage` object.
#' @param dimension Optional dimension name (e.g. `"year"`) to filter to.
#' @param tidy Logical (default `TRUE`). The stable long contract: returns
#'   columns `dimension`, `level`, `n_reference`, `n_matched`, `recall`,
#'   `n_corpus`, `precision`, `f1`. With `tidy = FALSE`, the legacy recall-only
#'   shape (`dimension`, `level`, `n_reference`, `n_matched`, `recall`) is
#'   returned for backward compatibility.
#'
#' @return A tibble (see `tidy`). Type-stable: a 0-row tibble with the
#'   documented columns when there are no breakdowns. Slices present on only one
#'   side (corpus vs reference) carry `NA` in the other side's counts/metric.
#'
#' @family coverage
#' @seealso [sm_coverage_audit()], [scimapR-stability]
#' @export
#' @examplesIf rlang::is_installed("stringdist")
#' corpus <- sm_example_corpus(n_works = 30, seed = 1)
#' ref <- corpus$works[1:25, c("work_id", "doi", "title", "year")]
#' cov <- sm_coverage_audit(corpus, ref, by = "year")
#' sm_coverage_breakdowns(cov, dimension = "year")
sm_coverage_breakdowns <- function(x, dimension = NULL, tidy = TRUE) {
  if (!inherits(x, "sm_coverage")) {
    cli::cli_abort("{.arg x} must be an {.cls sm_coverage} object.")
  }
  .check_flag(tidy)

  if (tidy) {
    bd <- x$breakdowns_tidy
    if (is.null(bd)) {
      # older sm_coverage objects: derive the stable shape from the recall-only
      # flat tibble, with precision/f1 unavailable (NA).
      legacy <- x$breakdowns %||% tibble::tibble(
        dimension = character(), level = character(),
        n_reference = integer(), n_matched = integer(), recall = double())
      bd <- tibble::tibble(
        dimension = legacy$dimension, level = legacy$level,
        n_reference = legacy$n_reference, n_matched = legacy$n_matched,
        recall = legacy$recall, n_corpus = NA_integer_,
        precision = NA_real_, f1 = NA_real_)
    }
  } else {
    bd <- x$breakdowns %||% tibble::tibble(
      dimension = character(), level = character(),
      n_reference = integer(), n_matched = integer(), recall = double())
  }

  if (!is.null(dimension)) {
    bd <- dplyr::filter(bd, .data$dimension %in% .env$dimension)
  }
  bd
}

#' Per-dimension recall breakdown for a coverage audit (legacy shape)
#'
#' @param side The reference side of a resolved dimension (see
#'   `.coverage_dims()`), or `NULL` when the reference cannot resolve it.
#' @param matched Logical vector, one per reference match-frame row.
#' @noRd
.coverage_breakdown <- function(side, matched) {
  empty <- tibble::tibble(
    slice = character(), n_reference = integer(),
    n_matched = integer(), recall = double()
  )
  counts <- .coverage_level_counts(side$long, matched)
  if (nrow(counts) == 0L) return(empty)
  out <- tibble::tibble(
    slice = counts$level,
    n_reference = counts$n,
    n_matched = counts$n_matched,
    recall = round(counts$n_matched / counts$n, 4)
  )
  dplyr::arrange(out, .data$slice)
}

#' Records and matched records per level of a long (row, level) table
#'
#' @param long A long table from `.coverage_levels()`, or `NULL`.
#' @param matched Logical vector, one per match-frame row of that side.
#' @return A tibble with `level`, `n` (records) and `n_matched`.
#' @noRd
.coverage_level_counts <- function(long, matched) {
  if (is.null(long) || nrow(long) == 0L) {
    return(tibble::tibble(level = character(), n = integer(),
                          n_matched = integer()))
  }
  long$matched <- matched[long$row]
  grouped <- dplyr::group_by(long, .data$level)
  dplyr::summarise(grouped, n = dplyr::n(), n_matched = sum(.data$matched),
                   .groups = "drop")
}

#' The named breakdown dimensions of a coverage audit
#' @noRd
.coverage_named_dims <- function() {
  c("year", "source", "affiliation")
}

#' Validate the `by` argument of sm_coverage_audit()
#' @noRd
.coverage_check_by <- function(by, call = rlang::caller_env()) {
  if (is.null(by)) return(character())
  if (!is.character(by) || anyNA(by) || any(!nzchar(trimws(by)))) {
    cli::cli_abort(
      "{.arg by} must be a character vector of dimension or column names,
       without missing or empty names.",
      call = call
    )
  }
  unique(by)
}

#' Resolve the breakdown dimensions of a coverage audit, once per side
#'
#' For each name in `by`, both sides (`reference`, `corpus`) get either `NULL`
#' (the side has no source for the dimension) or a list with `long`, a
#' tibble of distinct (`row`, `level`) pairs where `row` indexes the side's
#' match frame (several rows per record for multi-valued dimensions),
#' `column` (where the levels come from) and `kind` (`"institution"` or
#' `"country"` for affiliation, else `NA`). Aborts on names that resolve on
#' neither side and are no named dimension; warns for named dimensions that
#' resolve on neither side; informs (and warns on a country fallback) about
#' the affiliation dimension, once per call.
#' @noRd
.coverage_dims <- function(by, corpus, corpus_frame, reference, ref_frame,
                           call = rlang::caller_env()) {
  dims <- list()
  for (dim in by) {
    dims[[dim]] <- list(
      reference = .coverage_dim_long(reference, ref_frame, dim),
      corpus = .coverage_dim_long(corpus, corpus_frame, dim)
    )
  }
  unresolved <- vapply(dims, function(d) {
    is.null(d$reference) && is.null(d$corpus)
  }, logical(1))
  unknown <- by[unresolved & !by %in% .coverage_named_dims()]
  if (length(unknown) > 0L) {
    .coverage_abort_unknown(unknown, corpus, reference, call = call)
  }
  for (dim in by[unresolved]) {
    cli::cli_warn(c(
      "!" = "Could not resolve breakdown dimension {.val {dim}} from the
             reference or the corpus.",
      "i" = "Returning an empty breakdown for {.val {dim}}."
    ))
  }
  if ("affiliation" %in% by) {
    .coverage_affiliation_notes(dims[["affiliation"]], call = call)
  }
  dims
}

#' Levels of one breakdown dimension on one side of a coverage audit
#'
#' @param x The side's input: an `sm_corpus` or a data frame.
#' @param frame Its match frame (from `.as_match_frame()`), one row per
#'   record in input order.
#' @param dim The dimension name as passed in `by`.
#' @return `NULL` or a list with `long`, `column` and `kind` (see
#'   `.coverage_dims()`).
#' @noRd
.coverage_dim_long <- function(x, frame, dim) {
  rows <- seq_len(nrow(frame))
  if (identical(dim, "year")) {
    return(.coverage_levels(rows, frame$year, "year"))
  }

  if (is_sm_corpus(x)) {
    w <- x$works
    if (identical(dim, "source")) {
      if (!"source_id" %in% names(w)) return(NULL)
      src <- x$sources
      nm <- as.character(w$source_id)
      named <- nrow(src) > 0L &&
        all(c("source_id", "display_name") %in% names(src))
      if (named) {
        nm <- as.character(src$display_name)[
          match(nm, as.character(src$source_id))
        ]
      }
      return(.coverage_levels(rows, nm, "source_id"))
    }
    if (identical(dim, "affiliation")) {
      a <- x$authorships
      if (is.null(a) || nrow(a) == 0L || !"work_id" %in% names(a)) {
        return(NULL)
      }
      res <- .resolve_institution_labels(a, x$institutions)
      if (is.na(res$column)) return(NULL)
      out <- .coverage_levels(match(as.character(a$work_id), frame$id),
                              res$label, paste0("authorships$", res$column))
      out$kind <- if (res$column == "country_code") "country" else "institution"
      return(out)
    }
    col <- .coverage_pick_column(names(w), dim)
    if (is.na(col)) return(NULL)
    return(.coverage_levels(rows, w[[col]], col))
  }

  if (is.data.frame(x)) {
    nms <- names(x)
    col <- switch(dim,
      source = .coverage_pick_alias(
        nms, c("source", "source_title", "journal", "so", "source_id")
      ),
      affiliation = .coverage_pick_alias(
        nms, c("affiliation", "affiliations", "institution", "country",
               "country_code")
      ),
      .coverage_pick_column(nms, dim)
    )
    if (is.na(col)) return(NULL)
    out <- .coverage_levels(rows, x[[col]], col)
    if (identical(dim, "affiliation")) {
      out$kind <- if (tolower(col) %in% c("country", "country_code")) {
        "country"
      } else {
        "institution"
      }
    }
    return(out)
  }

  NULL
}

#' Long (row, level) table of one side's values
#'
#' `values` holds one value per entry of `row`, or is a list column whose
#' elements give several values each. Missing and blank values and rows
#' that match no record are dropped; repeated (row, level) pairs count once.
#' @noRd
.coverage_levels <- function(row, values, column) {
  if (is.list(values)) {
    row <- rep(row, lengths(values))
    values <- unlist(lapply(values, as.character), use.names = FALSE)
  }
  level <- as.character(values)
  level[!is.na(level) & !nzchar(trimws(level))] <- NA_character_
  keep <- !is.na(row) & !is.na(level)
  long <- dplyr::distinct(tibble::tibble(row = row[keep], level = level[keep]))
  list(long = long, column = column, kind = NA_character_)
}

#' Column named `name`: the exact name, else the first case-insensitive match
#' @noRd
.coverage_pick_column <- function(nms, name) {
  if (name %in% nms) return(name)
  hit <- which(tolower(nms) == tolower(name))
  if (length(hit) > 0L) nms[hit[1]] else NA_character_
}

#' First column, in alias order, whose lower-cased name is one of `aliases`
#' @noRd
.coverage_pick_alias <- function(nms, aliases) {
  low <- tolower(nms)
  for (alias in aliases) {
    hit <- which(low == alias)
    if (length(hit) > 0L) return(nms[hit[1]])
  }
  NA_character_
}

#' Abort on breakdown names that resolve on neither side
#' @noRd
.coverage_abort_unknown <- function(unknown, corpus, reference, call) {
  if (is_sm_corpus(reference)) {
    .coverage_abort_columns(unknown, "reference$works", names(reference$works),
                            names(corpus$works), call = call)
  } else {
    .coverage_abort_columns(unknown, "reference", names(reference),
                            names(corpus$works), call = call)
  }
}

#' The abort itself, with the column names of both sides
#' @noRd
.coverage_abort_columns <- function(unknown, ref_where, ref_cols, works_cols,
                                    call) {
  cli::cli_abort(c(
    "Can't break the coverage down by {.val {unknown}}.",
    "x" = "{cli::qty(length(unknown))}{?This name is/These names are}
           neither a named dimension nor a column of {.arg reference} or of
           {.code corpus$works}.",
    "i" = "Named dimensions: {.val {(.coverage_named_dims())}}.",
    "i" = "Columns of {.code {ref_where}}: {.val {ref_cols}}.",
    "i" = "Columns of {.code corpus$works}: {.val {works_cols}}."
  ), call = call)
}

#' Say where the affiliation levels of each side come from
#'
#' One message naming the column of each side, and one warning when an
#' `sm_corpus` side falls back to country codes or the two sides list
#' different kinds of level (institutions vs countries).
#' @noRd
.coverage_affiliation_notes <- function(d, call = rlang::caller_env()) {
  ref <- d$reference
  cor <- d$corpus
  if (is.null(ref) && is.null(cor)) return(invisible(NULL))

  msg <- c(
    if (!is.null(ref)) {
      c("i" = "Reference side: affiliation levels from
               {.field {d$reference$column}}.")
    },
    if (!is.null(cor)) {
      c("i" = "Corpus side: affiliation levels from
               {.field {d$corpus$column}}.")
    }
  )
  cli::cli_inform(msg, class = "scimapR_coverage_affiliation_levels")

  from_corpus <- function(side) {
    !is.null(side) && identical(side$column, "authorships$country_code")
  }
  fallback <- c(reference = from_corpus(ref), corpus = from_corpus(cor))
  sides <- names(fallback)[fallback]
  mixed <- !is.null(ref) && !is.null(cor) && !identical(ref$kind, cor$kind)
  if (length(sides) > 0L) {
    cli::cli_warn(c(
      "!" = "The {sides} side{?s} of the affiliation breakdown
             {?falls/fall} back to country codes: no authorship has an
             institution label.",
      if (mixed) {
        c("!" = "The other side lists institutions, so the levels of the two
                 sides do not join.")
      },
      "i" = "Run {.fn sm_affiliation_match} (or
             {.fn sm_attribute_institution}) first to break the coverage down
             by institution."
    ), class = "scimapR_coverage_country_fallback", call = call)
  } else if (mixed) {
    cli::cli_warn(c(
      "!" = "The affiliation levels of the two sides do not join: the
             reference lists {(.coverage_kind_label(ref$kind))} and the
             corpus {(.coverage_kind_label(cor$kind))}.",
      "i" = "Give the reference an {.field affiliation} or
             {.field institution} column, or match the corpus affiliations
             with {.fn sm_affiliation_match}."
    ), class = "scimapR_coverage_affiliation_kinds", call = call)
  }
  invisible(NULL)
}

#' Plural noun for a kind of affiliation level
#' @noRd
.coverage_kind_label <- function(kind) {
  if (identical(kind, "country")) "countries" else "institutions"
}

#' @rdname sm_coverage_audit
#' @param x An `sm_coverage` object.
#' @param ... Ignored.
#' @return `print` returns `x` invisibly.
#' @export
print.sm_coverage <- function(x, ...) {
  cli::cli_h1("<sm_coverage>")
  cli::cli_text("{.strong Match strategy:} {x$match} (title threshold {x$threshold})")
  cli::cli_text("{.strong Recall:}    {.val {x$recall}}  ({x$n_matched}/{x$n_reference} reference records found)")
  cli::cli_text(
    "{.strong Precision:} {.val {x$precision}}  ",
    "({x$n_corpus_matched %||% x$n_matched}/{x$n_corpus} corpus records in ",
    "reference)"
  )
  cli::cli_text("{.strong F1:}        {.val {x$f1}}")
  cli::cli_text("")
  cli::cli_text("{.strong Corpus-only:} {x$n_corpus_only}   {.strong Reference-only:} {x$n_reference_only}")

  if (!is.null(x$indexability) && nrow(x$indexability) > 0L) {
    n_idx <- sum(x$indexability$n_records[x$indexability$indexable %in% TRUE])
    cli::cli_text("{.strong Indexable journals:} {n_idx}/{x$n_corpus} corpus records in a journal index")
  }

  bd <- x$breakdowns
  for (dim in unique(bd$dimension)) {
    sub <- dplyr::filter(bd, .data$dimension == dim)
    if (nrow(sub) == 0L) next
    cli::cli_text("")
    cli::cli_h3("Worst-covered slices by {dim}")
    worst <- utils::head(dplyr::arrange(sub, .data$recall), 5L)
    for (i in seq_len(nrow(worst))) {
      cli::cli_text("  {worst$level[i]}: recall {worst$recall[i]} ({worst$n_matched[i]}/{worst$n_reference[i]})")
    }
  }
  invisible(x)
}

#' @rdname sm_coverage_audit
#' @param object An `sm_coverage` object.
#' @return `summary` returns a one-row tibble of headline metrics: `recall`,
#'   `precision`, `f1`, `n_corpus`, `n_reference`, `n_matched`,
#'   `n_corpus_only`, `n_reference_only` and `n_corpus_matched`, so that
#'   `n_matched + n_reference_only` gives `n_reference` and
#'   `n_corpus_matched + n_corpus_only` gives `n_corpus`.
#' @export
summary.sm_coverage <- function(object, ...) {
  tibble::tibble(
    recall = object$recall,
    precision = object$precision,
    f1 = object$f1,
    n_corpus = object$n_corpus,
    n_reference = object$n_reference,
    n_matched = object$n_matched,
    n_corpus_only = object$n_corpus_only,
    n_reference_only = object$n_reference_only,
    # objects from scimapR 0.4.0 have one count for both sides
    n_corpus_matched = object$n_corpus_matched %||% object$n_matched
  )
}

#' @rdname sm_coverage_audit
#' @param object An `sm_coverage` object.
#' @param dim Which breakdown dimension to plot (defaults to the first
#'   available). If no breakdowns exist, a recall/precision summary bar is
#'   drawn.
#' @return `autoplot` returns a `ggplot` object.
#' @importFrom ggplot2 autoplot
#' @export
autoplot.sm_coverage <- function(object, dim = NULL, ...) {
  bd_all <- object$breakdowns
  bd_names <- unique(bd_all$dimension)

  if (length(bd_names) == 0L) {
    df <- tibble::tibble(
      metric = factor(c("recall", "precision", "f1"),
                      levels = c("recall", "precision", "f1")),
      value = c(object$recall, object$precision, object$f1)
    )
    return(
      ggplot2::ggplot(df, ggplot2::aes(.data$metric, .data$value,
                                       fill = .data$metric)) +
        ggplot2::geom_col() +
        ggplot2::ylim(0, 1) +
        sm_scale_fill() +
        sm_theme() +
        ggplot2::labs(title = "Coverage summary", x = NULL, y = NULL) +
        ggplot2::theme(legend.position = "none")
    )
  }

  dim <- dim %||% bd_names[1]
  bd <- dplyr::filter(bd_all, .data$dimension == dim)

  ggplot2::ggplot(bd, ggplot2::aes(.data$level, .data$recall,
                                   fill = .data$recall)) +
    ggplot2::geom_col() +
    ggplot2::ylim(0, 1) +
    sm_scale_fill(discrete = FALSE) +
    sm_theme() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)) +
    ggplot2::labs(
      title = paste0("Coverage (recall) by ", dim),
      x = dim, y = "Recall"
    )
}

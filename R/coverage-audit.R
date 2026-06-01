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
#'   against `doi`/`di` and `title`/`ti`/`display_name`; an `id`/`work_id`/
#'   `reference_id` column is used as the identifier if present).
#' @param by Optional character vector of breakdown dimensions, any of
#'   `"year"`, `"source"`, `"affiliation"`. Per-slice recall is reported for
#'   each supplied dimension.
#' @param match Matching strategy: `"doi_then_title"` (default), `"doi"`, or
#'   `"title"`.
#' @param threshold Minimum Jaro-Winkler title similarity (`[0, 1]`) to accept
#'   a title match. Default `0.9`. When the optional `stringdist` package is
#'   not installed, the title fallback degrades to normalised exact matching.
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
#'     \item{recall}{Matched reference records / total reference records.}
#'     \item{precision}{Matched corpus records / total corpus records.}
#'     \item{f1}{Harmonic mean of recall and precision.}
#'     \item{n_corpus, n_reference, n_matched}{Integer counts.}
#'     \item{n_corpus_only, n_reference_only}{Unmatched counts.}
#'     \item{matches}{Tibble with one row per corpus record: `corpus_id`,
#'       `reference_id`, `match_type` (`"doi"`/`"title"`/`"none"`),
#'       `match_score`. When `index_table` is supplied, also `issn`,
#'       `indexable` (logical), and `indexed_title`.}
#'     \item{corpus_only}{Tibble of corpus records absent from the reference.}
#'     \item{reference_only}{Tibble of reference records absent from the
#'       corpus.}
#'     \item{breakdowns}{A single flat tibble (`dimension`, `level`,
#'       `n_reference`, `n_matched`, `recall`) across all `by` dimensions. Use
#'       [sm_coverage_breakdowns()] to access/filter it.}
#'     \item{breakdowns_nested}{The legacy named list of per-dimension tibbles
#'       (`slice`, `n_reference`, `n_matched`, `recall`). Retained for one
#'       release; prefer `breakdowns`.}
#'     \item{indexability}{When `index_table` is supplied, a summary tibble of
#'       indexable vs non-indexable record counts; otherwise `NULL`.}
#'   }
#'
#' @family coverage
#' @seealso [sm_reconcile()], [sm_journal_in_index()],
#'   [sm_coverage_breakdowns()]
#' @export
#' @examplesIf rlang::is_installed("stringdist")
#' corpus <- sm_example_corpus(n_works = 30, seed = 1)
#' # Pretend the reference is the corpus minus a few works, plus an extra one
#' ref <- corpus$works[1:25, c("work_id", "doi", "title", "year")]
#' cov <- sm_coverage_audit(corpus, ref, by = "year")
#' cov
sm_coverage_audit <- function(corpus,
                              reference,
                              by = NULL,
                              match = c("doi_then_title", "doi", "title"),
                              threshold = 0.9,
                              index_table = NULL,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  match <- rlang::arg_match(match, error_call = call)
  if (!is.null(by)) {
    by <- rlang::arg_match(by, c("year", "source", "affiliation"),
                           multiple = TRUE, error_call = call)
  }

  corpus_frame <- .as_match_frame(corpus)
  ref_frame <- .as_match_frame(reference)

  pairs <- .sm_match_records(corpus_frame, ref_frame, match = match,
                             threshold = threshold)

  n_corpus <- nrow(corpus_frame)
  n_reference <- nrow(ref_frame)
  n_matched <- nrow(pairs)

  recall <- if (n_reference > 0L) n_matched / n_reference else NA_real_
  precision <- if (n_corpus > 0L) n_matched / n_corpus else NA_real_
  f1 <- if (!is.na(recall) && !is.na(precision) && (recall + precision) > 0) {
    2 * recall * precision / (recall + precision)
  } else {
    NA_real_
  }

  # provenance: one row per corpus record
  matches <- dplyr::left_join(
    tibble::tibble(corpus_id = corpus_frame$id),
    dplyr::rename(pairs, corpus_id = "a_id", reference_id = "b_id"),
    by = "corpus_id"
  )
  matches$match_type[is.na(matches$match_type)] <- "none"
  matches <- tibble::tibble(
    corpus_id = matches$corpus_id,
    reference_id = matches$reference_id,
    match_type = matches$match_type,
    match_score = matches$match_score
  )

  corpus_only_ids <- setdiff(corpus_frame$id, pairs$a_id)
  reference_only_ids <- setdiff(ref_frame$id, pairs$b_id)

  corpus_only <- dplyr::filter(corpus_frame, .data$id %in% corpus_only_ids)
  reference_only <- dplyr::filter(ref_frame, .data$id %in% reference_only_ids)

  # ---- breakdowns: nested list (legacy) + flat tibble (preferred) ----
  matched_ref_ids <- pairs$b_id
  breakdowns_nested <- list()
  for (dim in by) {
    breakdowns_nested[[dim]] <- .coverage_breakdown(reference, ref_frame,
                                                    matched_ref_ids, dim)
  }
  breakdowns <- .flatten_breakdowns(breakdowns_nested)

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
      n_corpus_only = length(corpus_only_ids),
      n_reference_only = length(reference_only_ids),
      match = match,
      threshold = threshold,
      matches = matches,
      corpus_only = corpus_only,
      reference_only = reference_only,
      breakdowns = breakdowns,
      breakdowns_nested = breakdowns_nested,
      indexability = indexability
    ),
    class = "sm_coverage"
  )
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
#' [sm_coverage_audit()] result as a single flat tibble (`dimension`, `level`,
#' `n_reference`, `n_matched`, `recall`), optionally filtered to one dimension.
#'
#' @param x An `sm_coverage` object.
#' @param dimension Optional dimension name (e.g. `"year"`) to filter to.
#'
#' @return A tibble. Type-stable: returns a 0-row tibble with the documented
#'   columns when there are no breakdowns.
#'
#' @family coverage
#' @seealso [sm_coverage_audit()]
#' @export
#' @examplesIf rlang::is_installed("stringdist")
#' corpus <- sm_example_corpus(n_works = 30, seed = 1)
#' ref <- corpus$works[1:25, c("work_id", "doi", "title", "year")]
#' cov <- sm_coverage_audit(corpus, ref, by = "year")
#' sm_coverage_breakdowns(cov, dimension = "year")
sm_coverage_breakdowns <- function(x, dimension = NULL) {
  if (!inherits(x, "sm_coverage")) {
    cli::cli_abort("{.arg x} must be an {.cls sm_coverage} object.")
  }
  bd <- x$breakdowns
  if (!is.null(dimension)) {
    bd <- dplyr::filter(bd, .data$dimension %in% .env$dimension)
  }
  bd
}

#' Per-dimension recall breakdown for a coverage audit
#' @noRd
.coverage_breakdown <- function(reference, ref_frame, matched_ref_ids, dim) {
  empty <- tibble::tibble(
    slice = character(), n_reference = integer(),
    n_matched = integer(), recall = double()
  )
  slice <- .coverage_dim_values(reference, ref_frame, dim)
  if (is.null(slice)) {
    cli::cli_warn(c(
      "!" = "Could not resolve breakdown dimension {.val {dim}} from the reference.",
      "i" = "Returning an empty breakdown for {.val {dim}}."
    ))
    return(empty)
  }

  df <- tibble::tibble(
    id = ref_frame$id,
    slice = slice,
    matched = ref_frame$id %in% matched_ref_ids
  )
  df <- dplyr::filter(df, !is.na(.data$slice))
  if (nrow(df) == 0L) return(empty)

  df %>%
    dplyr::group_by(.data$slice) %>%
    dplyr::summarise(
      n_reference = dplyr::n(),
      n_matched = sum(.data$matched),
      recall = round(sum(.data$matched) / dplyr::n(), 4),
      .groups = "drop"
    ) %>%
    dplyr::arrange(.data$slice)
}

#' Resolve per-record dimension values for a coverage breakdown
#'
#' Returns a character vector aligned to `ref_frame` rows, or `NULL` if the
#' dimension cannot be resolved.
#' @noRd
.coverage_dim_values <- function(reference, ref_frame, dim) {
  if (dim == "year") {
    return(as.character(ref_frame$year))
  }

  if (is_sm_corpus(reference)) {
    if (dim == "source") {
      w <- reference$works
      src <- reference$sources
      nm <- rep(NA_character_, nrow(w))
      if ("source_id" %in% names(w)) {
        if (nrow(src) > 0L && all(c("source_id", "display_name") %in% names(src))) {
          nm <- src$display_name[match(w$source_id, src$source_id)]
        } else {
          nm <- as.character(w$source_id)
        }
      }
      return(nm[match(ref_frame$id, as.character(w$work_id))])
    }
    if (dim == "affiliation") {
      a <- reference$authorships
      if (nrow(a) == 0L || !"country_code" %in% names(a)) return(NULL)
      first_cc <- a %>%
        dplyr::filter(!is.na(.data$country_code)) %>%
        dplyr::group_by(.data$work_id) %>%
        dplyr::summarise(cc = .data$country_code[1], .groups = "drop")
      return(first_cc$cc[match(ref_frame$id,
                               as.character(first_cc$work_id))])
    }
  }

  # data-frame reference: look for an appropriate column
  if (is.data.frame(reference)) {
    nms <- names(reference)
    low <- tolower(nms)
    aliases <- switch(dim,
      source = c("source", "journal", "so", "source_id", "source_title"),
      affiliation = c("affiliation", "institution", "country",
                      "country_code", "affiliations"),
      character()
    )
    hit <- which(low %in% aliases)
    if (length(hit) == 0L) return(NULL)
    vals <- as.character(reference[[nms[hit[1]]]])
    # align by id if the reference carries an id column, else assume row order
    rf_ids <- ref_frame$id
    id_hit <- which(low %in% c("id", "work_id", "reference_id", "ref_id"))
    if (length(id_hit) > 0L) {
      return(vals[match(rf_ids, as.character(reference[[nms[id_hit[1]]]]))])
    }
    return(vals)
  }

  NULL
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
  cli::cli_text("{.strong Precision:} {.val {x$precision}}  ({x$n_matched}/{x$n_corpus} corpus records in reference)")
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
#' @return `summary` returns a one-row tibble of headline metrics.
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
    n_reference_only = object$n_reference_only
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

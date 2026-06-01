#' Reconcile two corpora by DOI and title
#'
#' @description
#' Computes a symmetric set difference between two corpora (or coercible data
#' frames) using the shared DOI-then-title matching engine. This generalises
#' [sm_diff_corpora()], which compares strictly by internal `work_id`:
#' `sm_reconcile()` instead matches on *content* (normalised DOI with a fuzzy
#' title fallback), so it works across corpora from different sources that do
#' not share identifiers.
#'
#' @param corpus_a,corpus_b An `sm_corpus` or a data frame with DOI and/or
#'   title columns (see [sm_coverage_audit()] for accepted column aliases).
#' @param match Matching strategy: `"doi_then_title"` (default), `"doi"`, or
#'   `"title"`.
#' @param threshold Minimum Jaro-Winkler title similarity (`[0, 1]`) to accept
#'   a title match (default `0.9`).
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_reconciliation` S3 object with components:
#'   \describe{
#'     \item{in_both}{Tibble of matched pairs: `a_id`, `b_id`, `title`,
#'       `match_type`, `match_score`.}
#'     \item{only_a}{Tibble of `corpus_a` records absent from `corpus_b`
#'       (`id`, `doi`, `title`, `year`).}
#'     \item{only_b}{Tibble of `corpus_b` records absent from `corpus_a`.}
#'     \item{matches}{Match provenance tibble (`a_id`, `b_id`, `match_type`,
#'       `match_score`), the same shape as [sm_coverage_audit()]'s.}
#'     \item{summary}{One-row tibble with counts.}
#'   }
#'
#' @family coverage
#' @seealso [sm_coverage_audit()], [sm_diff_corpora()]
#' @export
#' @examplesIf rlang::is_installed("stringdist")
#' a <- sm_example_corpus(n_works = 20, seed = 1)
#' b <- sm_example_corpus(n_works = 20, seed = 1)[5:20]
#' rec <- sm_reconcile(a, b)
#' rec
sm_reconcile <- function(corpus_a, corpus_b,
                         match = c("doi_then_title", "doi", "title"),
                         threshold = 0.9,
                         call = rlang::caller_env()) {
  match <- rlang::arg_match(match, error_call = call)

  a <- .as_match_frame(corpus_a)
  b <- .as_match_frame(corpus_b)

  pairs <- .sm_match_records(a, b, match = match, threshold = threshold)

  in_both <- tibble::tibble(
    a_id = pairs$a_id,
    b_id = pairs$b_id,
    title = a$title[match(pairs$a_id, a$id)],
    match_type = pairs$match_type,
    match_score = pairs$match_score
  )

  only_a <- dplyr::filter(a, !(.data$id %in% pairs$a_id))
  only_b <- dplyr::filter(b, !(.data$id %in% pairs$b_id))

  matches <- tibble::tibble(
    a_id = pairs$a_id,
    b_id = pairs$b_id,
    match_type = pairs$match_type,
    match_score = pairs$match_score
  )

  summary_tbl <- tibble::tibble(
    n_a = nrow(a),
    n_b = nrow(b),
    n_in_both = nrow(in_both),
    n_only_a = nrow(only_a),
    n_only_b = nrow(only_b),
    jaccard = if ((nrow(a) + nrow(b) - nrow(in_both)) > 0) {
      round(nrow(in_both) / (nrow(a) + nrow(b) - nrow(in_both)), 4)
    } else {
      NA_real_
    }
  )

  structure(
    list(
      in_both = in_both,
      only_a = only_a,
      only_b = only_b,
      matches = matches,
      summary = summary_tbl
    ),
    class = "sm_reconciliation"
  )
}

#' @rdname sm_reconcile
#' @param x An `sm_reconciliation` object.
#' @param ... Ignored.
#' @return `print` returns `x` invisibly.
#' @export
print.sm_reconciliation <- function(x, ...) {
  s <- x$summary
  cli::cli_h1("<sm_reconciliation>")
  cli::cli_text("{.strong A:} {s$n_a} records   {.strong B:} {s$n_b} records")
  cli::cli_text("{.strong In both:} {s$n_in_both}   {.strong Only A:} {s$n_only_a}   {.strong Only B:} {s$n_only_b}")
  cli::cli_text("{.strong Jaccard overlap:} {.val {s$jaccard}}")
  if (nrow(x$in_both) > 0L) {
    n_doi <- sum(x$in_both$match_type == "doi")
    n_title <- sum(x$in_both$match_type == "title")
    cli::cli_text("{.strong Matched via:} {n_doi} DOI, {n_title} title")
  }
  invisible(x)
}

#' @rdname sm_reconcile
#' @param object An `sm_reconciliation` object.
#' @return `summary` returns the one-row summary tibble.
#' @export
summary.sm_reconciliation <- function(object, ...) {
  object$summary
}

#' @rdname sm_reconcile
#' @param object An `sm_reconciliation` object.
#' @return `autoplot` returns a `ggplot` set-size bar chart.
#' @importFrom ggplot2 autoplot
#' @export
autoplot.sm_reconciliation <- function(object, ...) {
  s <- object$summary
  df <- tibble::tibble(
    set = factor(c("Only A", "In both", "Only B"),
                 levels = c("Only A", "In both", "Only B")),
    n = c(s$n_only_a, s$n_in_both, s$n_only_b)
  )
  ggplot2::ggplot(df, ggplot2::aes(.data$set, .data$n, fill = .data$set)) +
    ggplot2::geom_col() +
    ggplot2::geom_text(ggplot2::aes(label = .data$n), vjust = -0.3) +
    sm_scale_fill() +
    sm_theme() +
    ggplot2::theme(legend.position = "none") +
    ggplot2::labs(title = "Corpus reconciliation", x = NULL,
                  y = "Number of records")
}

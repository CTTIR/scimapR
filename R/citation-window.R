#' Citations within a fixed window after publication
#'
#' @description
#' Counts each work's citations in its publication year and the `window`
#' years after it, from the yearly citation counts of the corpus
#' (`citations_by_year`, written by the OpenAlex readers and
#' [sm_enrich_openalex_impact()]), and says whether the counts cover the
#' whole window. Fixed windows compare old and recent works fairly, which
#' `cited_by_count` (all citations up to now) does not.
#'
#' @param corpus An `sm_corpus`.
#' @param window Number of years after the publication year, a whole number
#'   of 0 or more (default `3`). The window runs from the publication year
#'   through the publication year plus `window`, so it spans `window + 1`
#'   calendar years: `window = 3` counts the citations of a work from 2020
#'   in 2020 to 2023.
#' @param call Caller environment for error reporting.
#'
#' @details
#' OpenAlex gives the citations of the ten most recent years only (its
#' `counts_by_year`: the year of the counts and the nine before it), and
#' leaves out the years without citations. A year missing from
#' `citations_by_year` therefore counts 0 for a work that has yearly
#' counts. The date of the counts is `works$citations_as_of` (the day
#' OpenAlex last updated the record, or of the fetch); its year is still
#' running, so it counts as partial. A corpus restored with
#' [sm_corpus_from_tables()] may hold this date as a day count (days since
#' 1970-01-01, as SQLite keeps dates) or as ISO 8601 text; both are read as
#' the date they stand for.
#'
#' A window is `complete` when the work has a publication year and yearly
#' counts with a known date, its first year (the publication year) is no
#' earlier than nine years before the year of the counts, and its last year
#' is before the year of the counts. Otherwise `complete` is `FALSE` and
#' `citations` is a lower bound: the citations the counts hold for the
#' window years. A work without a publication year, or without yearly
#' counts (no rows in `citations_by_year` and no `citations_as_of`), gets
#' `citations = NA`.
#'
#' The result depends only on the corpus, never on today's date, so it is
#' the same in every session. A corpus without `citations_by_year` gives
#' `NA` for every work, with one message (class
#' `scimapR_no_citations_by_year`) that points to
#' [sm_enrich_openalex_impact()].
#'
#' @return A tibble with one row per work, in the order of `corpus$works`:
#'   `work_id` (character), `year` (integer, the publication year), `window`
#'   (integer), `citations` (integer) and `complete` (logical). A corpus
#'   without works gives a 0-row tibble with these columns.
#'
#' @family counting
#' @seealso [sm_citation_maturity()], [sm_enrich_openalex_impact()]
#' @export
#' @examples
#' works <- data.frame(
#'   work_id = c("W1", "W2", "W3"),
#'   title = c("Early work", "Recent work", "Unknown counts"),
#'   year = c(2018L, 2024L, 2019L),
#'   citations_as_of = as.Date(c("2026-10-17", "2026-10-17", NA))
#' )
#' yearly <- data.frame(
#'   work_id = c("W1", "W1", "W1", "W2"),
#'   year = c(2018L, 2019L, 2021L, 2025L),
#'   cited_by_count = c(2L, 5L, 4L, 3L)
#' )
#' corpus <- sm_corpus_from_tables(
#'   list(works = works, citations_by_year = yearly)
#' )
#' sm_citation_window(corpus, window = 3)
sm_citation_window <- function(corpus, window = 3L,
                               call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  if (!rlang::is_integerish(window, n = 1, finite = TRUE) || window < 0) {
    cli::cli_abort(
      "{.arg window} must be a whole number of 0 or more.",
      call = call
    )
  }
  window <- as.integer(window)

  works <- corpus$works
  year <- as.integer(works$year)
  n <- nrow(works)
  out <- tibble::tibble(
    work_id = as.character(works$work_id),
    year = year,
    window = rep(window, n),
    citations = rep(NA_integer_, n),
    complete = rep(FALSE, n)
  )
  if (n == 0L) return(out)

  yearly <- corpus$citations_by_year
  if (is.null(yearly)) {
    cli::cli_inform(
      c("i" = "The corpus has no yearly citation counts
               ({.field citations_by_year}), so every window is {.code NA}.",
        "i" = "Add them with {.fn sm_enrich_openalex_impact}."),
      class = "scimapR_no_citations_by_year"
    )
    return(out)
  }

  as_of <- if ("citations_as_of" %in% names(works)) {
    .citation_years(works$citations_as_of)
  } else {
    rep(NA_integer_, n)
  }
  has_counts <- out$work_id %in% yearly$work_id | !is.na(as_of)

  # citations of each work in its window years (missing years count 0)
  pub <- year[match(yearly$work_id, out$work_id)]
  in_window <- !is.na(pub) & yearly$year >= pub & yearly$year <= pub + window
  sums <- tapply(yearly$cited_by_count[in_window],
                 yearly$work_id[in_window], sum)
  citations <- as.integer(sums[out$work_id])
  citations[is.na(citations)] <- 0L
  citations[!has_counts | is.na(year)] <- NA_integer_
  out$citations <- citations

  out$complete <- has_counts & !is.na(year) & !is.na(as_of) &
    year >= as_of - 9L & year + window < as_of
  out
}

#' Calendar years of stored dates, one per value; `NA` when missing
#'
#' A Date, a day count (days since 1970-01-01) or ISO 8601 text, as
#' `.as_day_dates()` reads them.
#' @noRd
.citation_years <- function(x) {
  as.integer(format(.as_day_dates(x, what = "works$citations_as_of"), "%Y"))
}

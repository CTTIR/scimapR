#' Geographic representation audit
#'
#' @description
#' Audits the geographic distribution of a corpus, tabulating the
#' representation of countries, regions, or World Bank income tiers.
#' The analysis can be weighted by work count, total citations,
#' first-authorship, or corresponding authorship. Each work counts once
#' per distinct known group, with optional fractional credit.
#'
#' The result includes a Gini coefficient for concentration and a
#' coverage metric (proportion of works with known geography).
#'
#' @param corpus An `sm_corpus` object.
#' @param by Character. Grouping variable: `"country"` (ISO 3166-1 alpha-2
#'   codes from authorships), `"region"` (from institutions table), or
#'   `"income_tier"` (World Bank income classification from institutions).
#' @param weight Character. How to weight each work: `"count"` (one per
#'   work and group, before applying `method`),
#'   `"citations"` (weighted by cited_by_count), `"first-author"` (only
#'   first-author affiliations), `"corresponding"` (only corresponding-author
#'   affiliations).
#' @param method Counting rule: `"full"` gives each work one unit per
#'   distinct known group; `"fractional"` splits one unit equally among its
#'   known groups. Citation credit is split by the same shares.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_geographic` S3 object containing:
#' \describe{
#'   \item{distribution}{Tibble with columns `group`, `count`, `citations`,
#'     `pct`, `credit` and `weighted_citations`. Counts and raw citations
#'     include each work once per group under both methods. Percentages
#'     and the Gini use credit, or weighted citations for citation weighting.
#'     Count percentages describe work-group pairs under full counting and
#'     works under fractional counting.}
#'   \item{gini}{Gini coefficient of the distribution.}
#'   \item{coverage}{Proportion of works with at least one known geography.}
#'   \item{by}{The grouping variable used.}
#'   \item{weight}{The weighting method used.}
#'   \item{method}{The counting rule used.}
#' }
#'
#' @details
#' Coverage uses all corpus works as its denominator and counts works with
#' at least one known group after the authorship filter. Missing geography
#' is excluded from credit allocation; incomplete metadata can therefore
#' change both coverage and the shares assigned to known groups.
#'
#' @family audit
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' geo <- sm_audit_geographic(corpus)
#' print(geo)
sm_audit_geographic <- function(corpus,
                                by = c("country", "region", "income_tier"),
                                weight = c("count", "citations",
                                           "first-author", "corresponding"),
                                method = c("full", "fractional"),
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  by <- match.arg(by)
  weight <- match.arg(weight)
  method <- match.arg(method)
  if (nrow(corpus$works) == 0L) {
    return(.empty_audit_geographic(by, weight, method))
  }

  aships <- corpus$authorships
  if (weight == "first-author") {
    aships <- dplyr::filter(aships, .data$position == 1L)
  } else if (weight == "corresponding") {
    aships <- dplyr::filter(aships, .data$is_corresponding %in% TRUE)
  }
  if (by == "country") {
    aships$group <- aships$country_code
  } else {
    institutions <- corpus$institutions
    if (nrow(institutions) > 0L && by %in% names(institutions)) {
      lookup <- institutions[c("institution_id", by)]
      names(lookup)[2L] <- "group"
      aships <- dplyr::left_join(
        aships, lookup, by = "institution_id", na_matches = "never"
      )
    } else {
      aships$group <- rep(NA_character_, nrow(aships))
    }
  }

  known <- unique(aships[c("work_id", "group")])
  known <- dplyr::filter(
    known, !is.na(.data$group), nzchar(trimws(.data$group)),
    .data$work_id %in% corpus$works$work_id
  )
  if (nrow(known) == 0L) {
    return(.empty_audit_geographic(by, weight, method))
  }
  coverage <- length(unique(known$work_id)) / nrow(corpus$works)
  known <- dplyr::left_join(
    known, corpus$works[c("work_id", "cited_by_count")], by = "work_id"
  )
  known <- known |>
    dplyr::group_by(.data$work_id) |>
    dplyr::mutate(
      credit = if (method == "fractional") 1 / dplyr::n() else 1
    ) |>
    dplyr::ungroup()
  dist <- known |>
    dplyr::group_by(.data$group) |>
    dplyr::summarise(
      count = dplyr::n(),
      citations = sum(.data$cited_by_count, na.rm = TRUE),
      weighted_citations = sum(
        .data$credit * .data$cited_by_count, na.rm = TRUE
      ),
      credit = sum(.data$credit),
      .groups = "drop"
    )
  quantity <- if (weight == "citations") {
    dist$weighted_citations
  } else {
    dist$credit
  }
  dist$pct <- if (sum(quantity) == 0) {
    rep(0, nrow(dist))
  } else {
    round(100 * quantity / sum(quantity), 2)
  }
  dist <- dist[order(-dist$pct, dist$group), ]
  dist <- dist[c(
    "group", "count", "citations", "pct", "credit", "weighted_citations"
  )]
  structure(
    list(
      distribution = dist, gini = round(.compute_gini(quantity), 3),
      coverage = round(coverage, 3), by = by, weight = weight, method = method
    ),
    class = "sm_audit_geographic"
  )
}

#' Empty geographic audit result
#' @noRd
.empty_audit_geographic <- function(by = "country", weight = "count",
                                    method = "full") {
  structure(
    list(
      distribution = tibble::tibble(
        group = character(), count = integer(), citations = integer(),
        pct = double(), credit = double(), weighted_citations = double()
      ),
      gini = NA_real_, coverage = 0.0, by = by, weight = weight, method = method
    ),
    class = "sm_audit_geographic"
  )
}

#' Compute Gini coefficient
#' @noRd
.compute_gini <- function(x) {
  x <- sort(x[!is.na(x)])
  n <- length(x)
  if (n <= 1L || sum(x) == 0) return(0.0)
  index <- seq_len(n)
  2 * sum(index * x) / (n * sum(x)) - (n + 1) / n
}

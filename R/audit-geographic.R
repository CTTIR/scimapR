#' Geographic representation audit
#'
#' @description
#' Audits the geographic distribution of a corpus, tabulating the
#' representation of countries, regions, or World Bank income tiers.
#' The analysis can be weighted by work count, total citations,
#' first-authorship, or corresponding authorship.
#'
#' The result includes a Gini coefficient for concentration and a
#' coverage metric (proportion of works with known geography).
#'
#' @param corpus An `sm_corpus` object.
#' @param by Character. Grouping variable: `"country"` (ISO 3166-1 alpha-2
#'   codes from authorships), `"region"` (from institutions table), or
#'   `"income_tier"` (World Bank income classification from institutions).
#' @param weight Character. How to weight each work: `"count"` (one per work),
#'   `"citations"` (weighted by cited_by_count), `"first-author"` (only
#'   first-author affiliations), `"corresponding"` (only corresponding-author
#'   affiliations).
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_geographic` S3 object containing:
#' \describe{
#'   \item{distribution}{Tibble with columns `group`, `count`, `pct`,
#'     `citations`.}
#'   \item{gini}{Gini coefficient of the distribution.}
#'   \item{coverage}{Proportion of works with at least one known geography.}
#'   \item{by}{The grouping variable used.}
#'   \item{weight}{The weighting method used.}
#' }
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
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  by <- match.arg(by)
  weight <- match.arg(weight)

  if (nrow(corpus$works) == 0L) {
    return(.empty_audit_geographic(by = by, weight = weight))
  }

  # Filter authorships by weight
  aships <- corpus$authorships

  if (weight == "first-author") {
    aships <- dplyr::filter(aships, .data$position == 1L)
  } else if (weight == "corresponding") {
    aships <- dplyr::filter(aships, isTRUE(.data$is_corresponding))
  }

  # Determine grouping column
  if (by == "country") {
    aships$group <- aships$country_code
  } else if (by == "region") {
    # Join with institutions to get region
    if (nrow(corpus$institutions) > 0L) {
      inst_lookup <- dplyr::select(
        corpus$institutions,
        .data$institution_id, group = .data$region
      )
      aships <- dplyr::left_join(aships, inst_lookup,
                                  by = "institution_id")
    } else {
      aships$group <- NA_character_
    }
  } else if (by == "income_tier") {
    if (nrow(corpus$institutions) > 0L) {
      inst_lookup <- dplyr::select(
        corpus$institutions,
        .data$institution_id, group = .data$income_tier
      )
      aships <- dplyr::left_join(aships, inst_lookup,
                                  by = "institution_id")
    } else {
      aships$group <- NA_character_
    }
  }

  # Join with works for citation weighting
  aships <- dplyr::left_join(
    aships,
    dplyr::select(corpus$works, .data$work_id, .data$cited_by_count),
    by = "work_id"
  )

  # Drop unknown
  known <- dplyr::filter(aships, !is.na(.data$group))
  coverage <- if (nrow(aships) > 0L) {
    nrow(known) / nrow(aships)
  } else {
    0.0
  }

  # Aggregate
  if (weight == "citations") {
    dist <- known %>%
      dplyr::group_by(.data$group) %>%
      dplyr::summarise(
        count = dplyr::n(),
        citations = sum(.data$cited_by_count, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(pct = round(100 * .data$citations /
                                  sum(.data$citations, na.rm = TRUE), 2)) %>%
      dplyr::arrange(dplyr::desc(.data$citations))
  } else {
    dist <- known %>%
      dplyr::group_by(.data$group) %>%
      dplyr::summarise(
        count = dplyr::n(),
        citations = sum(.data$cited_by_count, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(pct = round(100 * .data$count /
                                  sum(.data$count, na.rm = TRUE), 2)) %>%
      dplyr::arrange(dplyr::desc(.data$count))
  }

  gini <- .compute_gini(dist$count)

  structure(
    list(
      distribution = dist,
      gini = round(gini, 3),
      coverage = round(coverage, 3),
      by = by,
      weight = weight
    ),
    class = "sm_audit_geographic"
  )
}

#' Empty geographic audit result
#' @noRd
.empty_audit_geographic <- function(by = "country", weight = "count") {
  structure(
    list(
      distribution = tibble::tibble(
        group = character(),
        count = integer(),
        pct = double(),
        citations = integer()
      ),
      gini = NA_real_,
      coverage = 0.0,
      by = by,
      weight = weight
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

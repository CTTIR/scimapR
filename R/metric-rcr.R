#' Calculate Relative Citation Ratio
#'
#' @description
#' Computes the Relative Citation Ratio (RCR) for each work in the corpus.
#' RCR normalises citation counts by the expected citation rate of works in
#' the same field and publication year, providing a field-normalised measure
#' of scientific influence.
#'
#' @param corpus An [sm_corpus] object.
#' @param baseline Character; the normalisation baseline. Currently only
#'   `"field_year"` is supported, which normalises by field (derived from
#'   concepts) and publication year.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns `work_id`, `cited_by_count`, `expected_rate`,
#'   and `rcr`. Works without sufficient data receive `NA` for `rcr`.
#'
#' @details
#' The RCR is calculated as:
#'
#' \deqn{RCR = \frac{C_i}{E_i}}{RCR = C_i / E_i}
#'
#' Where:
#' \describe{
#'   \item{C_i}{The citation count of work *i*.}
#'   \item{E_i}{The expected citation count, computed as the mean citation
#'     count of works in the same field-year group.}
#' }
#'
#' Field assignment uses the top-level concept (level 0) from the concepts
#' table. Works without concept assignments are grouped into an "unclassified"
#' field.
#'
#' An RCR of 1.0 means the work is cited at the average rate for its
#' field-year. Values above 1.0 indicate above-average impact.
#'
#' @references
#' Hutchins, B. I., Yuan, X., Anderson, J. M., & Santangelo, G. M. (2016).
#' Relative Citation Ratio (RCR): A New Metric That Uses Citation Rates to
#' Measure Influence at the Article Level. *PLOS Biology*, 14(9), e1002541.
#' \doi{10.1371/journal.pbio.1002541}
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' rcr <- sm_metric_rcr(corpus)
#' head(rcr)
sm_metric_rcr <- function(corpus,
                          baseline = "field_year",
                          call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(baseline, call = call)

  if (baseline != "field_year") {
    cli::cli_abort(
      "Currently only {.val field_year} baseline is supported.",
      call = call
    )
  }

  works <- corpus$works
  concepts <- corpus$concepts

  if (nrow(works) == 0L) {
    return(tibble::tibble(
      work_id = character(), cited_by_count = integer(),
      expected_rate = double(), rcr = double()
    ))
  }

  # Assign each work to a field based on top-level concept
  if (nrow(concepts) > 0L && "level" %in% names(concepts)) {
    # Use the highest-scoring level-0 concept per work
    field_map <- concepts %>%
      dplyr::filter(.data$level == 0L) %>%
      dplyr::group_by(.data$work_id) %>%
      dplyr::slice_max(order_by = .data$score, n = 1L, with_ties = FALSE) %>%
      dplyr::ungroup() %>%
      dplyr::select("work_id", field = "concept_name")
  } else {
    field_map <- tibble::tibble(work_id = character(), field = character())
  }

  # Join field to works
  work_data <- works %>%
    dplyr::select("work_id", "year", "cited_by_count") %>%
    dplyr::left_join(field_map, by = "work_id") %>%
    dplyr::mutate(field = ifelse(is.na(.data$field), "unclassified",
                                 .data$field))

  # Compute expected citation rate per field-year group
  group_means <- work_data %>%
    dplyr::group_by(.data$field, .data$year) %>%
    dplyr::summarise(
      expected_rate = mean(.data$cited_by_count, na.rm = TRUE),
      .groups = "drop"
    )

  # Join and compute RCR
  result <- work_data %>%
    dplyr::left_join(group_means, by = c("field", "year")) %>%
    dplyr::mutate(
      rcr = dplyr::if_else(
        is.na(.data$expected_rate) | .data$expected_rate == 0,
        NA_real_,
        .data$cited_by_count / .data$expected_rate
      ),
      rcr = round(.data$rcr, 4)
    ) %>%
    dplyr::select("work_id", "cited_by_count", "expected_rate", "rcr")

  result
}

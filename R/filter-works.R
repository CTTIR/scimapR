#' Filter works in a corpus
#'
#' @description
#' Subset a corpus by filtering works on year, type, OA status, or
#' custom expressions.
#'
#' @param corpus An `sm_corpus` object.
#' @param ... Filtering expressions passed to [dplyr::filter()], evaluated
#'   in the context of the `works` tibble.
#' @param year_range Optional two-element integer vector for year filtering.
#' @param types Optional character vector of document types to keep.
#' @param oa_only Logical; keep only open access works?
#'
#' @return An `sm_corpus` with the filtered subset.
#'
#' @family filters
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' filtered <- sm_filter_works(corpus, year_range = c(2020, 2024))
#' nrow(filtered$works)
sm_filter_works <- function(corpus, ...,
                            year_range = NULL,
                            types = NULL,
                            oa_only = FALSE) {
  .check_sm_corpus(corpus)

  works <- corpus$works

  dots <- rlang::enquos(...)
  if (length(dots) > 0) {
    works <- dplyr::filter(works, !!!dots)
  }

  if (!is.null(year_range)) {
    works <- dplyr::filter(works,
      !is.na(.data$year),
      .data$year >= year_range[1],
      .data$year <= year_range[2]
    )
  }

  if (!is.null(types)) {
    works <- dplyr::filter(works, .data$type %in% types)
  }

  if (oa_only) {
    works <- dplyr::filter(works,
      .data$oa_status %in% c("gold", "green", "hybrid", "bronze")
    )
  }

  keep_ids <- works$work_id
  corpus[which(corpus$works$work_id %in% keep_ids)]
}

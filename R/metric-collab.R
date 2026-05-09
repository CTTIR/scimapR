#' Calculate collaboration index
#'
#' @description
#' Computes several collaboration indicators for the corpus, including the
#' Collaboration Index (CI), mean authors per paper, proportion of
#' multi-authored papers, and international collaboration rate.
#'
#' @param corpus An [sm_corpus] object with a populated `authorships` table.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row per work and columns:
#'   \describe{
#'     \item{`work_id`}{The work identifier.}
#'     \item{`n_authors`}{Number of authors on the work.}
#'     \item{`n_countries`}{Number of distinct countries among co-authors.}
#'     \item{`n_institutions`}{Number of distinct institutions among co-authors.}
#'     \item{`is_international`}{Logical; `TRUE` if authors from more than one
#'       country contributed.}
#'     \item{`is_multi_authored`}{Logical; `TRUE` if more than one author.}
#'   }
#'
#' @details
#' The Collaboration Index (CI) for a set of works is typically defined as
#' the mean number of authors per paper. This function returns per-work
#' data, from which aggregate CI can be computed by the user.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' collab <- sm_metric_collab_index(corpus)
#' head(collab)
#' # Aggregate collaboration index:
#' mean(collab$n_authors)
sm_metric_collab_index <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  works <- corpus$works
  authorships <- corpus$authorships

  if (nrow(works) == 0L) {
    return(tibble::tibble(
      work_id = character(), n_authors = integer(),
      n_countries = integer(), n_institutions = integer(),
      is_international = logical(), is_multi_authored = logical()
    ))
  }

  if (nrow(authorships) == 0L) {
    return(tibble::tibble(
      work_id = works$work_id,
      n_authors = rep(NA_integer_, nrow(works)),
      n_countries = rep(NA_integer_, nrow(works)),
      n_institutions = rep(NA_integer_, nrow(works)),
      is_international = rep(NA, nrow(works)),
      is_multi_authored = rep(NA, nrow(works))
    ))
  }

  # Compute per-work collaboration metrics
  work_collab <- authorships %>%
    dplyr::group_by(.data$work_id) %>%
    dplyr::summarise(
      n_authors      = dplyr::n_distinct(.data$author_id),
      n_countries    = dplyr::n_distinct(
        .data$country_code[!is.na(.data$country_code)]
      ),
      n_institutions = dplyr::n_distinct(
        .data$institution_id[!is.na(.data$institution_id)]
      ),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      is_international = .data$n_countries > 1L,
      is_multi_authored = .data$n_authors > 1L
    )

  # Ensure all works are represented
  result <- tibble::tibble(work_id = works$work_id) %>%
    dplyr::left_join(work_collab, by = "work_id")

  result
}

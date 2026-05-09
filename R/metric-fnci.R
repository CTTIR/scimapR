#' Calculate Field-Normalized Citation Impact
#'
#' @description
#' Computes the Field-Normalized Citation Impact (FNCI) for each work in the
#' corpus. FNCI normalises a work's citation count by the average citation
#' count of all works in the same field and publication year.
#'
#' @param corpus An [sm_corpus] object.
#' @param classification Character; the classification system used to assign
#'   works to fields. One of `"openalex_concepts"` (default), `"mesh"`, or
#'   `"manual"`.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns `work_id`, `field`, `year`,
#'   `cited_by_count`, `field_mean`, and `fnci`.
#'
#' @details
#' FNCI is defined as:
#'
#' \deqn{FNCI_i = \frac{C_i}{\bar{C}_{f,y}}}{FNCI_i = C_i / mean(C_f,y)}
#'
#' Where \eqn{C_i} is the citation count of work *i* and
#' \eqn{\bar{C}_{f,y}} is the mean citation count of all works in field *f*
#' published in year *y*.
#'
#' An FNCI of 1.0 means the work is cited at the world average for its
#' field-year. Values > 1.0 indicate above-average impact.
#'
#' For `"openalex_concepts"`, the highest-scoring level-0 concept from the
#' concepts table is used. For `"mesh"`, MeSH terms are used (requires MeSH
#' data in concepts). For `"manual"`, a `field` column must already exist
#' in `corpus$works`.
#'
#' @references
#' Waltman, L., van Eck, N. J., van Leeuwen, T. N., Visser, M. S., &
#' van Raan, A. F. J. (2011). Towards a New Crown Indicator: Some Theoretical
#' Considerations. *Journal of Informetrics*, 5(1), 37--47.
#' \doi{10.1016/j.joi.2010.08.001}
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' fnci <- sm_metric_fnci(corpus, classification = "openalex_concepts")
#' head(fnci)
sm_metric_fnci <- function(corpus,
                           classification = c("openalex_concepts", "mesh",
                                              "manual"),
                           call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  classification <- rlang::arg_match(classification, error_call = call)

  works <- corpus$works

  if (nrow(works) == 0L) {
    return(tibble::tibble(
      work_id = character(), field = character(), year = integer(),
      cited_by_count = integer(), field_mean = double(), fnci = double()
    ))
  }

  # --- assign field ---
  field_map <- .assign_field(corpus, classification, call)

  # Join field to works
  work_data <- works %>%
    dplyr::select("work_id", "year", "cited_by_count") %>%
    dplyr::left_join(field_map, by = "work_id") %>%
    dplyr::mutate(field = ifelse(is.na(.data$field), "unclassified",
                                 .data$field))

  # Compute field-year means
  field_means <- work_data %>%
    dplyr::group_by(.data$field, .data$year) %>%
    dplyr::summarise(
      field_mean = mean(.data$cited_by_count, na.rm = TRUE),
      .groups = "drop"
    )

  # Compute FNCI
  result <- work_data %>%
    dplyr::left_join(field_means, by = c("field", "year")) %>%
    dplyr::mutate(
      fnci = dplyr::if_else(
        is.na(.data$field_mean) | .data$field_mean == 0,
        NA_real_,
        .data$cited_by_count / .data$field_mean
      ),
      fnci = round(.data$fnci, 4)
    ) %>%
    dplyr::select("work_id", "field", "year", "cited_by_count",
                  "field_mean", "fnci")

  result
}


#' Assign works to fields based on classification system
#' @noRd
.assign_field <- function(corpus, classification, call) {
  concepts <- corpus$concepts
  works <- corpus$works

  switch(classification,
    openalex_concepts = {
      if (nrow(concepts) == 0L) {
        return(tibble::tibble(work_id = works$work_id,
                              field = rep(NA_character_, nrow(works))))
      }
      # Use highest-scoring level-0 concept
      concepts %>%
        dplyr::filter(.data$level == 0L) %>%
        dplyr::group_by(.data$work_id) %>%
        dplyr::slice_max(order_by = .data$score, n = 1L,
                         with_ties = FALSE) %>%
        dplyr::ungroup() %>%
        dplyr::select("work_id", field = "concept_name")
    },
    mesh = {
      if (nrow(concepts) == 0L) {
        return(tibble::tibble(work_id = works$work_id,
                              field = rep(NA_character_, nrow(works))))
      }
      # Use MeSH vocabulary concepts
      mesh_concepts <- concepts %>%
        dplyr::filter(tolower(.data$vocabulary) %in% c("mesh", "medline"))
      if (nrow(mesh_concepts) == 0L) {
        cli::cli_inform(c(
          "!" = "No MeSH terms found in concepts table.",
          "i" = "Falling back to {.val unclassified} for all works."
        ))
        return(tibble::tibble(work_id = works$work_id,
                              field = rep(NA_character_, nrow(works))))
      }
      mesh_concepts %>%
        dplyr::group_by(.data$work_id) %>%
        dplyr::slice_max(order_by = .data$score, n = 1L,
                         with_ties = FALSE) %>%
        dplyr::ungroup() %>%
        dplyr::select("work_id", field = "concept_name")
    },
    manual = {
      if ("field" %in% names(works)) {
        works %>% dplyr::select("work_id", "field")
      } else {
        cli::cli_abort(
          c("Column {.field field} not found in works table.",
            "i" = "For {.val manual} classification, add a {.field field} column to {.code corpus$works}."),
          call = call
        )
      }
    }
  )
}

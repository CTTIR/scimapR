#' Link corpus works to clinical trials
#'
#' @description
#' Identify works in the corpus that are linked to clinical trials
#' based on PMIDs or DOIs.
#'
#' @param corpus An `sm_corpus`.
#' @param ... Additional arguments (currently unused).
#' @param call Caller environment.
#'
#' @return A tibble with `work_id` and trial-related information.
#'
#' @examples
#' corpus <- sm_example_corpus()
#' sm_field_clinical_trials(corpus)
#'
#' @family field-helpers
#' @export
sm_field_clinical_trials <- function(corpus, ...,
                                     call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  trials <- corpus$works %>%
    dplyr::filter(.data$type %in% c("clinical-trial", "randomized-controlled-trial")) %>%
    dplyr::select("work_id", "doi", "title", "year", "pmid")

  if (nrow(trials) == 0) {
    cli::cli_inform(c("i" = "No clinical trials identified in corpus."))
  }

  trials
}

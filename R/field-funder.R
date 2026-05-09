#' Extract funding information
#'
#' @description
#' Summarise funding sources from corpus metadata.
#'
#' @param corpus An `sm_corpus`.
#' @param source Data source for funding info.
#' @param call Caller environment.
#'
#' @return A tibble of funders with counts.
#'
#' @family field-helpers
#' @export
sm_field_funder <- function(corpus,
                            source = c("crossref", "openalex"),
                            call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  source <- match.arg(source)

  cli::cli_inform(c(
    "i" = "Funding data requires enrichment. Use {.fn sm_enrich_concepts} or fetch from {source}."
  ))

  tibble::tibble(
    funder = character(),
    doi_prefix = character(),
    country = character(),
    n_works = integer()
  )
}

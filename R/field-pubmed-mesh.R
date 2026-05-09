#' Extract MeSH terms from corpus
#'
#' @description
#' Summarise MeSH (Medical Subject Headings) terms from the concepts table.
#'
#' @param corpus An `sm_corpus`.
#' @param call Caller environment.
#'
#' @return A tibble with `mesh_term`, `count`, and `proportion`.
#'
#' @family field-helpers
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_field_pubmed_mesh(corpus)
sm_field_pubmed_mesh <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  mesh <- corpus$concepts %>%
    dplyr::filter(.data$vocabulary == "mesh")

  if (nrow(mesh) == 0) {
    cli::cli_inform(c("i" = "No MeSH terms found. Enrich with {.fn sm_enrich_concepts}."))
    return(tibble::tibble(
      mesh_term = character(),
      count = integer(),
      proportion = double()
    ))
  }

  n_works <- nrow(corpus$works)

  mesh %>%
    dplyr::count(.data$concept_name, name = "count", sort = TRUE) %>%
    dplyr::rename(mesh_term = "concept_name") %>%
    dplyr::mutate(proportion = .data$count / n_works)
}

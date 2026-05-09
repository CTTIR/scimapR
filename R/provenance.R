#' Get corpus provenance
#'
#' @description
#' Returns the full provenance table from a corpus, documenting the data
#' lineage of every work: where it was fetched from, when, with which query,
#' and which version of scimapR performed the ingestion.
#'
#' @param corpus An `sm_corpus` object.
#'
#' @return A tibble with columns `work_id`, `source`, `source_id_external`,
#'   `fetch_date`, `query`, `engine`, `scimapR_version`, and `prompt_hash`.
#'
#' @family reproducibility
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_provenance(corpus)
sm_provenance <- function(corpus) {
  .check_sm_corpus(corpus)

  corpus$provenance
}

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
#'   `fetch_date`, `query`, `engine`, `scimapR_version`, and `prompt_hash`,
#'   and the optional column `kind` (the kind of step, such as
#'   `"enrichment"` for [sm_enrich_openalex_impact()]; `NA` for rows that
#'   do not record one).
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

#' The kind of step behind each provenance row
#'
#' `"api_query"` (a search or file read, which [sm_rebuild_from_cert()]
#' replays), `"enrichment"` (a step that added fields to works already in
#' the corpus), `"refresh"` ([sm_refresh()]) or `"manual"` (synthetic and
#' hand-made records). A row's own `kind` wins; rows without one get the
#' kind of their source label.
#'
#' @param source Provenance source labels.
#' @param kind `NULL`, or the recorded kinds (`NA` where none).
#' @return A character vector along `source`.
#' @noRd
.provenance_kind <- function(source, kind = NULL) {
  source <- as.character(source)
  out <- rep("api_query", length(source))
  out[source %in% c("synthetic", "manual")] <- "manual"
  out[grepl("_refresh$", source)] <- "refresh"
  out[source %in% .enrichment_sources] <- "enrichment"
  if (!is.null(kind)) {
    kind <- as.character(kind)
    given <- !is.na(kind) & nzchar(kind)
    out[given] <- kind[given]
  }
  out
}

#' Provenance source labels of enrichment steps
#' @noRd
.enrichment_sources <- "openalex_impact"

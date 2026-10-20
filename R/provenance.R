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
#'   and the optional columns `kind` (the kind of step: `"api_query"`,
#'   `"file"`, `"enrichment"`, `"refresh"` or `"manual"`, see
#'   [sm_certificate()]; `NA` for rows that do not record one), `filter` and
#'   `n_max` (the filter and the maximum number of works of a search, which
#'   [sm_rebuild_from_cert()] uses to replay it). File readers record the
#'   file in `query` relative to the working directory when it lies below
#'   it, else by its name.
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
#' `"api_query"` (a search of a bibliographic API, which
#' [sm_rebuild_from_cert()] can replay), `"file"` (records read from a local
#' file, or imported from data read from one), `"enrichment"` (a step that
#' added fields to works already in the corpus), `"refresh"` ([sm_refresh()])
#' or `"manual"` (synthetic and hand-made records). A row's own `kind` wins.
#' Rows without one, as written before kinds were recorded, get the kind of
#' their source label, their query and their engine: file formats and the
#' bibliometrix engine are files, an OpenAlex or PubMed query that ends in a
#' file extension is a file, and the placeholder queries of the enrichers
#' (`"enrich_..."`) are enrichments.
#'
#' @param source Provenance source labels.
#' @param kind `NULL`, or the recorded kinds (`NA` where none).
#' @param query,engine `NULL`, or the queries and engines of the rows.
#' @return A character vector along `source`.
#' @noRd
.provenance_kind <- function(source, kind = NULL, query = NULL,
                             engine = NULL) {
  source <- as.character(source)
  n <- length(source)
  query <- if (is.null(query)) rep(NA_character_, n) else as.character(query)
  engine <- if (is.null(engine)) rep(NA_character_, n) else
    as.character(engine)

  out <- rep("api_query", n)
  file_query <- !is.na(query) &
    grepl(.file_query_pattern, query, ignore.case = TRUE)
  out[source %in% .file_sources | engine %in% "bibliometrix" |
        (source %in% .replay_sources & file_query)] <- "file"
  out[!is.na(query) & startsWith(query, "enrich_")] <- "enrichment"
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

#' Provenance source labels of the file readers
#' @noRd
.file_sources <- c("wos", "scopus", "lens", "dimensions", "ris", "bibtex",
                   "endnote", "zotero", "cochrane", "bibliometrix-import")

#' Sources whose searches sm_rebuild_from_cert() replays
#' @noRd
.replay_sources <- c("openalex", "pubmed", "crossref")

#' Queries that name a file (older file reads of OpenAlex and PubMed data)
#' @noRd
.file_query_pattern <-
  "\\.(json|jsonl|ndjson|xml|txt|csv|tsv|ris|bib|nbib|ciw|xlsx?|gz|zip)$"

#' Record a search in the provenance of the corpus it fetched
#'
#' Adds the columns `kind` (`"api_query"`), `filter` and `n_max`, which
#' [sm_rebuild_from_cert()] needs to replay the search, to every row.
#' @noRd
.record_request <- function(corpus, filter = NULL, n_max = NULL) {
  prov <- corpus$provenance
  n <- nrow(prov)
  given <- length(filter) == 1L && !is.na(filter) && nzchar(filter)
  prov$kind <- rep_len("api_query", n)
  prov$filter <- rep_len(if (given) as.character(filter) else NA_character_,
                         n)
  prov$n_max <- rep_len(as.integer(n_max %||% NA_integer_), n)
  corpus$provenance <- prov
  corpus
}

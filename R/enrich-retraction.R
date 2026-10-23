#' Enrich corpus with retraction data
#'
#' @description
#' Check works in the corpus against the
#' [Retraction Watch](https://retractionwatch.com/) database (via the
#' Crossref update notices and OpenAlex) to identify
#' retracted publications.
#'
#' Updates the `is_retracted` and `retraction_date` columns in the
#' `works` table.
#'
#' This enricher is idempotent: re-running it updates existing retraction
#' data rather than duplicating it.
#'
#' @param corpus An `sm_corpus` object.
#' @param verbose Print progress messages?
#' @param api_key OpenAlex API key, sent in the authorization header.
#' @param mailto Contact address sent only to Crossref.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `is_retracted` and
#'   `retraction_date` columns in the `works` table, plus new provenance
#'   rows for checked works only. Failed requests warn; when no work could
#'   be checked they error without changing the corpus. Missing records are
#'   reported separately. Existing retraction flags are never cleared.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_retraction(corpus)
#' }
sm_enrich_retraction <- function(corpus, verbose = TRUE,
                                 api_key = Sys.getenv("OPENALEX_API_KEY"),
                                 mailto = Sys.getenv("SCIMAPR_MAILTO"),
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_corpus_unlocked(corpus, call = call)
  dois <- .normalize_doi(corpus$works$doi)
  has_doi <- !is.na(dois) & nzchar(dois)
  if (!any(has_doi)) {
    .sm_verbose("No DOIs in corpus; skipping retraction check.", verbose)
    return(corpus)
  }
  targets <- unique(dois[has_doi])
  oa <- .openalex_lookup(targets, select = "doi,is_retracted",
                         api_key = api_key, call = call)
  checked <- vapply(oa$records, function(x) x$doi %||% NA_character_,
                    character(1))
  checked <- intersect(targets, checked)
  if (length(oa$failed) && !length(checked)) {
    cli::cli_abort("Retraction check failed: no work could be checked.",
                   class = "scimapR_retraction_failed", parent = oa$condition,
                   call = call)
  }
  flagged <- vapply(oa$records, function(x) {
    if (isTRUE(x$is_retracted)) x$doi %||% NA_character_ else NA_character_
  }, character(1))
  cr <- .crossref_lookup(targets, filter_name = "updates", rows = 100L,
                         mailto = mailto, call = call)
  for (notice in cr$records) {
    for (update in notice[["update-to"]] %||% list()) {
      if (tolower(update$type %||% "") == "retraction") {
        flagged <- c(flagged, .normalize_doi(update$DOI %||% NA_character_))
      }
    }
  }
  flagged <- intersect(targets, flagged)
  completed <- union(checked, flagged)
  failed <- union(oa$failed, cr$failed)
  condition <- oa$condition %||% cr$condition
  if (length(failed) && !length(completed)) {
    cli::cli_abort("Retraction check failed: no work could be checked.",
                   class = "scimapR_retraction_failed", parent = condition,
                   call = call)
  }
  corpus$works$is_retracted[dois %in% flagged] <- TRUE
  rows <- which(dois %in% completed)
  if (length(rows)) {
    prov <- .make_provenance_rows(
      corpus$works$work_id[rows], "retraction_check", dois[rows],
      "enrich_retraction", "native", kind = "enrichment"
    )
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, prov)
  }
  unchecked <- corpus$works$work_id[dois %in% failed]
  n_unchecked <- length(unchecked)
  if (n_unchecked) {
    message <- sprintf("Retraction lookups left %d works not fully checked.",
                       n_unchecked)
    .sm_warn_unchecked(unchecked, condition, "scimapR_retraction_unchecked",
                       message, call = call, key_setting = "OPENALEX_API_KEY")
  }
  n_found <- sum(dois %in% flagged)
  n_checked <- length(rows)
  n_not_found <- sum(has_doi & !dois %in% union(checked, oa$failed))
  .sm_verbose(sprintf(
    "%d retracted of %d checked; %d not found in OpenAlex; %d not checked.",
    n_found, n_checked, n_not_found, n_unchecked
  ), verbose)
  corpus
}

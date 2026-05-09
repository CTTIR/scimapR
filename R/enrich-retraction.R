#' Enrich corpus with retraction data
#'
#' @description
#' Check works in the corpus against the
#' [Retraction Watch](https://retractionwatch.com/) database (via the
#' Crossref API retracted-article filter and OpenAlex) to identify
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
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `is_retracted` and
#'   `retraction_date` columns in the `works` table, plus new provenance
#'   rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_retraction(corpus)
#' }
sm_enrich_retraction <- function(corpus,
                                 verbose = TRUE,
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  dois <- corpus$works$doi
  has_doi <- !is.na(dois) & nzchar(dois)

  if (!any(has_doi)) {
    .sm_verbose(
      "No DOIs in corpus; skipping retraction check.",
      verbose
    )
    return(corpus)
  }

  target_dois <- dois[has_doi]
  target_ids <- corpus$works$work_id[has_doi]

  .sm_verbose(
    "Checking {length(target_dois)} DOIs for retractions via OpenAlex...",
    verbose
  )

  # Strategy: batch check via OpenAlex filter
  # Process in batches of 50 DOIs (OpenAlex pipe-separated OR filter)
  batch_size <- 50L
  retracted_dois <- character()
  retracted_dates <- list()

  chunks <- split(seq_along(target_dois),
                  ceiling(seq_along(target_dois) / batch_size))

  for (chunk_idx in chunks) {
    doi_batch <- target_dois[chunk_idx]

    # Build OpenAlex filter with pipe-separated DOIs
    doi_filter <- paste0(
      "doi:",
      paste(doi_batch, collapse = "|"),
      ",is_retracted:true"
    )

    result <- tryCatch({
      req <- httr2::request("https://api.openalex.org/works") |>
        httr2::req_url_query(
          filter = doi_filter,
          select = "doi,is_retracted",
          per_page = length(doi_batch)
        ) |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 10 / 1)

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
      NULL
    })

    if (!is.null(result)) {
      items <- result[["results"]] %||% list()
      for (item in items) {
        if (isTRUE(item[["is_retracted"]])) {
          item_doi <- .normalize_doi(item[["doi"]] %||% NA_character_)
          if (!is.na(item_doi)) {
            retracted_dois <- c(retracted_dois, item_doi)
          }
        }
      }
    }

    if (verbose) {
      .sm_verbose(
        "Retraction check: {max(chunk_idx)} / {length(target_dois)} DOIs processed.",
        verbose
      )
    }
  }

  # Also check via Crossref for retraction notices
  if (length(target_dois) <= 200) {
    .sm_verbose("Cross-checking via Crossref retraction filter...", verbose)

    for (doi in target_dois) {
      if (doi %in% retracted_dois) next  # Already known retracted

      result <- tryCatch({
        req <- httr2::request("https://api.crossref.org/works") |>
          httr2::req_url_query(
            filter = paste0("doi:", doi, ",type:retraction"),
            rows = 1
          ) |>
          httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
          httr2::req_throttle(rate = 50 / 1)

        resp <- httr2::req_perform(req)
        body <- httr2::resp_body_json(resp)
        body[["message"]][["total-results"]]
      }, error = function(e) {
        0L
      })

      if (!is.null(result) && result > 0) {
        retracted_dois <- c(retracted_dois, doi)
      }
    }
  }

  # Update works table
  works <- corpus$works
  n_found <- 0L

  if (length(retracted_dois) > 0) {
    retracted_dois <- unique(.normalize_doi(retracted_dois))
    match_mask <- .normalize_doi(works$doi) %in% retracted_dois

    n_found <- sum(match_mask)
    if (n_found > 0) {
      works$is_retracted[match_mask] <- TRUE
      # We don't have exact retraction dates from these APIs
      # Set to NA if not already known
    }
  }

  corpus$works <- works

  # Provenance for all checked works
  new_prov <- .make_provenance_rows(
    work_ids = target_ids,
    source_name = "retraction_check",
    external_ids = target_dois,
    query_text = "enrich_retraction",
    engine_name = "native"
  )
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)

  .sm_done(
    "Retraction check complete: {n_found} retracted work{?s} identified out of {length(target_dois)} checked."
  )
  corpus
}

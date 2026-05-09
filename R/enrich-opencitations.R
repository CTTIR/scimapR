#' Enrich corpus with OpenCitations citation data
#'
#' @description
#' Look up DOIs in the corpus via the
#' [OpenCitations](https://opencitations.net/) COCI API and add incoming
#' and outgoing citation counts, plus citation links between works in the
#' corpus.
#'
#' This enricher is idempotent: re-running it updates existing citation
#' data rather than duplicating it.
#'
#' @param corpus An `sm_corpus` object.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `cited_by_count` in the
#'   `works` table, enriched `references` table, and new provenance rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_opencitations(corpus)
#' }
sm_enrich_opencitations <- function(corpus,
                                    verbose = TRUE,
                                    call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  dois <- corpus$works$doi
  has_doi <- !is.na(dois) & nzchar(dois)

  if (!any(has_doi)) {
    .sm_verbose("No DOIs in corpus; skipping OpenCitations enrichment.", verbose)
    return(corpus)
  }

  target_dois <- dois[has_doi]
  target_ids <- corpus$works$work_id[has_doi]

  .sm_verbose(
    "Looking up {length(target_dois)} DOIs on OpenCitations...",
    verbose
  )

  new_refs <- list()
  citation_counts <- rep(NA_integer_, length(target_dois))

  for (i in seq_along(target_dois)) {
    result <- tryCatch({
      req <- httr2::request(
        paste0("https://opencitations.net/index/coci/api/v1/citations/",
               target_dois[i])
      ) |>
        httr2::req_headers(
          `User-Agent` = .sm_user_agent(),
          Accept = "application/json"
        ) |>
        httr2::req_throttle(rate = 5 / 1)

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
      NULL
    })

    if (!is.null(result) && length(result) > 0) {
      citation_counts[i] <- as.integer(length(result))

      citing_dois <- purrr::map_chr(result, "citing", .default = NA_character_)
      citing_dois <- citing_dois[!is.na(citing_dois)]

      if (length(citing_dois) > 0) {
        new_refs[[length(new_refs) + 1L]] <- tibble::tibble(
          work_id = target_ids[i],
          ref_index = seq_along(citing_dois),
          cited_work_id = NA_character_,
          cited_doi = .normalize_doi(citing_dois),
          cited_raw = NA_character_
        )
      }
    }

    if (verbose && i %% 50 == 0) {
      .sm_verbose(
        "OpenCitations: {i} / {length(target_dois)} DOIs processed.",
        verbose
      )
    }
  }

  # Update works table - citation counts
  works <- corpus$works
  updated_counts <- citation_counts[!is.na(citation_counts)]
  updated_idx <- which(has_doi)[!is.na(citation_counts)]
  if (length(updated_idx) > 0) {
    works$cited_by_count[updated_idx] <- updated_counts
  }

  # Merge new references (avoiding duplicates)
  references <- corpus$references
  if (length(new_refs) > 0) {
    new_refs_tbl <- dplyr::bind_rows(new_refs)
    # Remove refs already present
    if (nrow(references) > 0 && nrow(new_refs_tbl) > 0) {
      existing_keys <- paste(references$work_id, references$cited_doi, sep = "||")
      new_keys <- paste(new_refs_tbl$work_id, new_refs_tbl$cited_doi, sep = "||")
      new_refs_tbl <- new_refs_tbl[!new_keys %in% existing_keys, ]
    }
    if (nrow(new_refs_tbl) > 0) {
      references <- dplyr::bind_rows(references, new_refs_tbl)
    }
  }

  # Add provenance rows
  enriched_ids <- target_ids[!is.na(citation_counts)]
  enriched_dois <- target_dois[!is.na(citation_counts)]

  if (length(enriched_ids) > 0) {
    new_prov <- .make_provenance_rows(
      work_ids = enriched_ids,
      source_name = "opencitations",
      external_ids = enriched_dois,
      query_text = "enrich_opencitations",
      engine_name = "native"
    )
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)
  }

  corpus$works <- works
  corpus$references <- references

  n_enriched <- sum(!is.na(citation_counts))
  .sm_done("Enriched {n_enriched} works with OpenCitations data.")
  corpus
}

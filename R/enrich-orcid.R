#' Enrich corpus authors with ORCID data
#'
#' @description
#' Look up authors in the corpus who have ORCID identifiers and fetch
#' additional profile information from the
#' [ORCID](https://orcid.org/) Public API. Updates the `authors` table
#' with display name alternatives and the `authorships` table with
#' affiliation data.
#'
#' This enricher is idempotent: re-running it updates existing ORCID data
#' rather than duplicating it.
#'
#' @param corpus An `sm_corpus` object.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `authors` and `authorships`
#'   tables, plus new provenance rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_orcid(corpus)
#' }
sm_enrich_orcid <- function(corpus,
                            verbose = TRUE,
                            call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  orcids <- corpus$authors$orcid
  has_orcid <- !is.na(orcids) & nzchar(orcids)

  if (!any(has_orcid)) {
    .sm_verbose("No ORCIDs in corpus authors; skipping ORCID enrichment.", verbose)
    return(corpus)
  }

  target_orcids <- orcids[has_orcid]
  target_author_ids <- corpus$authors$author_id[has_orcid]

  # Clean ORCID format
  target_orcids <- sub("^https?://orcid\\.org/", "", target_orcids)

  .sm_verbose(
    "Enriching {length(target_orcids)} authors from ORCID...",
    verbose
  )

  authors <- corpus$authors

  for (i in seq_along(target_orcids)) {
    result <- tryCatch({
      req <- httr2::request(
        paste0("https://pub.orcid.org/v3.0/", target_orcids[i], "/person")
      ) |>
        httr2::req_headers(
          Accept = "application/json",
          `User-Agent` = .sm_user_agent()
        ) |>
        httr2::req_throttle(rate = 5 / 1)

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
      NULL
    })

    if (is.null(result)) next

    auth_idx <- which(authors$author_id == target_author_ids[i])
    if (length(auth_idx) == 0) next

    # Update display name if it's richer than what we have
    given <- result[["name"]][["given-names"]][["value"]]
    family <- result[["name"]][["family-name"]][["value"]]
    if (!is.null(given) && !is.null(family)) {
      full_name <- paste(given, family)
      current_name <- authors$display_name[auth_idx]
      if (is.na(current_name) || nchar(full_name) > nchar(current_name)) {
        authors$display_name[auth_idx] <- full_name
      }
      # Add old name as alternative
      if (!is.na(current_name) && current_name != full_name) {
        alts <- authors$display_name_alternatives[[auth_idx]]
        if (!current_name %in% alts) {
          authors$display_name_alternatives[[auth_idx]] <- c(alts, current_name)
        }
      }
    }

    # Also get other names
    other_names <- result[["other-names"]][["other-name"]]
    if (length(other_names) > 0) {
      other_vals <- purrr::map_chr(other_names, \(x) {
        x[["content"]] %||% NA_character_
      })
      other_vals <- other_vals[!is.na(other_vals)]
      if (length(other_vals) > 0) {
        existing_alts <- authors$display_name_alternatives[[auth_idx]]
        new_alts <- setdiff(other_vals, existing_alts)
        authors$display_name_alternatives[[auth_idx]] <- c(existing_alts, new_alts)
      }
    }

    if (verbose && i %% 50 == 0) {
      .sm_verbose("ORCID: {i} / {length(target_orcids)} authors processed.", verbose)
    }
  }

  corpus$authors <- authors

  # Provenance (one row per enriched author's works)
  enriched_author_ids <- target_author_ids
  enriched_work_ids <- corpus$authorships |>
    dplyr::filter(.data$author_id %in% enriched_author_ids) |>
    dplyr::pull(.data$work_id) |>
    unique()

  if (length(enriched_work_ids) > 0) {
    new_prov <- .make_provenance_rows(
      work_ids = enriched_work_ids,
      source_name = "orcid",
      external_ids = NA_character_,
      query_text = "enrich_orcid",
      engine_name = "native"
    )
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)
  }

  .sm_done("Enriched {length(target_orcids)} authors with ORCID data.")
  corpus
}

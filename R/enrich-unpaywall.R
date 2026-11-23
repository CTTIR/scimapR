#' Enrich corpus with Unpaywall open-access data
#'
#' @description
#' Look up DOIs in the corpus via the
#' [Unpaywall](https://unpaywall.org/) API and add open-access status
#' and best OA URL to the `works` table.
#'
#' This enricher is idempotent: re-running it updates existing OA data
#' rather than duplicating it. Requires a `mailto` address for API access.
#'
#' @param corpus An `sm_corpus` object.
#' @param mailto Email address for the Unpaywall API. Read from
#'   `SCIMAPR_MAILTO` env var by default.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `oa_status` and `oa_url`
#'   columns in the `works` table, plus provenance rows for the works
#'   Unpaywall answered for ("not found" included). Works whose lookup
#'   failed for another reason (rejected address, rate limit, server or
#'   network error) keep their previous values and are reported in a
#'   warning of class `scimapR_unpaywall_unchecked` with their `work_ids`.
#'
#' @family enrichers
#' @export
#' @examples
#' \donttest{
#' # Queries the Unpaywall web API; runs only when a contact e-mail address
#' # is set in the SCIMAPR_MAILTO environment variable.
#' if (nzchar(Sys.getenv("SCIMAPR_MAILTO")) &&
#'     requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
#'   corpus <- sm_corpus(works = tibble::tibble(
#'     work_id = "W1",
#'     doi = "10.1371/journal.pbio.1002541"
#'   ))
#'   enriched <- try(sm_enrich_unpaywall(corpus))
#'   if (is_sm_corpus(enriched)) enriched$works[, c("oa_status", "oa_url")]
#' }
#' }
sm_enrich_unpaywall <- function(corpus,
                                mailto = Sys.getenv("SCIMAPR_MAILTO"),
                                verbose = TRUE,
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_corpus_unlocked(corpus, call = call)

  if (!nzchar(mailto)) {
    cli::cli_abort(
      c("A mailto address is required for the Unpaywall API.",
        "i" = "Set the {.envvar SCIMAPR_MAILTO} environment variable."),
      call = call
    )
  }

  dois <- corpus$works$doi
  has_doi <- !is.na(dois) & nzchar(dois)

  if (!any(has_doi)) {
    .sm_verbose("No DOIs in corpus; skipping Unpaywall enrichment.", verbose)
    return(corpus)
  }

  target_dois <- dois[has_doi]
  target_ids <- corpus$works$work_id[has_doi]

  .sm_verbose(
    "Looking up {length(target_dois)} DOIs on Unpaywall...",
    verbose
  )

  oa_status <- rep(NA_character_, length(target_dois))
  oa_url <- rep(NA_character_, length(target_dois))
  failed <- rep(FALSE, length(target_dois))

  for (i in seq_along(target_dois)) {
    result <- tryCatch({
      req <- httr2::request(
        paste0("https://api.unpaywall.org/v2/", .doi_url_path(target_dois[i]))
      ) |>
        httr2::req_url_query(email = mailto) |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 10 / 1)

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
      # A 404 means Unpaywall has no record for the DOI, which is a normal
      # answer; anything else leaves the work unchecked.
      if (!inherits(e, "httr2_http_404")) failed[i] <<- TRUE
      NULL
    })

    if (!is.null(result)) {
      oa_status[i] <- result[["oa_status"]] %||% NA_character_
      best_loc <- result[["best_oa_location"]]
      oa_url[i] <- if (!is.null(best_loc)) {
        best_loc[["url_for_pdf"]] %||%
          best_loc[["url_for_landing_page"]] %||%
          best_loc[["url"]] %||%
          NA_character_
      } else {
        NA_character_
      }
    }

    if (verbose && i %% 50 == 0) {
      .sm_verbose("Unpaywall: {i} / {length(target_dois)} DOIs processed.", verbose)
    }
  }

  # Update works table
  works <- corpus$works
  works$oa_status[has_doi] <- ifelse(
    is.na(oa_status), works$oa_status[has_doi], oa_status
  )

  # Add oa_url column if not present
  if (!"oa_url" %in% names(works)) {
    works$oa_url <- NA_character_
  }
  # A failed lookup keeps the URL of an earlier run; an answer replaces it,
  # also with NA when Unpaywall no longer knows an open copy.
  answered <- which(has_doi)[!failed]
  works$oa_url[answered] <- oa_url[!failed]

  # Add provenance rows for the works Unpaywall answered for
  new_prov <- .make_provenance_rows(
    work_ids = target_ids[!failed],
    source_name = "unpaywall",
    external_ids = target_dois[!failed],
    query_text = "enrich_unpaywall",
    engine_name = "native",
    kind = "enrichment"
  )

  corpus$works <- works
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)

  if (any(failed)) {
    cli::cli_warn(
      c(sprintf("Unpaywall lookups failed for %d of %d works.",
                sum(failed), length(target_dois)),
        "i" = "Their open-access data were left unchanged."),
      class = "scimapR_unpaywall_unchecked",
      work_ids = target_ids[failed], call = call
    )
  }

  .sm_done("Enriched {sum(!is.na(oa_status))} works with Unpaywall data.",
           verbose = verbose)
  corpus
}

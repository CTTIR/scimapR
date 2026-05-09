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
#'   columns in the `works` table, plus new provenance rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_unpaywall(corpus)
#' }
sm_enrich_unpaywall <- function(corpus,
                                mailto = Sys.getenv("SCIMAPR_MAILTO"),
                                verbose = TRUE,
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

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

  for (i in seq_along(target_dois)) {
    result <- tryCatch({
      req <- httr2::request(
        paste0("https://api.unpaywall.org/v2/", target_dois[i])
      ) |>
        httr2::req_url_query(email = mailto) |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 10 / 1)

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
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
  works$oa_url[has_doi] <- oa_url

  # Add provenance rows
  new_prov <- .make_provenance_rows(
    work_ids = target_ids,
    source_name = "unpaywall",
    external_ids = target_dois,
    query_text = "enrich_unpaywall",
    engine_name = "native"
  )

  corpus$works <- works
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)

  .sm_done("Enriched {sum(!is.na(oa_status))} works with Unpaywall data.")
  corpus
}

#' Fetch works from ORCID
#'
#' @description
#' Retrieve works associated with an [ORCID](https://orcid.org/) identifier
#' via the ORCID Public API and return the results as an `sm_corpus`.
#'
#' This fetches work summaries from the public API endpoint
#' `https://pub.orcid.org/v3.0/{orcid}/works`.
#'
#' @param orcid An ORCID identifier (e.g., `"0000-0001-8006-9742"`).
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object.
#'
#' @family fetchers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_fetch_orcid("0000-0001-8006-9742")
#' print(corpus)
#' }
sm_fetch_orcid <- function(orcid,
                           verbose = TRUE,
                           call = rlang::caller_env()) {
  .check_string(orcid, call = call)

  # Validate ORCID format
  orcid <- trimws(orcid)
  orcid <- sub("^https?://orcid\\.org/", "", orcid)
  if (!grepl("^\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]$", orcid)) {
    cli::cli_abort(
      "{.arg orcid} must be a valid ORCID (e.g., {.val 0000-0001-8006-9742}).",
      call = call
    )
  }

  .sm_verbose("Fetching works for ORCID {.val {orcid}}...", verbose)

  req <- httr2::request(
    paste0("https://pub.orcid.org/v3.0/", orcid, "/works")
  ) |>
    httr2::req_headers(
      Accept = "application/json",
      `User-Agent` = .sm_user_agent()
    ) |>
    httr2::req_throttle(rate = 5 / 1)

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      cli::cli_abort(
        c("ORCID API request failed for {.val {orcid}}.",
          "i" = conditionMessage(e)),
        call = call
      )
    }
  )

  body <- httr2::resp_body_json(resp)
  groups <- body[["group"]] %||% list()

  if (length(groups) == 0L) {
    .sm_verbose("No works found for ORCID {.val {orcid}}.", verbose)
    return(.empty_corpus_with_provenance("orcid", orcid, "native"))
  }

  .parse_orcid_results(groups, orcid, verbose, call)
}

# ---- internal helpers ----

#' @noRd
.parse_orcid_results <- function(groups, orcid, verbose, call) {
  # Each group has work-summary list; take the first summary per group
  summaries <- purrr::map(groups, \(g) {
    ws <- g[["work-summary"]]
    if (length(ws) == 0) return(NULL)
    ws[[1]]
  })
  summaries <- purrr::compact(summaries)

  n <- length(summaries)
  if (n == 0L) {
    return(.empty_corpus_with_provenance("orcid", orcid, "native"))
  }

  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = purrr::map_chr(summaries, \(s) {
      ids <- s[["external-ids"]][["external-id"]] %||% list()
      doi_entry <- purrr::keep(ids, \(x) {
        identical(x[["external-id-type"]], "doi")
      })
      if (length(doi_entry) == 0) return(NA_character_)
      .normalize_doi(doi_entry[[1]][["external-id-value"]] %||% NA_character_)
    }),
    title = purrr::map_chr(summaries, \(s) {
      t <- s[["title"]][["title"]][["value"]]
      t %||% NA_character_
    }),
    abstract = NA_character_,
    year = as.integer(purrr::map_chr(summaries, \(s) {
      y <- s[["publication-date"]][["year"]][["value"]]
      y %||% NA_character_
    })),
    type = purrr::map_chr(summaries, \(s) {
      t <- s[["type"]]
      if (is.null(t)) NA_character_ else tolower(gsub("_", "-", t))
    }),
    source_id = purrr::map_chr(summaries, \(s) {
      jt <- s[["journal-title"]][["value"]]
      jt %||% NA_character_
    }),
    cited_by_count = NA_integer_,
    oa_status = NA_character_,
    language = NA_character_,
    pmid = purrr::map_chr(summaries, \(s) {
      ids <- s[["external-ids"]][["external-id"]] %||% list()
      pmid_entry <- purrr::keep(ids, \(x) {
        identical(x[["external-id-type"]], "pmid")
      })
      if (length(pmid_entry) == 0) return(NA_character_)
      pmid_entry[[1]][["external-id-value"]] %||% NA_character_
    }),
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # Create a single author entry for the ORCID holder
  authors <- tibble::tibble(
    author_id = "A000000001",
    orcid = orcid,
    display_name = NA_character_,
    display_name_alternatives = list(character()),
    inferred_gender = NA_character_,
    gender_confidence = NA_real_,
    gender_method = NA_character_
  )

  authorships <- tibble::tibble(
    work_id = work_ids,
    author_id = "A000000001",
    position = 1L,
    is_corresponding = TRUE,
    institution_id = NA_character_,
    raw_affiliation = NA_character_,
    country_code = NA_character_
  )

  # ---- provenance ----
  orcid_put_codes <- purrr::map_chr(summaries, \(s) {
    pc <- s[["put-code"]]
    if (is.null(pc)) NA_character_ else as.character(pc)
  })

  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = "orcid",
    external_ids = orcid_put_codes,
    query_text = orcid,
    engine_name = "native"
  )

  .sm_done("Parsed {n} ORCID works into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = authors,
    authorships = authorships,
    provenance = provenance
  )
}

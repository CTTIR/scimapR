#' Enrich corpus institutions with ROR data
#'
#' @description
#' Look up institutions in the corpus via the
#' [Research Organization Registry (ROR)](https://ror.org/) API and enrich
#' the `institutions` table with standardized metadata including country,
#' region, type, and income tier.
#'
#' Works by matching raw affiliation strings against the ROR affiliation
#' matching API, or by directly resolving existing ROR identifiers.
#'
#' This enricher is idempotent: re-running it updates existing ROR data
#' rather than duplicating it.
#'
#' @param corpus An `sm_corpus` object.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `institutions` and
#'   `authorships` tables, plus new provenance rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_ror(corpus)
#' }
sm_enrich_ror <- function(corpus,
                          verbose = TRUE,
                          call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  # Get unique raw affiliations that don't yet have institution_ids
  aff_data <- corpus$authorships |>
    dplyr::filter(
      !is.na(.data$raw_affiliation),
      nzchar(.data$raw_affiliation),
      is.na(.data$institution_id) | !nzchar(.data$institution_id)
    ) |>
    dplyr::distinct(.data$raw_affiliation)

  if (nrow(aff_data) == 0) {
    .sm_verbose("No unresolved affiliations; skipping ROR enrichment.", verbose)
    return(corpus)
  }

  affiliations <- aff_data$raw_affiliation

  .sm_verbose(
    "Matching {length(affiliations)} affiliations against ROR...",
    verbose
  )

  ror_cache <- list()

  for (i in seq_along(affiliations)) {
    aff_str <- affiliations[i]

    result <- tryCatch({
      req <- httr2::request("https://api.ror.org/v2/organizations") |>
        httr2::req_url_query(affiliation = aff_str) |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 10 / 1)

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
      NULL
    })

    if (is.null(result)) next

    items <- result[["items"]] %||% list()
    if (length(items) == 0) next

    # Take the best match (highest score, chosen = TRUE)
    best <- NULL
    for (item in items) {
      if (isTRUE(item[["chosen"]])) {
        best <- item[["organization"]]
        break
      }
    }
    if (is.null(best) && length(items) > 0) {
      best <- items[[1]][["organization"]]
    }
    if (is.null(best)) next

    ror_id <- best[["id"]] %||% NA_character_

    if (!is.na(ror_id)) {
      # Extract country from locations
      locations <- best[["locations"]] %||% list()
      cc <- if (length(locations) > 0) {
        loc <- locations[[1]]
        geo <- loc[["geonames_details"]] %||% list()
        geo[["country_code"]] %||% NA_character_
      } else {
        NA_character_
      }

      # Extract name
      disp_name <- best[["name"]] %||% NA_character_

      # Extract type
      types <- best[["types"]] %||% list()
      org_type <- if (length(types) > 0) types[[1]] else NA_character_

      ror_cache[[aff_str]] <- list(
        institution_id = ror_id,
        ror = ror_id,
        display_name = disp_name,
        country_code = cc,
        region = NA_character_,
        income_tier = NA_character_,
        type = org_type
      )
    }

    if (verbose && i %% 50 == 0) {
      .sm_verbose("ROR: {i} / {length(affiliations)} affiliations processed.", verbose)
    }
  }

  if (length(ror_cache) == 0) {
    .sm_verbose("No ROR matches found.", verbose)
    return(corpus)
  }

  # Update institution table
  new_insts <- list()
  existing_inst_ids <- corpus$institutions$institution_id

  for (aff_str in names(ror_cache)) {
    info <- ror_cache[[aff_str]]
    if (!info$institution_id %in% existing_inst_ids) {
      new_insts[[length(new_insts) + 1L]] <- tibble::tibble(
        institution_id = info$institution_id,
        ror = info$ror,
        display_name = info$display_name,
        country_code = info$country_code,
        region = info$region,
        income_tier = info$income_tier,
        type = info$type
      )
      existing_inst_ids <- c(existing_inst_ids, info$institution_id)
    }
  }

  if (length(new_insts) > 0) {
    corpus$institutions <- dplyr::bind_rows(
      corpus$institutions,
      dplyr::bind_rows(new_insts)
    )
  }

  # Update authorships with resolved institution_ids and country codes
  authorships <- corpus$authorships
  for (j in seq_len(nrow(authorships))) {
    aff <- authorships$raw_affiliation[j]
    if (is.na(aff) || !nzchar(aff)) next
    if (!is.na(authorships$institution_id[j]) &&
        nzchar(authorships$institution_id[j])) next

    match_info <- ror_cache[[aff]]
    if (!is.null(match_info)) {
      authorships$institution_id[j] <- match_info$institution_id
      if (is.na(authorships$country_code[j])) {
        authorships$country_code[j] <- match_info$country_code
      }
    }
  }
  corpus$authorships <- authorships

  # Provenance
  affected_work_ids <- corpus$authorships |>
    dplyr::filter(.data$raw_affiliation %in% names(ror_cache)) |>
    dplyr::pull(.data$work_id) |>
    unique()

  if (length(affected_work_ids) > 0) {
    new_prov <- .make_provenance_rows(
      work_ids = affected_work_ids,
      source_name = "ror",
      external_ids = NA_character_,
      query_text = "enrich_ror",
      engine_name = "native"
    )
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)
  }

  .sm_done(
    "Resolved {length(ror_cache)} affiliations via ROR; added {length(new_insts)} new institutions."
  )
  corpus
}

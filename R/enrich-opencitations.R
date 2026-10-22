#' Enrich corpus with OpenCitations citation data
#'
#' @description
#' Look up DOIs using the
#' [OpenCitations Index API](https://api.opencitations.net/index/v2)
#' and add outgoing references. DOI and OpenAlex identifiers link these
#' references to works in the corpus. The separate incoming citation count
#' replaces `works$cited_by_count`.
#'
#' This enricher is idempotent: re-running it updates existing citation
#' data rather than duplicating it.
#'
#' @param corpus An `sm_corpus` object.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `cited_by_count` in the
#'   `works` table, outgoing `references` linked where possible, and new
#'   provenance rows for works with usable responses.
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
  .check_corpus_unlocked(corpus, call = call)

  dois <- .normalize_doi(corpus$works$doi)
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

  references <- corpus$references
  citation_counts <- rep(NA_integer_, length(target_dois))
  enriched <- rep(FALSE, length(target_dois))

  for (i in seq_along(target_dois)) {
    result <- .opencitations_request("references", target_dois[i])
    count <- .opencitations_request("citation-count", target_dois[i])
    citation_counts[i] <- .opencitations_count(count)
    valid_rows <- is.list(result) && length(result) > 0L &&
      all(vapply(result, function(row) {
        is.list(row) && is.character(row[["cited"]]) &&
          length(row[["cited"]]) == 1L
      }, logical(1)))
    enriched[i] <- valid_rows || !is.na(citation_counts[i])
    if (valid_rows) {
      cited <- vapply(result, function(row) row[["cited"]], character(1))
      add <- tibble::tibble(
        work_id = target_ids[i], ref_index = NA_integer_,
        cited_work_id = NA_character_,
        cited_doi = .normalize_doi(.opencitations_identifier(cited, "doi")),
        cited_raw = .openalex_short_id(
          .opencitations_identifier(cited, "openalex")
        )
      )
      add$.key <- .opencitations_reference_key(add)
      existing <- tibble::tibble(
        work_id = references$work_id,
        .key = .opencitations_reference_key(references)
      )
      add <- add |>
        dplyr::filter(!is.na(.data$.key)) |>
        dplyr::distinct(.data$work_id, .data$.key, .keep_all = TRUE) |>
        dplyr::anti_join(existing, by = c("work_id", ".key"),
                         na_matches = "never")
      add$.key <- NULL
      if (nrow(add) > 0L) {
        previous <- references$ref_index[references$work_id == target_ids[i]]
        add$ref_index <- max(c(0L, previous), na.rm = TRUE) + seq_len(nrow(add))
        references <- dplyr::bind_rows(references, add)
      }
    }
    if (verbose && i %% 50 == 0) {
      .sm_verbose("OpenCitations: {i} / {length(target_dois)} DOIs processed.",
                  verbose)
    }
  }

  works <- corpus$works
  updated <- !is.na(citation_counts)
  works$cited_by_count[which(has_doi)[updated]] <- citation_counts[updated]
  references <- .link_references(references, works)
  if (any(enriched)) {
    new_prov <- .make_provenance_rows(
      work_ids = target_ids[enriched], source_name = "opencitations",
      external_ids = target_dois[enriched], query_text = "enrich_opencitations",
      engine_name = "native", kind = "enrichment"
    )
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)
  }
  corpus$works <- works
  corpus$references <- references
  .sm_done("Enriched {sum(enriched)} works with OpenCitations data.")
  corpus
}

.opencitations_request <- function(endpoint, doi) {
  tryCatch({
    req <- httr2::request(paste0("https://api.opencitations.net/index/v2/",
                                 endpoint, "/doi:", doi)) |>
      httr2::req_headers(`User-Agent` = .sm_user_agent(),
                         Accept = "application/json") |>
      httr2::req_throttle(rate = 5 / 1)
    httr2::resp_body_json(httr2::req_perform(req))
  }, error = function(e) NULL)
}

.opencitations_identifier <- function(x, prefix) {
  x[is.na(x)] <- ""
  pattern <- paste0("(?i)(?:^|\\s)", prefix, ":[^\\s]+")
  m <- regexpr(pattern, x, perl = TRUE)
  out <- rep(NA_character_, length(x))
  out[m > 0L] <- sub(paste0("(?i)^", prefix, ":"), "",
                     trimws(regmatches(x, m)), perl = TRUE)
  out
}

.opencitations_reference_key <- function(refs) {
  if (nrow(refs) == 0L) return(character())
  doi <- .normalize_doi(refs[["cited_doi"]] %||% rep(NA_character_, nrow(refs)))
  oa <- .openalex_short_id(
    refs[["cited_raw"]] %||% rep(NA_character_, nrow(refs))
  )
  ifelse(!is.na(doi), paste0("doi:", doi),
         ifelse(!is.na(oa), paste0("openalex:", oa), NA_character_))
}

.opencitations_count <- function(result) {
  if (!is.list(result) || length(result) == 0L || !is.list(result[[1]])) {
    return(NA_integer_)
  }
  value <- result[[1]][["count"]]
  if (!is.atomic(value) || length(value) != 1L) return(NA_integer_)
  value <- suppressWarnings(as.numeric(value))
  if (!is.finite(value) || value < 0 || value != floor(value) ||
        value > .Machine$integer.max) return(NA_integer_)
  as.integer(value)
}

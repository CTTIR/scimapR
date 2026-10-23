#' Funding source audit
#'
#' @description
#' Audits the distribution of funding sources across works in a corpus.
#' Funding metadata is extracted from either Crossref `funder` fields or
#' OpenAlex `funders` and `awards` fields (also accepting legacy `grants`),
#' depending on the `source` parameter.
#'
#' The result includes funder counts, the proportion of works with known
#' funding, and a concentration analysis.
#'
#' @param corpus An `sm_corpus` object.
#' @param source Character. Where to look for funding data: `"crossref"`
#'   (uses DOIs to query Crossref funder metadata) or `"openalex"` (uses
#'   OpenAlex IDs, with DOI fallback).
#' @param api_key OpenAlex API key, sent in the authorization header.
#' @param mailto Contact address for Crossref requests.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_funding` S3 object containing:
#' \describe{
#'   \item{funders}{Tibble with columns `funder_name`, `funder_doi`,
#'     `n_works`, `pct` (percentage of checked works).}
#'   \item{coverage}{Proportion of checked works with at least one funder;
#'     `NA` if none could be checked, and 0 for an empty corpus.}
#'   \item{n_works_total}{Total number of works in corpus.}
#'   \item{n_works_funded}{Number of works with funding data.}
#'   \item{n_works_checked}{Works returned by the source.}
#'   \item{n_works_failed}{Works whose request failed; reported in a warning.}
#'   \item{n_works_no_id}{Works without an identifier for the chosen source.}
#'   \item{source}{The data source used.}
#' }
#'
#' @family audit
#' @export
#' @examples
#' # Works without a DOI need no Crossref lookup, so this runs offline and
#' # returns an empty audit.
#' corpus <- sm_example_corpus(n_works = 20, n_authors = 10)
#' corpus$works$doi <- NA_character_
#' funding <- sm_audit_funding(corpus, source = "crossref")
#' print(funding)
#' @examplesIf interactive()
#' # Live lookup: batched Crossref requests (the example DOIs are invented,
#' # so no funders are found).
#' corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
#' funding <- sm_audit_funding(corpus, source = "crossref")
#' print(funding)
sm_audit_funding <- function(corpus, source = c("crossref", "openalex"),
                             api_key = Sys.getenv("OPENALEX_API_KEY"),
                             mailto = Sys.getenv("SCIMAPR_MAILTO"),
                             call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  source <- match.arg(source)
  n_works_total <- nrow(corpus$works)
  if (!n_works_total) return(.empty_audit_funding(source))
  run <- if (source == "crossref") {
    .fetch_funding_crossref(corpus$works, mailto = mailto, call = call)
  } else {
    .fetch_funding_openalex(corpus$works, api_key = api_key, call = call)
  }
  identifiers <- if (source == "crossref") .normalize_doi(corpus$works$doi) else
    .openalex_lookup_keys(corpus$works, by = c("openalex_id", "doi"))$key
  n_no_id <- sum(is.na(identifiers) | !nzchar(identifiers))
  n_checked <- length(unique(run$checked))
  n_failed <- length(unique(run$failed))
  if (n_failed) {
    message <- sprintf(
      "Funding lookup failed for %d works, excluded from coverage.", n_failed
    )
    setting <- if (source == "openalex") "OPENALEX_API_KEY" else NULL
    .sm_warn_unchecked(
      run$failed, run$condition, "scimapR_funding_lookup_failed",
      message, call = call, key_setting = setting
    )
  }
  if (n_no_id == n_works_total) {
    cli::cli_inform("No funding data: works lack DOIs or identifiers.")
  } else if (!nrow(run$funders) && n_checked > 0L) {
    cli::cli_inform(
      "No funding data found via {.val {source}} for checked works."
    )
  }
  summary <- run$funders |>
    dplyr::group_by(.data$funder_name, .data$funder_doi) |>
    dplyr::summarise(n_works = dplyr::n_distinct(.data$work_id),
                     .groups = "drop") |>
    dplyr::mutate(pct = round(100 * .data$n_works / n_checked, 2)) |>
    dplyr::arrange(dplyr::desc(.data$n_works))
  n_funded <- dplyr::n_distinct(run$funders$work_id)
  structure(list(
    funders = summary, coverage = if (n_checked) round(n_funded / n_checked,
                                                       3) else
      NA_real_, n_works_total = n_works_total, n_works_funded = n_funded,
    n_works_checked = n_checked, n_works_failed = n_failed,
    n_works_no_id = n_no_id, source = source
  ), class = "sm_audit_funding")
}

.empty_audit_funding <- function(source = "crossref", n_works_total = 0L) {
  structure(list(
    funders = tibble::tibble(funder_name = character(),
                             funder_doi = character(),
                             n_works = integer(), pct = double()),
    coverage = 0, n_works_total = n_works_total, n_works_funded = 0L,
    n_works_checked = 0L, n_works_failed = 0L, n_works_no_id = 0L,
      source = source
  ), class = "sm_audit_funding")
}

.empty_funding_rows <- function() {
  tibble::tibble(work_id = character(), funder_name = character(),
                 funder_doi = character())
}

.fetch_funding_crossref <- function(works, mailto = "",
                                    call = rlang::caller_env()) {
  dois <- .normalize_doi(works$doi)
  run <- .crossref_lookup(dois, select = "DOI,funder", mailto = mailto,
                          call = call)
  rows <- list(.empty_funding_rows())
  checked <- character()
  for (record in run$records) {
    ids <- works$work_id[dois %in% record$DOI]
    checked <- c(checked, ids)
    for (funder in record$funder %||% list()) {
      if (!length(ids)) next
      rows[[length(rows) + 1L]] <- tibble::tibble(
        work_id = ids, funder_name = funder$name %||% NA_character_,
        funder_doi = funder$DOI %||% NA_character_
      )
    }
  }
  list(funders = dplyr::distinct(dplyr::bind_rows(rows)),
       checked = unique(checked),
       failed = works$work_id[dois %in% run$failed], condition = run$condition)
}

.fetch_funding_openalex <- function(works, api_key = "",
                                    call = rlang::caller_env()) {
  run <- .openalex_work_lookup(works, "id,doi,funders,awards", api_key, call)
  rows <- list(.empty_funding_rows())
  checked <- character()
  for (i in seq_len(nrow(works))) {
    record <- run$records[[i]]
    if (is.null(record)) next
    wid <- works$work_id[i]
    checked <- c(checked, wid)
    funders <- lapply(record$funders %||% list(), function(funder) {
      list(id = funder$id, name = funder$display_name)
    })
    known_ids <- vapply(
      funders, function(f) f$id %||% NA_character_, character(1)
    )
    grants <- c(record$awards %||% list(), record$grants %||% list())
    for (grant in grants) {
      id <- grant$funder_id %||% grant$funder %||% NA_character_
      name <- grant$funder_display_name %||% NA_character_
      hit <- match(id, known_ids)
      if (is.na(name) && !is.na(id) && !is.na(hit)) {
        name <- funders[[hit]]$name
      }
      funders[[length(funders) + 1L]] <- list(id = id, name = name)
    }
    for (funder in funders) {
      name <- funder$name %||% NA_character_
      id <- funder$id %||% NA_character_
      if (is.na(name) && is.na(id)) next
      rows[[length(rows) + 1L]] <- tibble::tibble(
        work_id = wid, funder_name = name, funder_doi = id
      )
    }
  }
  list(funders = dplyr::distinct(dplyr::bind_rows(rows)), checked = checked,
       failed = run$failed, condition = run$condition)
}

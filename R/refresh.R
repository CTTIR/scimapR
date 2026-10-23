#' Refresh stale corpus data
#'
#' @description
#' Re-fetches metadata for works whose `last_refreshed` timestamp is older
#' than `max_age_days`. For each stale work, the original provenance source
#' is consulted: OpenAlex supplies citation counts and open-access status;
#' Crossref supplies citation counts. Other sources remain stale. Failed
#' requests, missing identifiers and records not returned are reported.
#' Only works with returned updates receive a new timestamp and provenance
#' row. `metadata$last_refresh` advances only when at least one work was
#' refreshed and none failed. Enrichment rows never select a refresh source.
#'
#' The operation is **idempotent**: running it twice in succession will not
#' re-fetch works that were just refreshed. The function **refuses to operate
#' on a locked corpus**; use [sm_unlock()] first.
#'
#' @param corpus An `sm_corpus` object.
#' @param max_age_days Numeric. Works last refreshed more than this many days
#'   ago will be re-fetched. Default `30`.
#' @param what Character vector of data aspects to refresh. One or more of
#'   `"citations"` and `"oa_status"` (the default). `"new_refs"` and
#'   `"altmetric"` are accepted but unsupported: they warn and are ignored,
#'   or error when no implemented aspect remains.
#' @param sources Optional character vector restricting which provenance
#'   sources to re-query (e.g., `"openalex"`, `"crossref"`). If `NULL` (the
#'   default), the original source for each work is used.
#' @param verbose Logical. Print progress messages?
#' @param api_key OpenAlex API key, sent only in the authorization header.
#' @param mailto Contact address for Crossref requests.
#' @param call Caller environment for error reporting.
#'
#' @return A refreshed `sm_corpus` with updated fields and appended
#'   provenance rows.
#'
#' @family refresh
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' # In practice, this would re-fetch from APIs:
#' # refreshed <- sm_refresh(corpus, max_age_days = 7)
sm_refresh <- function(corpus, max_age_days = 30,
                       what = c("citations", "oa_status"), sources = NULL,
                       verbose = TRUE, api_key = Sys.getenv("OPENALEX_API_KEY"),
                       mailto = Sys.getenv("SCIMAPR_MAILTO"),
                       call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_corpus_unlocked(corpus, call = call)
  what <- rlang::arg_match(what, c("citations", "oa_status", "new_refs",
                                   "altmetric"),
                           multiple = TRUE, error_call = call)
  unsupported <- intersect(what, c("new_refs", "altmetric"))
  what <- setdiff(what, unsupported)
  if (length(unsupported)) {
    message <- "Unsupported refresh aspects: {.val {unsupported}}."
    if (!length(what)) {
      cli::cli_abort(message, class = "scimapR_refresh_aspect_unsupported",
                     call = call)
    }
    cli::cli_warn(message, class = "scimapR_refresh_aspect_unsupported",
                  call = call)
  }
  valid_sources <- c("openalex", "crossref", "pubmed", "semantic_scholar",
                     "arxiv", "biorxiv", "unpaywall", "altmetric")
  bad <- setdiff(tolower(sources), valid_sources)
  if (length(bad)) {
    cli::cli_abort(
      c("Unknown {cli::qty(length(bad))}source{?s}: {.val {bad}}.",
        "i" = "Valid sources: {.val {valid_sources}}."),
      class = "scimapR_refresh_unknown_source", call = call
    )
  }
  staleness <- sm_staleness(corpus, threshold_days = max_age_days, call = call)
  stale_ids <- staleness$work_id[staleness$is_stale]
  if (!length(stale_ids)) {
    .sm_verbose("No stale works found. Corpus is up to date.", verbose)
    return(corpus)
  }
  bases <- .refresh_base_sources(corpus)
  chosen <- match(stale_ids, corpus$works$work_id)
  if (!is.null(sources)) chosen <- chosen[bases[chosen] %in% tolower(sources)]
  if (!length(chosen)) {
    .sm_verbose("No stale works match the specified sources.", verbose)
    return(corpus)
  }
  groups <- split(corpus$works$work_id[chosen], bases[chosen])
  statuses <- list()
  condition <- NULL
  now <- Sys.time()
  for (source in names(groups)) {
    run <- .refresh_from_source(corpus, unique(groups[[source]]), source,
                                what, api_key = api_key, mailto = mailto,
                                call = call)
    statuses[[source]] <- dplyr::mutate(run$status, source = source)
    condition <- if (inherits(condition, "scimapR_rate_limited")) condition else
      run$condition %||% condition
    refreshed <- run$status$work_id[run$status$status == "refreshed"]
    for (wid in refreshed) {
      i <- match(wid, corpus$works$work_id)
      updates <- run$updates[[wid]]
      for (column in names(updates)) {
        corpus$works[[column]][i] <- updates[[column]]
      }
      corpus$works$last_refreshed[i] <- now
      aspects <- c(cited_by_count = "citations", oa_status = "oa_status")
      actual <- unname(aspects[names(updates)])
      external <- if (source == "openalex") {
        .openalex_lookup_keys(corpus$works[i, ], by = c("openalex_id",
                                                        "doi"))$key
      } else {
        .normalize_doi(corpus$works$doi[i])
      }
      row <- .make_provenance_rows(
        wid, paste0(source, "_refresh"), external,
        paste0("sm_refresh(what=", paste(actual, collapse = ","), ")"),
        "native", kind = "refresh"
      )
      row$fetch_date <- now
      corpus$provenance <- dplyr::bind_rows(corpus$provenance, row)
    }
  }
  status <- dplyr::bind_rows(statuses)
  n <- sum(status$status == "refreshed")
  failed <- status$work_id[status$status == "failed"]
  if (n > 0L && !length(failed)) corpus$metadata$last_refresh <- now
  if (length(failed)) {
    .sm_warn_unchecked(
      failed, condition, "scimapR_refresh_failed",
      sprintf(paste0("%d works remain stale after failed requests; ",
                     "metadata$last_refresh is unchanged."), length(failed)),
      call = call, key_setting = "OPENALEX_API_KEY"
    )
  }
  skipped <- status[status$status %in% c("not_found", "no_id", "unsupported"), ]
  if (nrow(skipped)) {
    labels <- ifelse(skipped$status == "unsupported",
                     paste0("unsupported (", skipped$source, ")"),
                     skipped$status)
    counts <- table(labels)
    details <- paste(paste(names(counts), as.integer(counts), sep = ": "),
                     collapse = "; ")
    cli::cli_warn(.sm_cli_escape(paste0("Works left stale: ", details, ".")),
                  class = "scimapR_refresh_skipped", call = call)
  }
  total <- nrow(status)
  .sm_verbose(sprintf("Refreshed %d of %d stale works.", n, total), verbose)
  corpus
}

.refresh_base_sources <- function(corpus) {
  prov <- corpus$provenance
  source <- tolower(prov$source)
  kind <- .provenance_kind(source, prov[["kind"]], prov$query)
  enrichment <- c("retraction_check", "unpaywall", "altmetric",
                  "opencitations", "orcid", "ror")
  drop <- kind == "enrichment" | source %in% enrichment |
    (!is.na(prov$query) & startsWith(prov$query, "enrich_"))
  prov <- prov[!drop, ]
  prov <- prov[order(prov$fetch_date, seq_len(nrow(prov)), na.last = TRUE), ]
  base <- sub("(_refresh)+$", "", tolower(prov$source))
  out <- base[match(corpus$works$work_id, prov$work_id)]
  out[is.na(out) | !nzchar(out)] <- "unknown"
  out
}

.refresh_result <- function(works, status = "unsupported") {
  list(status = tibble::tibble(work_id = works$work_id,
                               status = rep(status, nrow(works)),
                               reason = status),
       updates = list(), condition = NULL)
}

.refresh_from_source <- function(corpus, work_ids, source, what, api_key = "",
                                 mailto = "", call = rlang::caller_env()) {
  works <- corpus$works[match(work_ids, corpus$works$work_id), ]
  switch(source,
         openalex = .refresh_openalex(works, what, api_key, call),
         crossref = .refresh_crossref(works, what, mailto, call),
         .refresh_result(works))
}

.refresh_openalex <- function(works, what, api_key = "",
                              call = rlang::caller_env()) {
  run <- .openalex_work_lookup(works, "id,doi,cited_by_count,open_access",
                               api_key, call)
  result <- .refresh_result(works, "not_found")
  result$condition <- run$condition
  for (i in seq_len(nrow(works))) {
    record <- run$records[[i]]
    wid <- works$work_id[i]
    state <- if (is.na(run$ids[i])) {
      "no_id"
    } else if (wid %in% run$failed) {
      "failed"
    } else if (is.null(record)) {
      "not_found"
    } else {
      "refreshed"
    }
    updates <- list()
    if (state == "refreshed") {
      count <- record$cited_by_count
      oa <- record$open_access$oa_status
      if ("citations" %in% what && length(count) == 1L && !is.na(count)) {
        updates$cited_by_count <- as.integer(count)
      }
      if ("oa_status" %in% what && length(oa) == 1L && !is.na(oa)) {
        updates$oa_status <- as.character(oa)
      }
      if (!length(updates)) state <- "not_found"
    }
    if (state == "refreshed") result$updates[[wid]] <- updates
    result$status$status[i] <- state
    result$status$reason[i] <- state
  }
  result
}

.refresh_crossref <- function(works, what, mailto = "",
                              call = rlang::caller_env()) {
  if (!"citations" %in% what) return(.refresh_result(works))
  dois <- .normalize_doi(works$doi)
  run <- .crossref_lookup(dois, select = "DOI,is-referenced-by-count",
                          mailto = mailto, call = call)
  returned <- vapply(run$records, function(x) .normalize_doi(x$DOI),
                     character(1))
  result <- .refresh_result(works, "not_found")
  result$condition <- run$condition
  for (i in seq_len(nrow(works))) {
    hit <- match(dois[i], returned)
    state <- if (is.na(dois[i]) || !nzchar(dois[i])) {
      "no_id"
    } else if (dois[i] %in% run$failed) {
      "failed"
    } else {
      "not_found"
    }
    if (!is.na(hit)) {
      count <- run$records[[hit]][["is-referenced-by-count"]]
      if (length(count) == 1L && !is.na(count)) {
        state <- "refreshed"
        result$updates[[works$work_id[i]]] <- list(
          cited_by_count = as.integer(count)
        )
      }
    }
    result$status$status[i] <- state
    result$status$reason[i] <- state
  }
  result
}

.refresh_pubmed <- function(works, what, call = rlang::caller_env()) {
  .refresh_result(works)
}

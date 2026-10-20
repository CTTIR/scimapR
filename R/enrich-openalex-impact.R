#' Add OpenAlex impact fields to any corpus
#'
#' @description
#' Looks the works of a corpus up on [OpenAlex](https://openalex.org/) by
#' identifier and adds OpenAlex's impact fields: the field-weighted
#' citation impact (`fwci`), the citation percentile
#' (`citation_percentile`, 0 to 1, with the flags `is_top_10pct` and
#' `is_top_1pct`), the date of these values (`citations_as_of`) and the
#' yearly citation counts (the corpus element `citations_by_year`). The
#' corpus can come from any source, such as Web of Science files or
#' [sm_corpus_from_tables()]; only identifiers are sent.
#'
#' @details
#' Each work is looked up by the first identifier of `by` that it has: its
#' OpenAlex id (`works$openalex_id`, shortened to the `W` number) or its
#' DOI (normalised on both sides, so `https://doi.org/` prefixes and case
#' do not matter). Works without either are counted and left as they are.
#' A DOI that contains `,` or `|` cannot be written into an OpenAlex
#' filter; such works are left out and counted too. The identifiers are
#' sent in batches of `batch_size` (at most 100, the number of values an
#' OpenAlex filter takes), with only the fields needed (`select`). When
#' OpenAlex has several records for one DOI, the record with the most
#' yearly citations is used, then the one with the lowest OpenAlex id.
#'
#' The fields are joined with [sm_materialise()] (`overwrite = TRUE`). All
#' five values of a work found come from its OpenAlex record, `NA` where
#' the record has none, so a new run replaces the values of an earlier run
#' or of another source, and the values, their date (`citations_as_of`)
#' and the yearly counts of a work always belong to one record. The works
#' not found keep their values. Only these five `works` columns change;
#' `cited_by_count` and the other columns keep the values of their source.
#' The `citations_by_year` rows of every work found are replaced by the
#' counts OpenAlex has now; the rows of the other works stay.
#' `metadata$last_refresh` is not changed.
#'
#' Every work found gets a provenance row with the source
#' `"openalex_impact"`, its OpenAlex id in `source_id_external`, a short
#' description of the call in `query` and the kind `"enrichment"`, so
#' [sm_rebuild_from_cert()] never replays the step as a search. Neither
#' the API key nor any request URL or filter is stored.
#'
#' On HTTP 429 (the request budget is used up) the function stops at once
#' and joins nothing, not even the batches fetched before: a partial
#' enrichment would compare works with OpenAlex values against works
#' without them. The error
#' (class `scimapR_openalex_rate_limit`) names the reset time, the
#' remaining budget OpenAlex reports and the key setting. Any other failed
#' request stops it too (class `scimapR_openalex_failed`).
#'
#' @inheritSection sm_fetch_openalex API key and rate limits
#'
#' @param corpus An `sm_corpus`.
#' @param by The identifiers to look works up by, in order of preference:
#'   one or both of `"openalex_id"` and `"doi"`. The default tries the
#'   OpenAlex id first and the DOI for works without one, as in corpora from
#'   Web of Science files, whose `openalex_id` is `NA`.
#' @param batch_size Number of identifiers per request, from 1 to 100
#'   (default `50`). Larger values are lowered to 100 with a message.
#' @param api_key OpenAlex API key. Read from the `OPENALEX_API_KEY`
#'   environment variable by default; see "API key and rate limits".
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return The `corpus` with the `works` columns `fwci`,
#'   `citation_percentile`, `is_top_10pct`, `is_top_1pct` and
#'   `citations_as_of` (see [sm_corpus()]), the element `citations_by_year`
#'   and a provenance row for each work found. The columns and the element
#'   are added even when OpenAlex has none of the works looked up (with
#'   `NA` and no rows where the corpus had none). A corpus without works,
#'   or without works that have an identifier, is returned unchanged.
#'
#' @family enrichers
#' @seealso [sm_fetch_openalex()], [sm_citation_window()]
#' @export
#' @examples
#' \dontrun{
#' fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
#' fix <- sm_enrich_openalex_impact(fix, by = "doi")
#' sm_citation_window(fix, window = 3)
#' }
sm_enrich_openalex_impact <- function(corpus,
                                      by = c("openalex_id", "doi"),
                                      batch_size = 50L,
                                      api_key = Sys.getenv("OPENALEX_API_KEY"),
                                      verbose = TRUE,
                                      call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  by <- unique(rlang::arg_match(by, multiple = TRUE, error_call = call))
  batch_size <- .check_positive_int(batch_size, call = call)
  .check_flag(verbose, call = call)
  if (batch_size > 100L) {
    .sm_verbose(
      paste0("{.arg batch_size} lowered to 100, the most values an OpenAlex ",
             "filter takes."),
      verbose
    )
    batch_size <- 100L
  }
  api_key <- .openalex_setting(api_key)

  works <- corpus$works
  if (nrow(works) == 0L) {
    .sm_verbose("The corpus has no works; nothing to enrich.", verbose)
    return(corpus)
  }

  keys <- .openalex_lookup_keys(works, by)
  n_unsafe <- sum(keys$unsafe_doi)
  n_looked <- sum(!is.na(keys$key))
  if (n_looked == 0L) {
    .sm_verbose(
      "No work has an identifier to look up ({.val {by}}); nothing to enrich.",
      verbose
    )
    return(corpus)
  }

  batches <- .openalex_key_batches(keys, batch_size)
  .sm_verbose(
    paste0("Looking up {n_looked} work{?s} on OpenAlex in ",
           "{length(batches)} batch{?es}..."),
    verbose
  )
  fetched_at <- Sys.time()
  run <- .openalex_batches(
    batches,
    fetch = function(b) {
      .openalex_fetch_all(
        "works",
        list(filter = paste0(b$filter_key, ":",
                             paste(b$values, collapse = "|")),
             select = paste("id,doi,fwci,citation_normalized_percentile",
                            "counts_by_year,updated_date", sep = ",")),
        per_page = 100L, api_key = api_key, call = call
      )
    },
    context = paste0("Nothing was joined: a partial enrichment would ",
                     "compare works with OpenAlex values against works ",
                     "without them."),
    call = call
  )

  records <- .openalex_pick_records(batches, run$results)
  hit <- match(paste(keys$type, keys$key), paste(records$type, records$key))
  hit[is.na(keys$key)] <- NA_integer_
  found <- !is.na(hit)
  n_found <- sum(found)
  n_missing <- n_looked - n_found
  n_no_id <- sum(is.na(keys$key)) - n_unsafe

  corpus <- .coerce_impact_columns(corpus)
  if (n_found > 0L) {
    ids <- works$work_id[found]
    chosen <- records$record[hit[found]]
    impact <- .openalex_impact_fields(chosen, ids, fetched = fetched_at)
    # All values of a work found come from its record, NA included, so they
    # stay one record's with their date and yearly counts. sm_materialise()
    # keeps an older value where the new one is NA: clear these works first.
    corpus$works <- .clear_impact_values(corpus$works, found)
    corpus <- if (verbose) {
      sm_materialise(corpus, list(works = impact$works), overwrite = TRUE,
                     call = call)
    } else {
      suppressMessages(
        sm_materialise(corpus, list(works = impact$works), overwrite = TRUE,
                       call = call)
      )
    }
    old <- corpus$citations_by_year %||% .empty_citations_by_year()
    yearly <- dplyr::bind_rows(old[!old$work_id %in% ids, , drop = FALSE],
                               impact$citations_by_year)
    corpus$citations_by_year <- yearly[
      order(yearly$work_id, yearly$year, method = "radix"), , drop = FALSE
    ]

    prov <- .make_provenance_rows(
      work_ids = ids,
      source_name = "openalex_impact",
      external_ids = .openalex_short_id(
        vapply(chosen, function(r) r[["id"]] %||% NA_character_,
               character(1))
      ),
      query_text = paste0("sm_enrich_openalex_impact(by = ",
                          paste(by, collapse = ", "), ")"),
      engine_name = "native"
    )
    prov$fetch_date <- fetched_at
    prov$kind <- "enrichment"
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, prov)
  }
  # the columns and the element are there whatever OpenAlex found
  corpus$works <- .add_impact_columns(corpus$works)
  corpus$citations_by_year <- corpus$citations_by_year %||%
    .empty_citations_by_year()
  validate_sm_corpus(corpus, call = call)

  if (verbose && n_found > 0L) {
    .sm_done(paste0(
      "Added OpenAlex impact fields to {n_found} of {nrow(works)} work{?s}",
      if (n_missing > 0L) " ({n_missing} not found on OpenAlex)" else "",
      "."
    ))
  } else if (verbose) {
    cli::cli_inform(c(
      "!" = "OpenAlex has none of the {n_looked} work{?s} looked up; no
             impact values were added."
    ))
  }
  if (n_no_id + n_unsafe > 0L) {
    .sm_verbose(paste0(
      "Not looked up: {n_no_id} work{?s} without an identifier",
      if (n_unsafe > 0L) {
        paste0(" and {n_unsafe} with a DOI that contains a comma or a ",
               "vertical bar, which an OpenAlex filter cannot hold")
      } else {
        ""
      },
      "."
    ), verbose)
  }
  corpus
}

#' The identifier each work is looked up by
#'
#' The first identifier of `by` that a work has: its OpenAlex id (the `W`
#' number) or its normalised DOI. A DOI with `,` or `|` cannot go into an
#' OpenAlex filter, so it counts as missing and is flagged in `unsafe_doi`
#' when no other identifier of `by` is left.
#' @return A tibble along the works: `type` (`"openalex_id"`, `"doi"` or
#'   `NA`), `key` and `unsafe_doi`.
#' @noRd
.openalex_lookup_keys <- function(works, by) {
  n <- nrow(works)
  oa <- .openalex_short_id(works$openalex_id %||% rep(NA_character_, n))
  doi <- .normalize_doi(works$doi %||% rep(NA_character_, n))
  doi <- as.character(doi)
  unsafe <- !is.na(doi) & grepl("[,|]", doi)
  doi[unsafe] <- NA_character_
  type <- rep(NA_character_, n)
  key <- rep(NA_character_, n)
  for (b in rev(by)) {
    value <- if (b == "openalex_id") oa else doi
    use <- !is.na(value)
    type[use] <- b
    key[use] <- value[use]
  }
  unsafe <- unsafe & is.na(key) & "doi" %in% by
  tibble::tibble(type = type, key = key, unsafe_doi = unsafe)
}

#' OpenAlex work ids shortened to the `W` number; `NA` when not one
#' @noRd
.openalex_short_id <- function(x) {
  x <- trimws(as.character(x))
  shape <- "^(?:https?://(?:www\\.)?openalex\\.org/)?([Ww][0-9]+)$"
  m <- regmatches(x, regexec(shape, x, perl = TRUE))
  vapply(m, function(p) {
    if (length(p) == 2L) toupper(p[2]) else NA_character_
  }, character(1))
}

#' Batches of unique identifiers, one filter per batch
#' @return A list of batches: `type`, `filter_key` (`openalex` or `doi`) and
#'   `values`.
#' @noRd
.openalex_key_batches <- function(keys, batch_size) {
  out <- list()
  for (type in c("openalex_id", "doi")) {
    values <- unique(keys$key[keys$type %in% type])
    if (length(values) == 0L) next
    values <- sort(values, method = "radix")
    chunks <- split(values, ceiling(seq_along(values) / batch_size))
    filter_key <- if (type == "openalex_id") "openalex" else "doi"
    out <- c(out, lapply(unname(chunks), function(v) {
      list(type = type, filter_key = filter_key, values = v)
    }))
  }
  out
}

#' One OpenAlex record per identifier
#'
#' Records are matched to the identifiers of their batch (the shortened id,
#' or the normalised DOI). Of several records for one identifier, the one
#' with the most yearly citations is kept, then the one with the lowest
#' OpenAlex id.
#' @return A tibble: `type`, `key` and `record` (a list column).
#' @noRd
.openalex_pick_records <- function(batches, results) {
  rows <- lapply(seq_along(batches), function(i) {
    recs <- results[[i]] %||% list()
    if (length(recs) == 0L) return(NULL)
    b <- batches[[i]]
    key <- if (b$type == "openalex_id") {
      .openalex_short_id(vapply(recs, function(r) {
        r[["id"]] %||% NA_character_
      }, character(1)))
    } else {
      as.character(.normalize_doi(vapply(recs, function(r) {
        r[["doi"]] %||% NA_character_
      }, character(1))))
    }
    total <- vapply(recs, function(r) {
      counts <- r[["counts_by_year"]] %||% list()
      sum(vapply(counts, function(e) {
        v <- suppressWarnings(as.numeric(e[["cited_by_count"]] %||% 0))
        if (length(v) == 1L && is.finite(v)) v else 0
      }, numeric(1)))
    }, numeric(1))
    id_num <- suppressWarnings(as.numeric(sub("^W", "", .openalex_short_id(
      vapply(recs, function(r) r[["id"]] %||% NA_character_, character(1))
    ))))
    keep <- !is.na(key) & key %in% b$values
    tibble::tibble(type = b$type, key = key, total = total, id_num = id_num,
                   record = recs)[keep, ]
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) {
    return(tibble::tibble(type = character(), key = character(),
                          record = list()))
  }
  all <- dplyr::bind_rows(rows)
  all <- all[order(all$type, all$key, -all$total, all$id_num,
                   method = "radix"), , drop = FALSE]
  all <- all[!duplicated(all[c("type", "key")]), , drop = FALSE]
  all[c("type", "key", "record")]
}

#' The impact columns the enrichment writes, each as a typed NA
#' @noRd
.impact_columns <- function() {
  list(fwci = NA_real_, citation_percentile = NA_real_, is_top_10pct = NA,
       is_top_1pct = NA, citations_as_of = as.Date(NA))
}

#' Give existing impact columns their schema types before a join
#'
#' A `citations_as_of` stored as a day count or as text, as a table store
#' can give it back, becomes the Date it stands for (`.as_day_dates()`).
#' @noRd
.coerce_impact_columns <- function(corpus) {
  works <- corpus$works
  for (col in c("fwci", "citation_percentile")) {
    if (col %in% names(works) && !is.double(works[[col]])) {
      works[[col]] <- suppressWarnings(as.numeric(works[[col]]))
    }
  }
  for (col in c("is_top_10pct", "is_top_1pct")) {
    if (col %in% names(works) && !is.logical(works[[col]])) {
      works[[col]] <- as.logical(works[[col]])
    }
  }
  if (!is.null(works[["citations_as_of"]])) {
    works$citations_as_of <- .as_day_dates(works$citations_as_of,
                                           what = "works$citations_as_of")
  }
  corpus$works <- works
  corpus
}

#' Clear the impact values of some works (logical `rows`) before a join
#' @noRd
.clear_impact_values <- function(works, rows) {
  for (col in intersect(names(.impact_columns()), names(works))) {
    works[[col]][rows] <- NA
  }
  works
}

#' Add the impact columns a works table lacks, as typed NA
#' @noRd
.add_impact_columns <- function(works) {
  template <- .impact_columns()
  for (col in setdiff(names(template), names(works))) {
    works[[col]] <- rep(template[[col]], nrow(works))
  }
  works
}

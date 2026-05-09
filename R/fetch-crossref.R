#' Fetch works from Crossref
#'
#' @description
#' Query the [Crossref](https://api.crossref.org/) API for scholarly works
#' and return the results as an `sm_corpus`.
#'
#' Uses offset-based pagination to retrieve up to `n_max` works. Providing
#' a `mailto` address enables the polite pool (faster rate limits).
#'
#' @param query Free-text search query. If `NULL`, `filter` must be supplied.
#' @param filter Crossref filter syntax, e.g.
#'   `"from-pub-date:2020,type:journal-article"`.
#' @param n_max Maximum number of works to return (default 200).
#' @param mailto Email address for the polite pool. Read from
#'   `SCIMAPR_MAILTO` env var by default.
#' @param engine One of `"native"` (built-in httr2 client), `"rcrossref"`
#'   (use the rcrossref package), or `"auto"` (use rcrossref if available,
#'   otherwise native).
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object.
#'
#' @family fetchers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_fetch_crossref(query = "bibliometrics", n_max = 10)
#' print(corpus)
#' }
sm_fetch_crossref <- function(query = NULL,
                              filter = NULL,
                              n_max = 200L,
                              mailto = Sys.getenv("SCIMAPR_MAILTO"),
                              engine = c("native", "rcrossref", "auto"),
                              verbose = TRUE,
                              call = rlang::caller_env()) {
  engine <- rlang::arg_match(engine, error_call = call)
  n_max <- .check_positive_int(n_max, call = call)

  if (is.null(query) && is.null(filter)) {
    cli::cli_abort(
      "At least one of {.arg query} or {.arg filter} must be provided.",
      call = call
    )
  }

  if (engine == "auto") {
    engine <- if (rlang::is_installed("rcrossref")) "rcrossref" else "native"
  }

  if (engine == "rcrossref") {
    return(.fetch_crossref_rcrossref(
      query = query, filter = filter, n_max = n_max,
      mailto = mailto, verbose = verbose, call = call
    ))
  }

  # ---- native httr2 implementation ----
  .sm_verbose("Fetching works from Crossref...", verbose)

  rows_per_page <- 100L
  collected <- list()
  offset <- 0L

  repeat {
    this_page <- min(rows_per_page, n_max - length(collected))
    if (this_page <= 0L) break

    req <- httr2::request("https://api.crossref.org/works") |>
      httr2::req_url_query(rows = this_page, offset = offset) |>
      httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
      httr2::req_throttle(rate = 50 / 1)

    if (!is.null(query) && nzchar(query)) {
      req <- httr2::req_url_query(req, query.bibliographic = query)
    }
    if (!is.null(filter) && nzchar(filter)) {
      req <- httr2::req_url_query(req, filter = filter)
    }
    if (nzchar(mailto)) {
      req <- httr2::req_url_query(req, mailto = mailto)
    }

    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        cli::cli_abort(
          c("Crossref API request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    body <- httr2::resp_body_json(resp)
    items <- body[["message"]][["items"]]

    if (length(items) == 0L) break

    collected <- c(collected, items)
    offset <- offset + length(items)

    total_results <- body[["message"]][["total-results"]] %||% n_max

    .sm_verbose(
      "Fetched {length(collected)} / {min(n_max, total_results)} works.",
      verbose
    )

    if (length(collected) >= n_max || offset >= total_results) break
  }

  if (length(collected) == 0L) {
    .sm_verbose("No results found.", verbose)
    return(.empty_corpus_with_provenance("crossref", query, "native"))
  }

  .parse_crossref_results(collected, query, verbose, call)
}

# ---- internal helpers ----

#' @noRd
.parse_crossref_results <- function(items, query_text, verbose, call) {
  n <- length(items)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = .normalize_doi(purrr::map_chr(items, "DOI", .default = NA_character_)),
    title = purrr::map_chr(items, \(x) {
      tt <- x[["title"]]
      if (is.null(tt) || length(tt) == 0) NA_character_ else tt[[1]]
    }),
    abstract = purrr::map_chr(items, \(x) {
      ab <- x[["abstract"]]
      if (is.null(ab)) NA_character_ else gsub("<[^>]+>", "", ab)
    }),
    year = as.integer(purrr::map_int(items, \(x) {
      dp <- x[["published-print"]][["date-parts"]][[1]] %||%
            x[["published-online"]][["date-parts"]][[1]] %||%
            x[["issued"]][["date-parts"]][[1]]
      if (is.null(dp) || length(dp) == 0) NA_integer_ else as.integer(dp[[1]])
    })),
    type = purrr::map_chr(items, "type", .default = NA_character_),
    source_id = purrr::map_chr(items, \(x) {
      issn <- x[["ISSN"]]
      if (is.null(issn) || length(issn) == 0) NA_character_ else issn[[1]]
    }),
    cited_by_count = as.integer(
      purrr::map_int(items, "is-referenced-by-count", .default = 0L)
    ),
    oa_status = NA_character_,
    language = purrr::map_chr(items, "language", .default = NA_character_),
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # ---- authors ----
  author_data <- .parse_crossref_authors(items, work_ids)

  # ---- sources ----
  sources <- .parse_crossref_sources(items)

  # ---- references ----
  references <- .parse_crossref_references(items, work_ids)

  # ---- provenance ----
  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = "crossref",
    external_ids = works$doi,
    query_text = query_text,
    engine_name = "native"
  )

  .sm_done("Parsed {n} Crossref works into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = author_data$authors,
    authorships = author_data$authorships,
    sources = sources,
    references = references,
    provenance = provenance
  )
}

#' @noRd
.parse_crossref_authors <- function(items, work_ids) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(items)) {
    authors_raw <- items[[i]][["author"]] %||% list()
    for (j in seq_along(authors_raw)) {
      a <- authors_raw[[j]]
      name <- paste(a[["given"]] %||% "", a[["family"]] %||% "")
      name <- trimws(name)
      orcid <- a[["ORCID"]] %||% NA_character_
      if (!is.na(orcid)) {
        orcid <- sub("^https?://orcid\\.org/", "", orcid)
      }

      key <- if (!is.na(orcid)) orcid else tolower(name)
      if (is.null(author_map[[key]])) {
        aid <- paste0("A", formatC(length(author_map) + 1L, width = 9, flag = "0"))
        author_map[[key]] <- list(
          author_id = aid,
          orcid = orcid,
          display_name = name
        )
      }

      aff_raw <- a[["affiliation"]]
      aff_str <- if (length(aff_raw) > 0) {
        paste(purrr::map_chr(aff_raw, "name", .default = ""), collapse = "; ")
      } else {
        NA_character_
      }

      authorship_rows[[length(authorship_rows) + 1L]] <- tibble::tibble(
        work_id = work_ids[i],
        author_id = author_map[[key]]$author_id,
        position = as.integer(j),
        is_corresponding = identical(a[["sequence"]], "first") && j == 1L,
        institution_id = NA_character_,
        raw_affiliation = aff_str,
        country_code = NA_character_
      )
    }
  }

  authors_tbl <- if (length(author_map) > 0) {
    tibble::tibble(
      author_id = purrr::map_chr(author_map, "author_id"),
      orcid = purrr::map_chr(author_map, "orcid"),
      display_name = purrr::map_chr(author_map, "display_name"),
      display_name_alternatives = lapply(seq_along(author_map), function(i) character()),
      inferred_gender = NA_character_,
      gender_confidence = NA_real_,
      gender_method = NA_character_
    )
  } else {
    .empty_authors()
  }

  authorships_tbl <- if (length(authorship_rows) > 0) {
    dplyr::bind_rows(authorship_rows)
  } else {
    .empty_authorships()
  }

  list(authors = authors_tbl, authorships = authorships_tbl)
}

#' @noRd
.parse_crossref_sources <- function(items) {
  src_map <- list()
  for (item in items) {
    issn <- item[["ISSN"]]
    if (is.null(issn) || length(issn) == 0) next
    key <- issn[[1]]
    if (key %in% names(src_map)) next
    src_map[[key]] <- list(
      source_id = key,
      issn_l = key,
      issn = list(as.character(issn)),
      display_name = item[["container-title"]][[1]] %||% NA_character_,
      type = "journal",
      is_oa = NA,
      publisher = item[["publisher"]] %||% NA_character_,
      publisher_country = NA_character_
    )
  }
  if (length(src_map) == 0) return(.empty_sources())

  tibble::tibble(
    source_id = purrr::map_chr(src_map, "source_id"),
    issn_l = purrr::map_chr(src_map, "issn_l"),
    issn = purrr::map(src_map, "issn"),
    display_name = purrr::map_chr(src_map, "display_name"),
    type = purrr::map_chr(src_map, "type"),
    is_oa = purrr::map_lgl(src_map, "is_oa"),
    publisher = purrr::map_chr(src_map, "publisher"),
    publisher_country = purrr::map_chr(src_map, "publisher_country")
  )
}

#' @noRd
.parse_crossref_references <- function(items, work_ids) {
  rows <- list()
  for (i in seq_along(items)) {
    refs <- items[[i]][["reference"]] %||% list()
    if (length(refs) == 0) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      ref_index = seq_along(refs),
      cited_work_id = NA_character_,
      cited_doi = .normalize_doi(purrr::map_chr(refs, "DOI", .default = NA_character_)),
      cited_raw = purrr::map_chr(refs, "unstructured", .default = NA_character_)
    )
  }
  if (length(rows) == 0) return(.empty_references())
  dplyr::bind_rows(rows)
}

#' @noRd
.fetch_crossref_rcrossref <- function(query, filter, n_max, mailto,
                                      verbose, call) {
  rlang::check_installed("rcrossref",
                         reason = "to use engine = 'rcrossref'",
                         call = call)

  .sm_verbose("Fetching via rcrossref...", verbose)

  tryCatch({
    if (nzchar(mailto)) {
      Sys.setenv(crossref_email = mailto)
    }

    raw <- rcrossref::cr_works(
      query = query,
      filter = if (!is.null(filter)) {
        parts <- strsplit(filter, ",")[[1]]
        kv <- strsplit(parts, ":")
        stats::setNames(
          purrr::map_chr(kv, \(x) paste(x[-1], collapse = ":")),
          purrr::map_chr(kv, 1)
        )
      },
      limit = min(n_max, 1000L)
    )

    items <- raw$data
    if (is.null(items) || nrow(items) == 0) {
      .sm_verbose("No results from rcrossref.", verbose)
      return(.empty_corpus_with_provenance("crossref", query, "rcrossref"))
    }

    if (nrow(items) > n_max) items <- items[seq_len(n_max), ]

    n <- nrow(items)
    work_ids <- .generate_work_id(n)

    works <- tibble::tibble(
      work_id = work_ids,
      doi = .normalize_doi(items[["doi"]] %||% rep(NA_character_, n)),
      title = items[["title"]] %||% rep(NA_character_, n),
      abstract = NA_character_,
      year = as.integer(
        sub("-.*$", "", items[["issued"]] %||% rep(NA_character_, n))
      ),
      type = items[["type"]] %||% rep(NA_character_, n),
      source_id = NA_character_,
      cited_by_count = as.integer(
        items[["is.referenced.by.count"]] %||% rep(0L, n)
      ),
      oa_status = NA_character_,
      language = items[["language"]] %||% rep(NA_character_, n),
      pmid = NA_character_,
      arxiv_id = NA_character_,
      openalex_id = NA_character_,
      is_retracted = FALSE,
      retraction_date = as.Date(NA),
      last_refreshed = Sys.time()
    )

    provenance <- .make_provenance_rows(
      work_ids, "crossref", works$doi, query, "rcrossref"
    )

    .sm_done("Parsed {n} Crossref works (via rcrossref) into sm_corpus.")

    new_sm_corpus(
      works = works,
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      provenance = provenance
    )
  }, error = function(e) {
    cli::cli_abort(
      c("rcrossref fetch failed.",
        "i" = conditionMessage(e)),
      call = call
    )
  })
}

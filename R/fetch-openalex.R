#' Fetch works from OpenAlex
#'
#' @description
#' Query the [OpenAlex](https://openalex.org/) API for scholarly works and
#' return the results as an `sm_corpus`.
#'
#' Supports both free-text search (`query`) and structured filter syntax
#' (`filter`). Uses cursor-based pagination to retrieve up to `n_max` works.
#' Set an OpenAlex API key (see "API key and rate limits").
#'
#' Besides `cited_by_count`, the works keep OpenAlex's field-weighted
#' citation impact (`fwci`), its citation percentile (`citation_percentile`,
#' 0 to 1, with the flags `is_top_10pct` and `is_top_1pct`) and the date of
#' these values (`citations_as_of`), and the corpus gets the yearly citation
#' counts as `citations_by_year` (see [sm_corpus()] and
#' [sm_citation_window()]). The openalexR engine has no percentile, so its
#' three percentile columns are `NA`. To add these fields to a corpus from
#' another source, use [sm_enrich_openalex_impact()].
#'
#' @section API key and rate limits:
#' OpenAlex expects a free API key. Requests without one share one small
#' daily budget with everyone on the same network address; once it is used
#' up, OpenAlex answers HTTP 429 (too many requests) until the budget
#' resets at midnight UTC. Set the key in the
#' `OPENALEX_API_KEY` environment variable (for example in `~/.Renviron`)
#' or pass it as `api_key`. It is sent in the `Authorization` header,
#' never in the URL, and it is stored nowhere in the corpus.
#'
#' On HTTP 429 the function stops at once with an error of class
#' `scimapR_openalex_rate_limit` instead of waiting: the message gives the
#' reset time and the remaining budget that OpenAlex reports (the fields
#' `reset_at` and `remaining` of the condition) and says whether a key was
#' sent. Only a wait of up to two seconds (OpenAlex also limits requests per
#' second) is waited out, once. Other failed requests stop with class
#' `scimapR_openalex_failed`; both classes inherit from
#' `scimapR_openalex_error`. With `engine = "openalexR"` the
#' \pkg{openalexR} package (version 3.1.1 or later) sends the requests: it
#' gets the key too and its own retries are switched off, but it does not
#' pass on the response headers, so the reset time and the budget are not
#' known.
#'
#' @param query Free-text search query passed to the `search` parameter.
#'   If `NULL`, `filter` must be supplied.
#' @param filter A character string using OpenAlex filter syntax, e.g.
#'   `"from_publication_date:2020-01-01,type:journal-article"`.
#' @param n_max Maximum number of works to return (default 200).
#' @param per_page Number of results per page (max 200).
#' @param mailto Contact address sent with each request as the `mailto`
#'   parameter. Read from the `SCIMAPR_MAILTO` environment variable by
#'   default. OpenAlex no longer gives such requests a larger budget (the
#'   API key does), and the openalexR engine does not send it.
#' @param api_key OpenAlex API key. Read from the `OPENALEX_API_KEY`
#'   environment variable by default; see "API key and rate limits".
#' @param engine One of `"native"` (built-in httr2 client), `"openalexR"`
#'   (use the openalexR package), or `"auto"` (use openalexR if version
#'   3.1.1 or later is installed, otherwise native).
#' @param batch_size Integer; maximum number of `|`-joined values allowed in a
#'   single OpenAlex filter clause before the request is automatically split
#'   into multiple batched requests. OpenAlex limits the number of values in an
#'   `OR` filter and the overall URL length, so long DOI (or other ID) lists
#'   are chunked, fetched per batch, and row-bound with de-duplication. Default
#'   `50`, which stays comfortably under the API's documented limit of 100.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object.
#'
#' @family fetchers
#' @seealso [sm_enrich_openalex_impact()], [sm_citation_window()]
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_fetch_openalex(query = "bibliometrics", n_max = 10)
#' print(corpus)
#' }
sm_fetch_openalex <- function(query = NULL,
                              filter = NULL,
                              n_max = 200L,
                              per_page = 200L,
                              mailto = Sys.getenv("SCIMAPR_MAILTO"),
                              api_key = Sys.getenv("OPENALEX_API_KEY"),
                              engine = c("native", "openalexR", "auto"),
                              batch_size = 50L,
                              verbose = TRUE,
                              call = rlang::caller_env()) {
  engine <- rlang::arg_match(engine, error_call = call)
  n_max <- .check_positive_int(n_max, call = call)
  per_page <- .check_positive_int(per_page, call = call)
  batch_size <- .check_positive_int(batch_size, call = call)


  if (is.null(query) && is.null(filter)) {
    cli::cli_abort(
      "At least one of {.arg query} or {.arg filter} must be provided.",
      call = call
    )
  }

  if (engine == "auto") {
    engine <- if (rlang::is_installed("openalexR", version = "3.1.1")) {
      "openalexR"
    } else {
      "native"
    }
  }

  if (engine == "openalexR") {
    return(.fetch_openalex_openalexr(
      query = query, filter = filter, n_max = n_max,
      api_key = api_key, batch_size = batch_size,
      verbose = verbose, call = call
    ))
  }

  # ---- native httr2 implementation ----
  .sm_verbose("Fetching works from OpenAlex...", verbose)

  per_page <- min(per_page, 200L)
  collected <- list()
  cursor <- "*"
  n_fetched <- 0L

  repeat {
    params <- list(per_page = min(per_page, n_max - n_fetched),
                   cursor = cursor)
    if (!is.null(query) && nzchar(query)) params$search <- query
    if (!is.null(filter) && nzchar(filter)) params$filter <- filter
    body <- tryCatch(
      .openalex_request("works", params, api_key = api_key, mailto = mailto,
                        call = call),
      scimapR_openalex_rate_limit = function(cnd) {
        .openalex_abort_rate_limit(
          cnd, key_set = cnd$key_set, n_fetched = n_fetched,
          context = sprintf("%d works had been fetched; none are returned.",
                            n_fetched),
          call = call
        )
      }
    )
    results <- body[["results"]]

    if (length(results) == 0L) break

    collected <- c(collected, results)
    n_fetched <- length(collected)

    .sm_verbose(
      "Fetched {n_fetched} / {min(n_max, body$meta$count %||% n_max)} works.",
      verbose
    )

    cursor <- body[["meta"]][["next_cursor"]]
    if (is.null(cursor) || n_fetched >= n_max) break
  }

  if (length(collected) == 0L) {
    .sm_verbose("No results found.", verbose)
    return(.empty_corpus_with_provenance("openalex", query, "native"))
  }

  .parse_openalex_results(collected, query, verbose, call)
}


# ---- internal helpers ----

#' @noRd
.sm_user_agent <- function() {
  paste0("scimapR/",
         tryCatch(as.character(utils::packageVersion("scimapR")),
                  error = function(e) "0.1.0"),
         " (https://github.com/CTTIR/scimapR)")
}

#' @noRd
.empty_corpus_with_provenance <- function(source_name, query_text, engine_name) {
  new_sm_corpus(
    works = .empty_works(),
    authors = .empty_authors(),
    authorships = .empty_authorships(),
    provenance = tibble::tibble(
      work_id = character(),
      source = character(),
      source_id_external = character(),
      fetch_date = as.POSIXct(character()),
      query = character(),
      engine = character(),
      scimapR_version = character(),
      prompt_hash = character()
    )
  )
}

#' @noRd
.make_provenance_rows <- function(work_ids, source_name, external_ids,
                                  query_text, engine_name) {
  tibble::tibble(
    work_id = work_ids,
    source = source_name,
    source_id_external = external_ids,
    fetch_date = Sys.time(),
    query = query_text %||% NA_character_,
    engine = engine_name,
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )
}

#' Parse OpenAlex work records from the API into an sm_corpus
#'
#' @param fetched When the records were fetched: the as-of date of their
#'   impact fields when a record has no `updated_date`.
#' @noRd
.parse_openalex_results <- function(results, query_text, verbose, call,
                                    fetched = Sys.time()) {
  n <- length(results)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = .normalize_doi(purrr::map_chr(results, "doi", .default = NA_character_)),
    title = purrr::map_chr(results, "title", .default = NA_character_),
    # `.openalex_abstract` always returns a length-1 character (or
    # `NA_character_`), so no `.default` is needed -- and passing `.default` to
    # `map_chr()` with a function `.f` errors in current purrr (part of G1).
    abstract = purrr::map_chr(results, .openalex_abstract),
    year = as.integer(purrr::map_int(results, "publication_year", .default = NA_integer_)),
    type = purrr::map_chr(results, "type", .default = NA_character_),
    source_id = purrr::map_chr(results, \(w) {
      w[["primary_location"]][["source"]][["id"]] %||% NA_character_
    }),
    cited_by_count = as.integer(
      purrr::map_int(results, "cited_by_count", .default = 0L)
    ),
    oa_status = purrr::map_chr(results, \(w) {
      w[["open_access"]][["oa_status"]] %||% NA_character_
    }),
    language = purrr::map_chr(results, "language", .default = NA_character_),
    pmid = purrr::map_chr(results, \(w) {
      pid <- w[["ids"]][["pmid"]]
      if (is.null(pid)) NA_character_ else sub("^https://pubmed.ncbi.nlm.nih.gov/", "", pid)
    }),
    arxiv_id = NA_character_,
    openalex_id = purrr::map_chr(results, "id", .default = NA_character_),
    is_retracted = purrr::map_lgl(results, "is_retracted", .default = FALSE),
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # ---- impact fields and yearly citation counts ----
  impact <- .openalex_impact_fields(results, work_ids, fetched = fetched)
  works <- dplyr::bind_cols(works, impact$works[-1])

  # ---- authors & authorships ----
  author_data <- .parse_openalex_authorships(results, work_ids)

  # ---- sources ----
  sources <- .parse_openalex_sources(results)

  # ---- concepts ----
  concepts <- .parse_openalex_concepts(results, work_ids)

  # ---- references ----
  references <- .parse_openalex_references(results, work_ids)

  # ---- provenance ----
  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = "openalex",
    external_ids = works$openalex_id,
    query_text = query_text,
    engine_name = "native"
  )

  .sm_done("Parsed {n} OpenAlex works into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = author_data$authors,
    authorships = author_data$authorships,
    sources = sources,
    references = references,
    concepts = concepts,
    provenance = provenance,
    citations_by_year = impact$citations_by_year
  )
}

#' The impact fields of OpenAlex work records
#'
#' `fwci`, the citation percentile (`citation_normalized_percentile`: its
#' `value` and the flags `is_in_top_10_percent` and `is_in_top_1_percent`),
#' the as-of date of these values and the yearly citation counts
#' (`counts_by_year`), with `NA` (and no yearly rows) where a record lacks
#' them. Shared by the native fetcher, [sm_read_openalex_json()] and
#' [sm_enrich_openalex_impact()].
#'
#' The as-of date is the day of the record's `updated_date`; a record
#' without one gets the day of `fetched`, or `NA` when `fetched` is `NULL`
#' (records read from a file). The yearly counts are kept as OpenAlex gives
#' them: the ten most recent years, without the years that have no
#' citations.
#'
#' @param results OpenAlex work records (lists, as parsed from JSON).
#' @param work_ids The corpus `work_id` of each record.
#' @param fetched `NULL`, or when the records were fetched (POSIXct).
#' @return A list: `works` (tibble: `work_id`, `fwci`,
#'   `citation_percentile`, `is_top_10pct`, `is_top_1pct`,
#'   `citations_as_of`) and `citations_by_year` (tibble: `work_id`, `year`,
#'   `cited_by_count`, sorted).
#' @noRd
.openalex_impact_fields <- function(results, work_ids, fetched = NULL) {
  number <- function(x) {
    if (is.null(x) || length(x) != 1L || is.list(x)) return(NA_real_)
    suppressWarnings(as.numeric(x))
  }
  flag <- function(x) {
    if (is.logical(x) && length(x) == 1L) x else NA
  }
  percentile <- lapply(results, function(w) {
    p <- w[["citation_normalized_percentile"]]
    if (is.list(p)) p else list()
  })
  fallback <- if (is.null(fetched)) {
    as.Date(NA)
  } else {
    as.Date(.as_utc_time(fetched, what = "fetch time"), tz = "UTC")
  }
  as_of <- vapply(results, function(w) {
    updated <- w[["updated_date"]]
    if (!is.character(updated) || length(updated) != 1L) {
      return(as.numeric(fallback))
    }
    day <- as.Date(.as_utc_time(updated, what = "updated_date"), tz = "UTC")
    as.numeric(if (is.na(day)) fallback else day)
  }, numeric(1))

  works <- tibble::tibble(
    work_id = as.character(work_ids),
    fwci = vapply(results, function(w) number(w[["fwci"]]), numeric(1)),
    citation_percentile = vapply(percentile, function(p) {
      number(p[["value"]])
    }, numeric(1)),
    is_top_10pct = vapply(percentile, function(p) {
      flag(p[["is_in_top_10_percent"]])
    }, logical(1)),
    is_top_1pct = vapply(percentile, function(p) {
      flag(p[["is_in_top_1_percent"]])
    }, logical(1)),
    citations_as_of = as.Date(as_of, origin = "1970-01-01")
  )

  rows <- lapply(seq_along(results), function(i) {
    counts <- results[[i]][["counts_by_year"]]
    if (!is.list(counts) || length(counts) == 0L) return(NULL)
    year <- vapply(counts, function(e) number(e[["year"]]), numeric(1))
    cited <- vapply(counts, function(e) {
      number(e[["cited_by_count"]])
    }, numeric(1))
    ok <- is.finite(year) & is.finite(cited) & cited >= 0 &
      year == round(year) & cited == round(cited)
    tibble::tibble(work_id = as.character(work_ids[i]),
                   year = as.integer(year[ok]),
                   cited_by_count = as.integer(cited[ok]))
  })
  yearly <- .sm_bind_rows(rows, template = .empty_citations_by_year())
  yearly <- yearly[!duplicated(yearly[c("work_id", "year")]), , drop = FALSE]
  yearly <- yearly[order(yearly$work_id, yearly$year, method = "radix"), ,
                   drop = FALSE]
  list(works = works, citations_by_year = yearly)
}

#' The affiliation text of one OpenAlex authorship
#'
#' The authorship's `raw_affiliation_strings`, else the older single
#' `raw_affiliation_string`, else the `raw_affiliation_string` of its
#' `affiliations`, else the names of its institutions; several strings are
#' joined with `"; "`. `NA` when there is none.
#' @noRd
.openalex_raw_affiliation <- function(a) {
  text <- function(x) {
    x <- trimws(as.character(unlist(x, use.names = FALSE)))
    unique(x[!is.na(x) & nzchar(x)])
  }
  found <- text(a[["raw_affiliation_strings"]])
  if (length(found) == 0L) found <- text(a[["raw_affiliation_string"]])
  if (length(found) == 0L) {
    found <- text(lapply(a[["affiliations"]] %||% list(), function(x) {
      if (is.list(x)) x[["raw_affiliation_string"]]
    }))
  }
  if (length(found) == 0L) {
    found <- text(lapply(a[["institutions"]] %||% list(), function(x) {
      if (is.list(x)) x[["display_name"]]
    }))
  }
  if (length(found) == 0L) NA_character_ else paste(found, collapse = "; ")
}

#' Reconstruct abstract from an OpenAlex inverted index
#'
#' @description
#' OpenAlex stores abstracts as an `abstract_inverted_index`: a named list
#' mapping each word to the integer position(s) at which it appears. This
#' helper reconstructs the linear word order into a single character string.
#'
#' The reconstruction is fully defensive and type-stable: it always returns a
#' single character string, and returns `NA_character_` whenever the abstract
#' is absent (`NULL`), empty, or malformed (e.g. no usable integer positions).
#' It never errors, so a single bad record cannot abort an entire fetch.
#'
#' @param work A single OpenAlex work (a list).
#' @return A length-one character vector (the abstract or `NA_character_`).
#' @noRd
.openalex_abstract <- function(work) {
  inv <- tryCatch(work[["abstract_inverted_index"]], error = function(e) NULL)
  if (is.null(inv) || length(inv) == 0L) return(NA_character_)

  words <- names(inv)
  if (is.null(words)) return(NA_character_)

  # Map each word to its (possibly multiple) integer positions, dropping any
  # entries that fail to coerce to a finite integer position.
  positions <- lapply(inv, function(p) {
    p <- suppressWarnings(as.integer(unlist(p, use.names = FALSE)))
    p[!is.na(p)]
  })

  all_pos <- unlist(positions, use.names = FALSE)
  if (length(all_pos) == 0L) return(NA_character_)

  max_pos <- max(all_pos)
  if (!is.finite(max_pos) || max_pos < 0L) return(NA_character_)

  out <- character(max_pos + 1L)
  for (i in seq_along(words)) {
    pos <- positions[[i]]
    if (length(pos) == 0L) next
    out[pos + 1L] <- words[i]
  }

  result <- paste(out[nzchar(out)], collapse = " ")
  if (!nzchar(result)) NA_character_ else result
}

#' @noRd
.parse_openalex_authorships <- function(results, work_ids) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(results)) {
    aships <- results[[i]][["authorships"]] %||% list()
    work_rows <- list()
    flags <- logical()
    oa_ids <- character()
    for (j in seq_along(aships)) {
      a <- aships[[j]]
      au <- a[["author"]] %||% list()
      oa_author_id <- au[["id"]] %||% NA_character_
      if (is.na(oa_author_id)) next

      if (is.null(author_map[[oa_author_id]])) {
        aid <- paste0("A", formatC(length(author_map) + 1L, width = 9, flag = "0"))
        author_map[[oa_author_id]] <- list(
          author_id = aid,
          orcid = .normalize_orcid(au[["orcid"]]),
          display_name = au[["display_name"]] %||% NA_character_
        )
      }

      inst <- a[["institutions"]]
      inst_id <- if (length(inst) > 0) inst[[1]][["id"]] %||% NA_character_ else NA_character_
      raw_aff <- .openalex_raw_affiliation(a)

      cc <- NA_character_
      if (length(inst) > 0) {
        cc <- inst[[1]][["country_code"]] %||% NA_character_
      }

      flags <- c(flags, isTRUE(a[["is_corresponding"]]))
      oa_ids <- c(oa_ids, oa_author_id)
      work_rows[[length(work_rows) + 1L]] <- tibble::tibble(
        work_id = work_ids[i],
        author_id = author_map[[oa_author_id]]$author_id,
        position = as.integer(j),
        is_corresponding = NA,
        institution_id = inst_id,
        raw_affiliation = raw_aff,
        country_code = cc
      )
    }
    corresponding <- .openalex_corresponding(
      flags, oa_ids, results[[i]][["corresponding_author_ids"]]
    )
    for (k in seq_along(work_rows)) {
      work_rows[[k]]$is_corresponding <- corresponding[k]
    }
    authorship_rows <- c(authorship_rows, work_rows)
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
.parse_openalex_sources <- function(results) {
  src_map <- list()
  for (w in results) {
    loc <- w[["primary_location"]][["source"]]
    if (is.null(loc)) next
    sid <- loc[["id"]]
    if (is.null(sid) || sid %in% names(src_map)) next
    src_map[[sid]] <- list(
      source_id = sid,
      issn_l = loc[["issn_l"]] %||% NA_character_,
      issn = list(loc[["issn"]] %||% character()),
      display_name = loc[["display_name"]] %||% NA_character_,
      type = loc[["type"]] %||% NA_character_,
      is_oa = loc[["is_oa"]] %||% NA,
      publisher = loc[["host_organization_name"]] %||% NA_character_,
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
.parse_openalex_concepts <- function(results, work_ids) {
  rows <- list()
  for (i in seq_along(results)) {
    concepts <- results[[i]][["concepts"]] %||% list()
    for (c in concepts) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        work_id = work_ids[i],
        concept_id = c[["id"]] %||% NA_character_,
        concept_name = c[["display_name"]] %||% NA_character_,
        level = as.integer(c[["level"]] %||% NA_integer_),
        score = as.double(c[["score"]] %||% NA_real_),
        vocabulary = "openalex"
      )
    }
  }
  if (length(rows) == 0) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

#' @noRd
.parse_openalex_references <- function(results, work_ids) {
  rows <- list()
  for (i in seq_along(results)) {
    refs <- results[[i]][["referenced_works"]] %||% character()
    if (length(refs) == 0) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      ref_index = seq_along(refs),
      cited_work_id = NA_character_,
      cited_doi = NA_character_,
      cited_raw = as.character(refs)
    )
  }
  if (length(rows) == 0) return(.empty_references())
  dplyr::bind_rows(rows)
}

#' Parse an OpenAlex filter string into a named list of value vectors
#'
#' @description
#' Splits a comma-separated `key:value` OpenAlex filter string into a named
#' list, further splitting any `|`-joined OR values into a character vector.
#' Returns `NULL` for an empty/`NULL` filter so it can be passed straight to
#' `openalexR::oa_fetch(filter = ...)`.
#' @noRd
.parse_openalex_filter <- function(filter) {
  if (is.null(filter) || !nzchar(filter)) return(NULL)
  parts <- strsplit(filter, ",", fixed = TRUE)[[1]]
  parts <- trimws(parts)
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0L) return(NULL)

  out <- list()
  for (p in parts) {
    kv <- strsplit(p, ":", fixed = TRUE)[[1]]
    if (length(kv) < 2L) next
    key <- trimws(kv[1])
    val <- trimws(paste(kv[-1], collapse = ":"))
    vals <- trimws(strsplit(val, "|", fixed = TRUE)[[1]])
    vals <- vals[nzchar(vals)]
    out[[key]] <- vals
  }
  if (length(out) == 0L) return(NULL)
  out
}

#' Split a parsed OpenAlex filter into batches under an OR-value limit
#'
#' @description
#' Given a parsed filter (named list of value vectors), find the clause with
#' the most OR values; if it exceeds `batch_size`, produce one filter per chunk
#' of that clause (holding all other clauses constant). Returns a list of
#' parsed filters. Pure and network-free, so it is directly unit-testable.
#' @noRd
.batch_openalex_filter <- function(parsed, batch_size = 50L) {
  if (is.null(parsed) || length(parsed) == 0L) return(list(NULL))
  lengths_v <- vapply(parsed, length, integer(1))
  longest <- names(parsed)[which.max(lengths_v)]
  n_vals <- lengths_v[[which.max(lengths_v)]]

  if (n_vals <= batch_size) return(list(parsed))

  vals <- parsed[[longest]]
  idx <- split(seq_along(vals), ceiling(seq_along(vals) / batch_size))
  lapply(idx, function(ii) {
    b <- parsed
    b[[longest]] <- vals[ii]
    b
  })
}

#' The openalexR engine of sm_fetch_openalex()
#'
#' openalexR (3.1.1 or later) retries an HTTP 429 a few times, then warns
#' (class `openalexR_429`) and returns an empty result. Here its retries
#' are switched off (`openalexR.max_tries = 1`, as option and environment
#' variable, restored on exit) and the warning becomes the same rate-limit
#' abort as in the native engine. openalexR reads the key for every page
#' but the first from `openalexR.apikey`, so a given `api_key` is set there
#' for the duration of the call as well; an empty `api_key` leaves the
#' user's own openalexR setting in force.
#' @noRd
.fetch_openalex_openalexr <- function(query, filter, n_max, api_key = "",
                                      batch_size = 50L, verbose, call) {
  rlang::check_installed("openalexR", version = "3.1.1",
                         reason = "to use engine = 'openalexR'",
                         call = call)

  .sm_verbose("Fetching via openalexR...", verbose)

  api_key <- .openalex_setting(api_key)
  old_tries <- Sys.getenv("openalexR.max_tries", unset = NA)
  old_key <- Sys.getenv("openalexR.apikey", unset = NA)
  old_options <- options(openalexR.max_tries = 1L)
  on.exit({
    options(old_options)
    .restore_envvar("openalexR.max_tries", old_tries)
    .restore_envvar("openalexR.apikey", old_key)
  }, add = TRUE)
  Sys.setenv(openalexR.max_tries = "1")
  if (nzchar(api_key)) Sys.setenv(openalexR.apikey = api_key)
  key_set <- nzchar(Sys.getenv("openalexR.apikey")) ||
    !is.null(getOption("openalexR.apikey"))

  parsed <- .parse_openalex_filter(filter)
  batches <- .batch_openalex_filter(parsed, batch_size = batch_size)
  n_batches <- length(batches)
  if (n_batches > 1L) {
    .sm_verbose("Splitting filter into {n_batches} batches of <= {batch_size} values.",
                verbose)
  }

  n_rows <- 0L
  tryCatch({
    raw_list <- lapply(seq_along(batches), function(bi) {
      b_filter <- batches[[bi]]
      args <- list(
        entity = "works",
        search = query,
        filter = b_filter,
        count_only = FALSE,
        options = openalexR::oa_options(per_page = 200L),
        verbose = verbose
      )
      if (nzchar(api_key)) args$api_key <- api_key
      raw <- withCallingHandlers(
        do.call(openalexR::oa_fetch, args),
        openalexR_429 = function(w) {
          .openalex_abort_rate_limit(
            list(), key_set = key_set, engine = "openalexR",
            context = sprintf("%d of %d batch%s had been fetched.", bi - 1L,
                              n_batches, if (n_batches == 1L) "" else "es"),
            n_done = bi - 1L, n_batches = n_batches, n_fetched = n_rows,
            call = call
          )
        }
      )
      n_rows <<- n_rows + NROW(raw)
      raw
    })

    raw_list <- raw_list[!vapply(raw_list, is.null, logical(1))]
    raw_list <- raw_list[vapply(raw_list, function(x) nrow(x) > 0L, logical(1))]

    raw <- if (length(raw_list) == 0L) NULL else dplyr::bind_rows(raw_list)

    # De-duplicate batched results on the OpenAlex work id.
    if (!is.null(raw) && nrow(raw) > 0L && "id" %in% names(raw)) {
      raw <- raw[!duplicated(raw[["id"]]), , drop = FALSE]
    }

    if (is.null(raw) || nrow(raw) == 0) {
      .sm_verbose("No results from openalexR.", verbose)
      return(.empty_corpus_with_provenance("openalex", query, "openalexR"))
    }

    if (nrow(raw) > n_max) raw <- raw[seq_len(n_max), ]

    n <- nrow(raw)
    work_ids <- .generate_work_id(n)

    works <- tibble::tibble(
      work_id = work_ids,
      doi = .normalize_doi(raw[["doi"]] %||% rep(NA_character_, n)),
      title = raw[["display_name"]] %||% rep(NA_character_, n),
      abstract = raw[["abstract"]] %||% raw[["ab"]] %||%
        rep(NA_character_, n),
      year = as.integer(raw[["publication_year"]] %||% rep(NA_integer_, n)),
      type = raw[["type"]] %||% rep(NA_character_, n),
      source_id = NA_character_,
      cited_by_count = as.integer(raw[["cited_by_count"]] %||% rep(0L, n)),
      oa_status = raw[["oa_status"]] %||% rep(NA_character_, n),
      language = raw[["language"]] %||% rep(NA_character_, n),
      pmid = NA_character_,
      arxiv_id = NA_character_,
      openalex_id = raw[["id"]] %||% rep(NA_character_, n),
      is_retracted = raw[["is_retracted"]] %||% rep(FALSE, n),
      retraction_date = as.Date(NA),
      last_refreshed = Sys.time()
    )

    # openalexR keeps fwci and the yearly counts (a data frame per work)
    # but no percentile and no updated_date
    records <- lapply(seq_len(n), function(i) {
      list(fwci = raw[["fwci"]][i],
           counts_by_year = .openalexr_counts(raw[["counts_by_year"]][i]))
    })
    impact <- .openalex_impact_fields(records, work_ids, fetched = Sys.time())
    works <- dplyr::bind_cols(works, impact$works[-1])

    provenance <- .make_provenance_rows(
      work_ids, "openalex", works$openalex_id, query, "openalexR"
    )

    .sm_done("Parsed {n} OpenAlex works (via openalexR) into sm_corpus.")

    new_sm_corpus(
      works = works,
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      provenance = provenance,
      citations_by_year = impact$citations_by_year
    )
  }, error = function(e) {
    if (inherits(e, "scimapR_openalex_error")) stop(e)
    cli::cli_abort(
      c("openalexR fetch failed.",
        "i" = .sm_cli_escape(conditionMessage(e))),
      call = call
    )
  })
}

#' Restore an environment variable saved with `Sys.getenv(unset = NA)`
#' @noRd
.restore_envvar <- function(name, old) {
  if (is.na(old)) {
    Sys.unsetenv(name)
  } else {
    do.call(Sys.setenv, stats::setNames(list(old), name))
  }
  invisible(NULL)
}

#' The yearly counts of one openalexR row as OpenAlex records
#'
#' openalexR stores `counts_by_year` as a data frame per work (`year`,
#' `cited_by_count`), or `NA` when the work has none.
#' @noRd
.openalexr_counts <- function(cell) {
  df <- if (is.list(cell)) cell[[1]] else NULL
  if (!is.data.frame(df) || !all(c("year", "cited_by_count") %in% names(df))) {
    return(list())
  }
  lapply(seq_len(nrow(df)), function(j) {
    list(year = df$year[j], cited_by_count = df$cited_by_count[j])
  })
}

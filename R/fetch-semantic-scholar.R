#' Fetch works from Semantic Scholar
#'
#' @description
#' Query the [Semantic Scholar](https://www.semanticscholar.org/) Academic
#' Graph API for papers and return the results as an `sm_corpus`.
#'
#' Supports both keyword search (`query`) and batch paper lookup
#' (`paper_ids`). Optionally fetches pre-computed SPECTER embeddings.
#'
#' @param query Free-text search query. If `NULL`, `paper_ids` must be
#'   supplied.
#' @param paper_ids Character vector of Semantic Scholar paper IDs, DOIs
#'   (prefixed `DOI:`), arXiv IDs (prefixed `ARXIV:`), or PMIDs
#'   (prefixed `PMID:`). If `NULL`, `query` must be supplied.
#' @param n_max Maximum number of papers to return (default 100).
#' @param api_key Semantic Scholar API key. Read from
#'   `SEMANTIC_SCHOLAR_API_KEY` env var by default.
#' @param include_embeddings Logical; if `TRUE`, request SPECTER embeddings
#'   for each paper and attach as an embedding matrix.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object.
#'
#' @family fetchers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_fetch_semantic_scholar(query = "bibliometrics", n_max = 10)
#' print(corpus)
#' }
sm_fetch_semantic_scholar <- function(query = NULL,
                                      paper_ids = NULL,
                                      n_max = 100L,
                                      api_key = Sys.getenv("SEMANTIC_SCHOLAR_API_KEY"),
                                      include_embeddings = FALSE,
                                      verbose = TRUE,
                                      call = rlang::caller_env()) {
  n_max <- .check_positive_int(n_max, call = call)

  if (is.null(query) && is.null(paper_ids)) {
    cli::cli_abort(
      "At least one of {.arg query} or {.arg paper_ids} must be provided.",
      call = call
    )
  }

  if (!is.null(paper_ids)) {
    return(.fetch_s2_batch(
      paper_ids = paper_ids,
      api_key = api_key,
      include_embeddings = include_embeddings,
      verbose = verbose,
      call = call
    ))
  }

  # ---- search mode ----
  .sm_verbose("Searching Semantic Scholar for: {.val {query}}", verbose)

  fields <- paste(c(
    "paperId", "externalIds", "title", "abstract", "year", "venue",
    "publicationVenue", "citationCount", "isOpenAccess",
    "openAccessPdf", "authors", "references",
    if (include_embeddings) "embedding"
  ), collapse = ",")

  collected <- list()
  offset <- 0L
  limit_per <- min(100L, n_max)

  repeat {
    req <- httr2::request("https://api.semanticscholar.org/graph/v1/paper/search") |>
      httr2::req_url_query(
        query = query,
        fields = fields,
        offset = offset,
        limit = min(limit_per, n_max - length(collected))
      ) |>
      httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
      httr2::req_throttle(rate = 1 / 1)

    if (nzchar(api_key)) {
      req <- httr2::req_headers(req, `x-api-key` = api_key)
    }

    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        cli::cli_abort(
          c("Semantic Scholar API request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    body <- httr2::resp_body_json(resp)
    papers <- body[["data"]]

    if (length(papers) == 0L) break

    collected <- c(collected, papers)
    offset <- offset + length(papers)

    total <- body[["total"]] %||% n_max

    .sm_verbose(
      "Fetched {length(collected)} / {min(n_max, total)} papers.",
      verbose
    )

    if (length(collected) >= n_max || is.null(body[["next"]])) break
  }

  if (length(collected) == 0L) {
    .sm_verbose("No results found.", verbose)
    return(.empty_corpus_with_provenance("semantic_scholar", query, "native"))
  }

  .parse_s2_results(collected, query, include_embeddings, verbose, call)
}

# ---- internal helpers ----

#' @noRd
.fetch_s2_batch <- function(paper_ids, api_key, include_embeddings,
                            verbose, call) {
  .sm_verbose("Batch-fetching {length(paper_ids)} papers from Semantic Scholar...", verbose)

  fields <- paste(c(
    "paperId", "externalIds", "title", "abstract", "year", "venue",
    "publicationVenue", "citationCount", "isOpenAccess",
    "openAccessPdf", "authors", "references",
    if (include_embeddings) "embedding"
  ), collapse = ",")

  # S2 batch endpoint accepts up to 500 IDs per request
  batch_size <- 500L
  collected <- list()
  chunks <- split(paper_ids, ceiling(seq_along(paper_ids) / batch_size))

  for (chunk in chunks) {
    req <- httr2::request("https://api.semanticscholar.org/graph/v1/paper/batch") |>
      httr2::req_url_query(fields = fields) |>
      httr2::req_body_json(list(ids = as.list(chunk))) |>
      httr2::req_method("POST") |>
      httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
      httr2::req_throttle(rate = 1 / 1)

    if (nzchar(api_key)) {
      req <- httr2::req_headers(req, `x-api-key` = api_key)
    }

    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        cli::cli_abort(
          c("Semantic Scholar batch request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    body <- httr2::resp_body_json(resp)
    # Filter out NULL entries (papers not found)
    papers <- purrr::compact(body)
    collected <- c(collected, papers)

    .sm_verbose(
      "Batch-fetched {length(collected)} / {length(paper_ids)} papers.",
      verbose
    )
  }

  if (length(collected) == 0L) {
    .sm_verbose("No papers found.", verbose)
    return(.empty_corpus_with_provenance(
      "semantic_scholar",
      paste(paper_ids, collapse = ","),
      "native"
    ))
  }

  .parse_s2_results(
    collected,
    paste(paper_ids, collapse = ","),
    include_embeddings, verbose, call
  )
}

#' @noRd
.parse_s2_results <- function(results, query_text, include_embeddings,
                               verbose, call) {
  n <- length(results)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = purrr::map_chr(results, \(p) {
      .normalize_doi(p[["externalIds"]][["DOI"]] %||% NA_character_)
    }),
    title = purrr::map_chr(results, "title", .default = NA_character_),
    abstract = purrr::map_chr(results, "abstract", .default = NA_character_),
    year = as.integer(purrr::map_int(results, "year", .default = NA_integer_)),
    type = "journal-article",
    source_id = purrr::map_chr(results, \(p) {
      pv <- p[["publicationVenue"]]
      if (is.null(pv)) return(NA_character_)
      pv[["id"]] %||% NA_character_
    }),
    cited_by_count = as.integer(
      purrr::map_int(results, "citationCount", .default = 0L)
    ),
    oa_status = purrr::map_chr(results, \(p) {
      if (isTRUE(p[["isOpenAccess"]])) "open" else "closed"
    }),
    language = NA_character_,
    pmid = purrr::map_chr(results, \(p) {
      p[["externalIds"]][["PubMed"]] %||% NA_character_
    }),
    arxiv_id = purrr::map_chr(results, \(p) {
      p[["externalIds"]][["ArXiv"]] %||% NA_character_
    }),
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # ---- authors ----
  author_data <- .parse_s2_authors(results, work_ids)

  # ---- references ----
  references <- .parse_s2_references(results, work_ids)

  # ---- sources ----
  sources <- .parse_s2_sources(results)

  # ---- embeddings ----
  embeddings <- NULL
  if (include_embeddings) {
    emb_list <- purrr::map(results, \(p) {
      e <- p[["embedding"]][["vector"]]
      if (is.null(e)) return(NULL)
      as.double(e)
    })
    valid <- !purrr::map_lgl(emb_list, is.null)
    if (any(valid)) {
      emb_mat <- do.call(rbind, emb_list[valid])
      rownames(emb_mat) <- work_ids[valid]
      embeddings <- emb_mat
    }
  }

  # ---- provenance ----
  s2_ids <- purrr::map_chr(results, "paperId", .default = NA_character_)
  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = "semantic_scholar",
    external_ids = s2_ids,
    query_text = query_text,
    engine_name = "native"
  )

  .sm_done("Parsed {n} Semantic Scholar papers into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = author_data$authors,
    authorships = author_data$authorships,
    sources = sources,
    references = references,
    embeddings = embeddings,
    provenance = provenance
  )
}

#' @noRd
.parse_s2_authors <- function(results, work_ids) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(results)) {
    authors_raw <- results[[i]][["authors"]] %||% list()
    for (j in seq_along(authors_raw)) {
      a <- authors_raw[[j]]
      s2_id <- a[["authorId"]] %||% NA_character_
      name <- a[["name"]] %||% NA_character_
      if (is.na(s2_id) && is.na(name)) next

      key <- if (!is.na(s2_id)) s2_id else tolower(name)
      if (is.null(author_map[[key]])) {
        aid <- paste0("A", formatC(length(author_map) + 1L, width = 9, flag = "0"))
        author_map[[key]] <- list(
          author_id = aid,
          orcid = NA_character_,
          display_name = name
        )
      }

      authorship_rows[[length(authorship_rows) + 1L]] <- tibble::tibble(
        work_id = work_ids[i],
        author_id = author_map[[key]]$author_id,
        position = as.integer(j),
        is_corresponding = j == 1L,
        institution_id = NA_character_,
        raw_affiliation = NA_character_,
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
.parse_s2_references <- function(results, work_ids) {
  rows <- list()
  for (i in seq_along(results)) {
    refs <- results[[i]][["references"]] %||% list()
    if (length(refs) == 0) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      ref_index = seq_along(refs),
      cited_work_id = NA_character_,
      cited_doi = purrr::map_chr(refs, \(r) {
        .normalize_doi(r[["externalIds"]][["DOI"]] %||% NA_character_)
      }),
      cited_raw = purrr::map_chr(refs, "title", .default = NA_character_)
    )
  }
  if (length(rows) == 0) return(.empty_references())
  dplyr::bind_rows(rows)
}

#' @noRd
.parse_s2_sources <- function(results) {
  src_map <- list()
  for (p in results) {
    pv <- p[["publicationVenue"]]
    if (is.null(pv)) next
    sid <- pv[["id"]]
    if (is.null(sid) || sid %in% names(src_map)) next
    src_map[[sid]] <- list(
      source_id = sid,
      issn_l = pv[["issn"]] %||% NA_character_,
      issn = list(as.character(pv[["alternate_issns"]] %||% character())),
      display_name = pv[["name"]] %||% NA_character_,
      type = pv[["type"]] %||% NA_character_,
      is_oa = NA,
      publisher = NA_character_,
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

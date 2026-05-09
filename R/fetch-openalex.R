#' Fetch works from OpenAlex
#'
#' @description
#' Query the [OpenAlex](https://openalex.org/) API for scholarly works and
#' return the results as an `sm_corpus`.
#'
#' Supports both free-text search (`query`) and structured filter syntax
#' (`filter`). Uses cursor-based pagination to retrieve up to `n_max` works.
#' An API key (polite pool) and a `mailto` address are strongly recommended
#' for higher rate limits.
#'
#' @param query Free-text search query passed to the `search` parameter.
#'   If `NULL`, `filter` must be supplied.
#' @param filter A character string using OpenAlex filter syntax, e.g.
#'   `"from_publication_date:2020-01-01,type:journal-article"`.
#' @param n_max Maximum number of works to return (default 200).
#' @param per_page Number of results per page (max 200).
#' @param mailto Email address for the polite pool. Read from
#'   `SCIMAPR_MAILTO` env var by default.
#' @param api_key OpenAlex API key. Read from `OPENALEX_API_KEY` env var.
#' @param engine One of `"native"` (built-in httr2 client), `"openalexR"`
#'   (use the openalexR package), or `"auto"` (use openalexR if available,
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
                              verbose = TRUE,
                              call = rlang::caller_env()) {
  engine <- rlang::arg_match(engine, error_call = call)
  n_max <- .check_positive_int(n_max, call = call)
  per_page <- .check_positive_int(per_page, call = call)


  if (is.null(query) && is.null(filter)) {
    cli::cli_abort(
      "At least one of {.arg query} or {.arg filter} must be provided.",
      call = call
    )
  }

  if (engine == "auto") {
    engine <- if (rlang::is_installed("openalexR")) "openalexR" else "native"
  }

  if (engine == "openalexR") {
    return(.fetch_openalex_openalexR(
      query = query, filter = filter, n_max = n_max,
      mailto = mailto, verbose = verbose, call = call
    ))
  }

  # ---- native httr2 implementation ----
  .sm_verbose("Fetching works from OpenAlex...", verbose)

  per_page <- min(per_page, 200L)
  collected <- list()
  cursor <- "*"
  n_fetched <- 0L

  repeat {
    req <- httr2::request("https://api.openalex.org/works") |>
      httr2::req_url_query(per_page = min(per_page, n_max - n_fetched),
                           cursor = cursor) |>
      httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
      httr2::req_throttle(rate = 10 / 1)

    if (!is.null(query) && nzchar(query)) {
      req <- httr2::req_url_query(req, search = query)
    }
    if (!is.null(filter) && nzchar(filter)) {
      req <- httr2::req_url_query(req, filter = filter)
    }
    if (nzchar(mailto)) {
      req <- httr2::req_url_query(req, mailto = mailto)
    }
    if (nzchar(api_key)) {
      req <- httr2::req_headers(req, `Authorization` = paste("Bearer", api_key))
    }

    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        cli::cli_abort(
          c("OpenAlex API request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    body <- httr2::resp_body_json(resp)
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
         " (https://github.com/r-heller/scimapR)")
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

#' @noRd
.parse_openalex_results <- function(results, query_text, verbose, call) {
  n <- length(results)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = .normalize_doi(purrr::map_chr(results, "doi", .default = NA_character_)),
    title = purrr::map_chr(results, "title", .default = NA_character_),
    abstract = purrr::map_chr(results, .openalex_abstract, .default = NA_character_),
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
    provenance = provenance
  )
}

#' Reconstruct abstract from inverted index
#' @noRd
.openalex_abstract <- function(work) {
  inv <- work[["abstract_inverted_index"]]
  if (is.null(inv)) return(NA_character_)
  words <- names(inv)
  positions <- purrr::map(inv, as.integer)
  max_pos <- max(unlist(positions), na.rm = TRUE)
  out <- character(max_pos + 1L)

  for (i in seq_along(words)) {
    for (pos in positions[[i]]) {
      out[pos + 1L] <- words[i]
    }
  }
  paste(out[nzchar(out)], collapse = " ")
}

#' @noRd
.parse_openalex_authorships <- function(results, work_ids) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(results)) {
    aships <- results[[i]][["authorships"]] %||% list()
    for (j in seq_along(aships)) {
      a <- aships[[j]]
      au <- a[["author"]] %||% list()
      oa_author_id <- au[["id"]] %||% NA_character_
      if (is.na(oa_author_id)) next

      if (is.null(author_map[[oa_author_id]])) {
        aid <- paste0("A", formatC(length(author_map) + 1L, width = 9, flag = "0"))
        author_map[[oa_author_id]] <- list(
          author_id = aid,
          orcid = au[["orcid"]] %||% NA_character_,
          display_name = au[["display_name"]] %||% NA_character_
        )
      }

      inst <- a[["institutions"]]
      inst_id <- if (length(inst) > 0) inst[[1]][["id"]] %||% NA_character_ else NA_character_
      raw_aff <- a[["raw_affiliation_string"]] %||% NA_character_
      if (is.list(raw_aff)) raw_aff <- raw_aff[[1]] %||% NA_character_

      cc <- NA_character_
      if (length(inst) > 0) {
        cc <- inst[[1]][["country_code"]] %||% NA_character_
      }

      authorship_rows[[length(authorship_rows) + 1L]] <- tibble::tibble(
        work_id = work_ids[i],
        author_id = author_map[[oa_author_id]]$author_id,
        position = as.integer(j),
        is_corresponding = identical(a[["author_position"]], "first") && j == 1L,
        institution_id = inst_id,
        raw_affiliation = raw_aff,
        country_code = cc
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

#' @noRd
.fetch_openalex_openalexR <- function(query, filter, n_max, mailto,
                                      verbose, call) {
  rlang::check_installed("openalexR",
                         reason = "to use engine = 'openalexR'",
                         call = call)

  .sm_verbose("Fetching via openalexR...", verbose)

  if (nzchar(mailto)) {
    openalexR::oa_fetch
    opts <- list(mailto = mailto)
  }

  tryCatch({
    raw <- openalexR::oa_fetch(
      entity = "works",
      search = query,
      filter = if (!is.null(filter)) {
        # parse comma-sep key:value into named list
        parts <- strsplit(filter, ",")[[1]]
        kv <- strsplit(parts, ":")
        stats::setNames(
          purrr::map_chr(kv, 2),
          purrr::map_chr(kv, 1)
        )
      },
      count_only = FALSE,
      per_page = 200L,
      mailto = if (nzchar(mailto)) mailto else NULL,
      verbose = verbose
    )

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
      abstract = raw[["ab"]] %||% rep(NA_character_, n),
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

    provenance <- .make_provenance_rows(
      work_ids, "openalex", works$openalex_id, query, "openalexR"
    )

    .sm_done("Parsed {n} OpenAlex works (via openalexR) into sm_corpus.")

    new_sm_corpus(
      works = works,
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      provenance = provenance
    )
  }, error = function(e) {
    cli::cli_abort(
      c("openalexR fetch failed.",
        "i" = conditionMessage(e)),
      call = call
    )
  })
}

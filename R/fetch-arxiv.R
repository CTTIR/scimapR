#' Fetch works from arXiv
#'
#' @description
#' Query the [arXiv](https://arxiv.org/) API (Atom feed) for preprints and
#' return the results as an `sm_corpus`.
#'
#' Uses start/max_results pagination to retrieve up to `n_max` results.
#' The arXiv API is free and requires no authentication.
#'
#' @param query arXiv search query string using the arXiv query syntax.
#'   Supports `all:`, `ti:`, `au:`, `abs:`, `cat:`, etc.
#' @param n_max Maximum number of results to return (default 200).
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object.
#'
#' @family fetchers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_fetch_arxiv(query = "all:bibliometrics", n_max = 10)
#' print(corpus)
#' }
sm_fetch_arxiv <- function(query,
                           n_max = 200L,
                           verbose = TRUE,
                           call = rlang::caller_env()) {
  .check_string(query, call = call)
  n_max <- .check_positive_int(n_max, call = call)

  .sm_verbose("Fetching from arXiv: {.val {query}}", verbose)

  per_page <- 100L
  collected <- list()
  start <- 0L


  repeat {
    this_page <- min(per_page, n_max - length(collected))
    if (this_page <= 0L) break

    req <- httr2::request("https://export.arxiv.org/api/query") |>
      httr2::req_url_query(
        search_query = query,
        start = start,
        max_results = this_page
      ) |>
      httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
      httr2::req_throttle(rate = 1 / 3)

    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        cli::cli_abort(
          c("arXiv API request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    xml_doc <- xml2::read_xml(httr2::resp_body_string(resp))
    ns <- xml2::xml_ns(xml_doc)

    entries <- xml2::xml_find_all(xml_doc, ".//d1:entry", ns)
    if (length(entries) == 0L) break

    collected <- c(collected, entries)
    start <- start + length(entries)

    total_str <- xml2::xml_text(
      xml2::xml_find_first(xml_doc, ".//opensearch:totalResults", ns)
    )
    total <- if (!is.na(total_str)) as.integer(total_str) else n_max

    .sm_verbose(
      "Fetched {length(collected)} / {min(n_max, total)} arXiv entries.",
      verbose
    )

    if (length(collected) >= n_max || length(entries) < this_page) break
  }

  if (length(collected) == 0L) {
    .sm_verbose("No arXiv results found.", verbose)
    return(.empty_corpus_with_provenance("arxiv", query, "native"))
  }

  .parse_arxiv_results(collected, query, verbose, call)
}

# ---- internal helpers ----

#' @noRd
.parse_arxiv_results <- function(entries, query_text, verbose, call) {
  n <- length(entries)
  work_ids <- .generate_work_id(n)

  # arXiv Atom namespace
  ns <- c(
    d1 = "http://www.w3.org/2005/Atom",
    arxiv = "http://arxiv.org/schemas/atom"
  )

  works <- tibble::tibble(
    work_id = work_ids,
    doi = purrr::map_chr(entries, \(e) {
      doi_node <- xml2::xml_find_first(e, ".//arxiv:doi", ns)
      if (is.na(xml2::xml_text(doi_node))) NA_character_
      else .normalize_doi(xml2::xml_text(doi_node))
    }),
    title = purrr::map_chr(entries, \(e) {
      tt <- xml2::xml_text(xml2::xml_find_first(e, ".//d1:title", ns))
      trimws(gsub("\\s+", " ", tt %||% NA_character_))
    }),
    abstract = purrr::map_chr(entries, \(e) {
      ab <- xml2::xml_text(xml2::xml_find_first(e, ".//d1:summary", ns))
      trimws(gsub("\\s+", " ", ab %||% NA_character_))
    }),
    year = as.integer(purrr::map_chr(entries, \(e) {
      pub <- xml2::xml_text(xml2::xml_find_first(e, ".//d1:published", ns))
      if (is.na(pub)) NA_character_ else substr(pub, 1, 4)
    })),
    type = "preprint",
    source_id = NA_character_,
    cited_by_count = NA_integer_,
    oa_status = "gold",
    language = "en",
    pmid = NA_character_,
    arxiv_id = purrr::map_chr(entries, \(e) {
      id_url <- xml2::xml_text(xml2::xml_find_first(e, ".//d1:id", ns))
      if (is.na(id_url)) NA_character_
      else sub("^https?://arxiv\\.org/abs/", "", id_url)
    }),
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # ---- authors ----
  author_data <- .parse_arxiv_authors(entries, work_ids, ns)

  # ---- concepts (arXiv categories) ----
  concepts <- .parse_arxiv_categories(entries, work_ids, ns)

  # ---- provenance ----
  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = "arxiv",
    external_ids = works$arxiv_id,
    query_text = query_text,
    engine_name = "native"
  )

  .sm_done("Parsed {n} arXiv entries into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = author_data$authors,
    authorships = author_data$authorships,
    concepts = concepts,
    provenance = provenance
  )
}

#' @noRd
.parse_arxiv_authors <- function(entries, work_ids, ns) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(entries)) {
    author_nodes <- xml2::xml_find_all(entries[[i]], ".//d1:author", ns)
    for (j in seq_along(author_nodes)) {
      name <- xml2::xml_text(
        xml2::xml_find_first(author_nodes[[j]], ".//d1:name", ns)
      )
      if (is.na(name) || !nzchar(name)) next

      key <- tolower(name)
      if (is.null(author_map[[key]])) {
        aid <- paste0("A", formatC(length(author_map) + 1L, width = 9, flag = "0"))
        author_map[[key]] <- list(
          author_id = aid,
          orcid = NA_character_,
          display_name = name
        )
      }

      aff_node <- xml2::xml_find_first(
        author_nodes[[j]], ".//arxiv:affiliation", ns
      )
      raw_aff <- if (!is.na(xml2::xml_text(aff_node))) {
        xml2::xml_text(aff_node)
      } else {
        NA_character_
      }

      authorship_rows[[length(authorship_rows) + 1L]] <- tibble::tibble(
        work_id = work_ids[i],
        author_id = author_map[[key]]$author_id,
        position = as.integer(j),
        is_corresponding = j == 1L,
        institution_id = NA_character_,
        raw_affiliation = raw_aff,
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
.parse_arxiv_categories <- function(entries, work_ids, ns) {
  rows <- list()
  for (i in seq_along(entries)) {
    cat_nodes <- xml2::xml_find_all(entries[[i]], ".//d1:category", ns)
    if (length(cat_nodes) == 0) next
    terms <- xml2::xml_attr(cat_nodes, "term")
    terms <- terms[!is.na(terms)]
    if (length(terms) == 0) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      concept_id = terms,
      concept_name = terms,
      level = 0L,
      score = NA_real_,
      vocabulary = "arxiv"
    )
  }
  if (length(rows) == 0) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

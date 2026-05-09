#' Fetch works from PubMed
#'
#' @description
#' Query [PubMed](https://pubmed.ncbi.nlm.nih.gov/) via the NCBI E-utilities
#' (esearch + efetch) and return the results as an `sm_corpus`.
#'
#' Uses retmax/retstart pagination to retrieve up to `n_max` records.
#' Providing an NCBI API key allows up to 10 requests/second instead of 3.
#'
#' @param query PubMed search query string (required).
#' @param n_max Maximum number of records to return (default 200).
#' @param api_key NCBI API key. Read from `NCBI_API_KEY` env var by default.
#' @param engine One of `"native"` (built-in httr2 client), `"rentrez"`
#'   (use the rentrez package), or `"auto"` (use rentrez if available,
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
#' corpus <- sm_fetch_pubmed(query = "bibliometrics[tiab]", n_max = 10)
#' print(corpus)
#' }
sm_fetch_pubmed <- function(query,
                            n_max = 200L,
                            api_key = Sys.getenv("NCBI_API_KEY"),
                            engine = c("native", "rentrez", "auto"),
                            verbose = TRUE,
                            call = rlang::caller_env()) {
  .check_string(query, call = call)
  engine <- rlang::arg_match(engine, error_call = call)
  n_max <- .check_positive_int(n_max, call = call)

  if (engine == "auto") {
    engine <- if (rlang::is_installed("rentrez")) "rentrez" else "native"
  }

  if (engine == "rentrez") {
    return(.fetch_pubmed_rentrez(
      query = query, n_max = n_max, api_key = api_key,
      verbose = verbose, call = call
    ))
  }

  # ---- native httr2: esearch to get PMIDs ----
  .sm_verbose("Searching PubMed for: {.val {query}}", verbose)

  rate <- if (nzchar(api_key)) 10 / 1 else 3 / 1

  search_req <- httr2::request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi") |>
    httr2::req_url_query(
      db = "pubmed",
      term = query,
      retmax = n_max,
      retmode = "json",
      usehistory = "y"
    ) |>
    httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
    httr2::req_throttle(rate = rate)

  if (nzchar(api_key)) {
    search_req <- httr2::req_url_query(search_req, api_key = api_key)
  }

  search_resp <- tryCatch(
    httr2::req_perform(search_req),
    error = function(e) {
      cli::cli_abort(
        c("PubMed esearch request failed.",
          "i" = conditionMessage(e)),
        call = call
      )
    }
  )

  search_body <- httr2::resp_body_json(search_resp)
  result <- search_body[["esearchresult"]]
  count <- as.integer(result[["count"]] %||% 0L)
  webenv <- result[["webenv"]]
  query_key <- result[["querykey"]]
  pmids <- as.character(result[["idlist"]] %||% character())

  if (length(pmids) == 0L) {
    .sm_verbose("No PubMed results found.", verbose)
    return(.empty_corpus_with_provenance("pubmed", query, "native"))
  }

  .sm_verbose("Found {count} results; fetching {length(pmids)} records.", verbose)

  # ---- efetch to get full records (XML) ----
  retmax_page <- 500L
  all_articles <- list()
  retstart <- 0L

  while (retstart < length(pmids)) {
    fetch_req <- httr2::request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi") |>
      httr2::req_url_query(
        db = "pubmed",
        query_key = query_key,
        WebEnv = webenv,
        retstart = retstart,
        retmax = min(retmax_page, length(pmids) - retstart),
        rettype = "xml",
        retmode = "xml"
      ) |>
      httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
      httr2::req_throttle(rate = rate)

    if (nzchar(api_key)) {
      fetch_req <- httr2::req_url_query(fetch_req, api_key = api_key)
    }

    fetch_resp <- tryCatch(
      httr2::req_perform(fetch_req),
      error = function(e) {
        cli::cli_abort(
          c("PubMed efetch request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    xml_doc <- xml2::read_xml(httr2::resp_body_string(fetch_resp))
    articles <- xml2::xml_find_all(xml_doc, ".//PubmedArticle")
    all_articles <- c(all_articles, articles)

    retstart <- retstart + retmax_page

    .sm_verbose(
      "Fetched {length(all_articles)} / {length(pmids)} PubMed records.",
      verbose
    )
  }

  .parse_pubmed_results(all_articles, query, verbose, call)
}


# ---- internal helpers ----

#' @noRd
.parse_pubmed_results <- function(articles, query_text, verbose, call) {
  n <- length(articles)
  if (n == 0L) {
    return(.empty_corpus_with_provenance("pubmed", query_text, "native"))
  }

  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = purrr::map_chr(articles, .pubmed_doi),
    title = purrr::map_chr(articles, \(a) {
      xml2::xml_text(xml2::xml_find_first(a, ".//ArticleTitle")) %||% NA_character_
    }),
    abstract = purrr::map_chr(articles, \(a) {
      abs_nodes <- xml2::xml_find_all(a, ".//AbstractText")
      if (length(abs_nodes) == 0) return(NA_character_)
      paste(xml2::xml_text(abs_nodes), collapse = " ")
    }),
    year = as.integer(purrr::map_chr(articles, \(a) {
      y <- xml2::xml_text(xml2::xml_find_first(a, ".//PubDate/Year"))
      if (is.na(y) || !nzchar(y)) {
        y <- xml2::xml_text(xml2::xml_find_first(a, ".//PubDate/MedlineDate"))
        if (!is.na(y)) y <- substr(y, 1, 4)
      }
      y %||% NA_character_
    })),
    type = "journal-article",
    source_id = purrr::map_chr(articles, \(a) {
      xml2::xml_text(xml2::xml_find_first(a, ".//ISSNLinking")) %||% NA_character_
    }),
    cited_by_count = NA_integer_,
    oa_status = NA_character_,
    language = purrr::map_chr(articles, \(a) {
      xml2::xml_text(xml2::xml_find_first(a, ".//Language")) %||% NA_character_
    }),
    pmid = purrr::map_chr(articles, \(a) {
      xml2::xml_text(xml2::xml_find_first(a, ".//PMID")) %||% NA_character_
    }),
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # ---- authors ----
  author_data <- .parse_pubmed_authors(articles, work_ids)

  # ---- MeSH concepts ----
  concepts <- .parse_pubmed_mesh(articles, work_ids)

  # ---- sources ----
  sources <- .parse_pubmed_sources(articles)

  # ---- provenance ----
  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = "pubmed",
    external_ids = works$pmid,
    query_text = query_text,
    engine_name = "native"
  )

  .sm_done("Parsed {n} PubMed records into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = author_data$authors,
    authorships = author_data$authorships,
    sources = sources,
    concepts = concepts,
    provenance = provenance
  )
}

#' @noRd
.pubmed_doi <- function(article) {
  ids <- xml2::xml_find_all(article, ".//ArticleId[@IdType='doi']")
  if (length(ids) == 0) return(NA_character_)
  .normalize_doi(xml2::xml_text(ids[[1]]))
}

#' @noRd
.parse_pubmed_authors <- function(articles, work_ids) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(articles)) {
    author_nodes <- xml2::xml_find_all(articles[[i]], ".//Author")
    for (j in seq_along(author_nodes)) {
      node <- author_nodes[[j]]
      last <- xml2::xml_text(xml2::xml_find_first(node, "LastName"))
      fore <- xml2::xml_text(xml2::xml_find_first(node, "ForeName"))
      if (is.na(last) && is.na(fore)) next

      name <- trimws(paste(fore %||% "", last %||% ""))

      orcid_node <- xml2::xml_find_first(node, ".//Identifier[@Source='ORCID']")
      orcid_val <- if (!is.na(xml2::xml_text(orcid_node))) {
        sub("^https?://orcid\\.org/", "", xml2::xml_text(orcid_node))
      } else {
        NA_character_
      }

      key <- if (!is.na(orcid_val)) orcid_val else tolower(name)
      if (is.null(author_map[[key]])) {
        aid <- paste0("A", formatC(length(author_map) + 1L, width = 9, flag = "0"))
        author_map[[key]] <- list(
          author_id = aid,
          orcid = orcid_val,
          display_name = name
        )
      }

      aff_nodes <- xml2::xml_find_all(node, ".//Affiliation")
      raw_aff <- if (length(aff_nodes) > 0) {
        paste(xml2::xml_text(aff_nodes), collapse = "; ")
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
.parse_pubmed_mesh <- function(articles, work_ids) {
  rows <- list()
  for (i in seq_along(articles)) {
    mesh_nodes <- xml2::xml_find_all(articles[[i]], ".//MeshHeading/DescriptorName")
    if (length(mesh_nodes) == 0) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      concept_id = xml2::xml_attr(mesh_nodes, "UI"),
      concept_name = xml2::xml_text(mesh_nodes),
      level = NA_integer_,
      score = NA_real_,
      vocabulary = "mesh"
    )
  }
  if (length(rows) == 0) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

#' @noRd
.parse_pubmed_sources <- function(articles) {
  src_map <- list()
  for (a in articles) {
    issn <- xml2::xml_text(xml2::xml_find_first(a, ".//ISSNLinking"))
    if (is.na(issn) || !nzchar(issn)) next
    if (issn %in% names(src_map)) next
    journal_title <- xml2::xml_text(xml2::xml_find_first(a, ".//Title"))
    src_map[[issn]] <- list(
      source_id = issn,
      issn_l = issn,
      issn = list(issn),
      display_name = journal_title %||% NA_character_,
      type = "journal",
      is_oa = NA,
      publisher = NA_character_,
      publisher_country = xml2::xml_text(
        xml2::xml_find_first(a, ".//MedlineJournalInfo/Country")
      ) %||% NA_character_
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
.fetch_pubmed_rentrez <- function(query, n_max, api_key, verbose, call) {
  rlang::check_installed("rentrez",
                         reason = "to use engine = 'rentrez'",
                         call = call)

  .sm_verbose("Fetching via rentrez...", verbose)

  if (nzchar(api_key)) {
    rentrez::set_entrez_key(api_key)
  }

  tryCatch({
    search_res <- rentrez::entrez_search(
      db = "pubmed",
      term = query,
      retmax = n_max,
      use_history = TRUE
    )

    if (search_res$count == 0 || length(search_res$ids) == 0) {
      .sm_verbose("No results from rentrez.", verbose)
      return(.empty_corpus_with_provenance("pubmed", query, "rentrez"))
    }

    pmids <- search_res$ids
    n <- length(pmids)

    # Fetch in batches
    retmax_page <- 500L
    all_xml <- character()
    for (start in seq(0, n - 1, by = retmax_page)) {
      chunk <- rentrez::entrez_fetch(
        db = "pubmed",
        web_history = search_res$web_history,
        rettype = "xml",
        retmax = min(retmax_page, n - start),
        retstart = start
      )
      all_xml <- c(all_xml, chunk)
    }

    xml_combined <- xml2::read_xml(paste(all_xml, collapse = "\n"))
    articles <- xml2::xml_find_all(xml_combined, ".//PubmedArticle")

    .parse_pubmed_results(articles, query, verbose, call)
  }, error = function(e) {
    cli::cli_abort(
      c("rentrez fetch failed.",
        "i" = conditionMessage(e)),
      call = call
    )
  })
}

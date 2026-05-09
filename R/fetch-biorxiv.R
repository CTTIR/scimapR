#' Fetch works from bioRxiv/medRxiv
#'
#' @description
#' Query the [bioRxiv](https://www.biorxiv.org/) or
#' [medRxiv](https://www.medrxiv.org/) API for preprints and return the
#' results as an `sm_corpus`.
#'
#' The API provides date-range-based content retrieval. If `query` is
#' supplied, results are filtered locally by title/abstract matching.
#'
#' @param query Optional search string for local filtering of results.
#' @param server One of `"biorxiv"` or `"medrxiv"`.
#' @param from_date Start date in `"YYYY-MM-DD"` format. Defaults to
#'   30 days ago.
#' @param to_date End date in `"YYYY-MM-DD"` format. Defaults to today.
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
#' corpus <- sm_fetch_biorxiv(
#'   from_date = "2024-01-01",
#'   to_date = "2024-01-07",
#'   n_max = 10
#' )
#' print(corpus)
#' }
sm_fetch_biorxiv <- function(query = NULL,
                             server = c("biorxiv", "medrxiv"),
                             from_date = NULL,
                             to_date = NULL,
                             n_max = 200L,
                             verbose = TRUE,
                             call = rlang::caller_env()) {
  server <- rlang::arg_match(server, error_call = call)
  n_max <- .check_positive_int(n_max, call = call)

  if (is.null(from_date)) from_date <- format(Sys.Date() - 30, "%Y-%m-%d")
  if (is.null(to_date)) to_date <- format(Sys.Date(), "%Y-%m-%d")

  .sm_verbose(
    "Fetching from {server} ({from_date} to {to_date})...",
    verbose
  )

  base_url <- paste0(
    "https://api.biorxiv.org/details/", server, "/",
    from_date, "/", to_date
  )

  collected <- list()
  cursor <- 0L

  repeat {
    req <- httr2::request(paste0(base_url, "/", cursor)) |>
      httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
      httr2::req_throttle(rate = 2 / 1)

    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        cli::cli_abort(
          c("{server} API request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    body <- httr2::resp_body_json(resp)
    items <- body[["collection"]]

    if (length(items) == 0L) break

    collected <- c(collected, items)
    cursor <- cursor + length(items)

    total <- as.integer(body[["messages"]][[1]][["total"]] %||% n_max)

    .sm_verbose(
      "Fetched {length(collected)} / {min(n_max, total)} {server} preprints.",
      verbose
    )

    if (length(collected) >= n_max || length(items) < 100L) break
  }

  if (length(collected) == 0L) {
    .sm_verbose("No results found.", verbose)
    return(.empty_corpus_with_provenance(server, query, "native"))
  }

  # Local filtering if query is provided
  if (!is.null(query) && nzchar(query)) {
    pattern <- tolower(query)
    collected <- purrr::keep(collected, \(item) {
      title <- tolower(item[["title"]] %||% "")
      abstract <- tolower(item[["abstract"]] %||% "")
      grepl(pattern, title, fixed = TRUE) ||
        grepl(pattern, abstract, fixed = TRUE)
    })
    .sm_verbose(
      "Filtered to {length(collected)} results matching query.",
      verbose
    )
  }

  if (length(collected) > n_max) {
    collected <- collected[seq_len(n_max)]
  }

  if (length(collected) == 0L) {
    .sm_verbose("No results after filtering.", verbose)
    return(.empty_corpus_with_provenance(server, query, "native"))
  }

  .parse_biorxiv_results(collected, server, query, verbose, call)
}

# ---- internal helpers ----

#' @noRd
.parse_biorxiv_results <- function(items, server, query_text, verbose, call) {
  n <- length(items)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = .normalize_doi(purrr::map_chr(items, "doi", .default = NA_character_)),
    title = purrr::map_chr(items, "title", .default = NA_character_),
    abstract = purrr::map_chr(items, "abstract", .default = NA_character_),
    year = as.integer(purrr::map_chr(items, \(x) {
      d <- x[["date"]]
      if (is.null(d) || !nzchar(d)) NA_character_ else substr(d, 1, 4)
    })),
    type = "preprint",
    source_id = NA_character_,
    cited_by_count = NA_integer_,
    oa_status = "gold",
    language = "en",
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # ---- authors ----
  author_data <- .parse_biorxiv_authors(items, work_ids)

  # ---- concepts (categories) ----
  concepts <- .parse_biorxiv_categories(items, work_ids, server)

  # ---- provenance ----
  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = server,
    external_ids = works$doi,
    query_text = query_text,
    engine_name = "native"
  )

  .sm_done("Parsed {n} {server} preprints into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = author_data$authors,
    authorships = author_data$authorships,
    concepts = concepts,
    provenance = provenance
  )
}

#' @noRd
.parse_biorxiv_authors <- function(items, work_ids) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(items)) {
    authors_str <- items[[i]][["authors"]] %||% ""
    if (!nzchar(authors_str)) next

    # Authors are semicolon-separated in bioRxiv API
    names_vec <- trimws(strsplit(authors_str, ";")[[1]])
    names_vec <- names_vec[nzchar(names_vec)]

    for (j in seq_along(names_vec)) {
      name <- names_vec[j]
      key <- tolower(name)

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
.parse_biorxiv_categories <- function(items, work_ids, server) {
  rows <- list()
  for (i in seq_along(items)) {
    cat <- items[[i]][["category"]] %||% NA_character_
    if (is.na(cat) || !nzchar(cat)) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      concept_id = cat,
      concept_name = cat,
      level = 0L,
      score = NA_real_,
      vocabulary = server
    )
  }
  if (length(rows) == 0) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

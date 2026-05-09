#' Fetch policy citations from Overton
#'
#' @description
#' Search the [Overton](https://www.overton.io/) API for policy document
#' citations of scholarly works and return the results as an `sm_corpus`.
#'
#' Requires an Overton API key (set via the `OVERTON_API_KEY` environment
#' variable).
#'
#' @param query Search query string.
#' @param api_key Overton API key. Read from `OVERTON_API_KEY` env var.
#' @param n_max Maximum number of results to return (default 100).
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object.
#'
#' @family fetchers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_fetch_overton(query = "climate change policy", n_max = 10)
#' print(corpus)
#' }
sm_fetch_overton <- function(query,
                             api_key = Sys.getenv("OVERTON_API_KEY"),
                             n_max = 100L,
                             verbose = TRUE,
                             call = rlang::caller_env()) {
  .check_string(query, call = call)
  n_max <- .check_positive_int(n_max, call = call)

  if (!nzchar(api_key)) {
    cli::cli_abort(
      c("Overton API key is required.",
        "i" = "Set the {.envvar OVERTON_API_KEY} environment variable."),
      call = call
    )
  }

  .sm_verbose("Searching Overton for: {.val {query}}", verbose)

  per_page <- min(50L, n_max)
  collected <- list()
  page <- 1L

  repeat {
    req <- httr2::request("https://app.overton.io/api/search") |>
      httr2::req_url_query(
        query = query,
        page = page,
        per_page = per_page
      ) |>
      httr2::req_headers(
        `Authorization` = paste("Bearer", api_key),
        `User-Agent` = .sm_user_agent()
      ) |>
      httr2::req_throttle(rate = 5 / 1)

    resp <- tryCatch(
      httr2::req_perform(req),
      error = function(e) {
        cli::cli_abort(
          c("Overton API request failed.",
            "i" = conditionMessage(e)),
          call = call
        )
      }
    )

    body <- httr2::resp_body_json(resp)
    items <- body[["results"]] %||% list()

    if (length(items) == 0L) break

    collected <- c(collected, items)
    page <- page + 1L

    total <- as.integer(body[["total"]] %||% n_max)

    .sm_verbose(
      "Fetched {length(collected)} / {min(n_max, total)} Overton results.",
      verbose
    )

    if (length(collected) >= n_max || length(items) < per_page) break
  }

  if (length(collected) == 0L) {
    .sm_verbose("No Overton results found.", verbose)
    return(.empty_corpus_with_provenance("overton", query, "native"))
  }

  if (length(collected) > n_max) {
    collected <- collected[seq_len(n_max)]
  }

  .parse_overton_results(collected, query, verbose, call)
}

# ---- internal helpers ----

#' @noRd
.parse_overton_results <- function(items, query_text, verbose, call) {
  n <- length(items)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id = work_ids,
    doi = .normalize_doi(purrr::map_chr(items, "doi", .default = NA_character_)),
    title = purrr::map_chr(items, "title", .default = NA_character_),
    abstract = purrr::map_chr(items, "abstract", .default = NA_character_),
    year = as.integer(purrr::map_chr(items, \(x) {
      y <- x[["year"]] %||% x[["publication_year"]]
      if (is.null(y)) NA_character_ else as.character(y)
    })),
    type = purrr::map_chr(items, "type", .default = "policy-document"),
    source_id = purrr::map_chr(items, "source", .default = NA_character_),
    cited_by_count = as.integer(
      purrr::map_int(items, "policy_citation_count", .default = 0L)
    ),
    oa_status = NA_character_,
    language = NA_character_,
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  # ---- authors ----
  author_data <- .parse_overton_authors(items, work_ids)

  # ---- provenance ----
  overton_ids <- purrr::map_chr(items, "id", .default = NA_character_)
  provenance <- .make_provenance_rows(
    work_ids = work_ids,
    source_name = "overton",
    external_ids = overton_ids,
    query_text = query_text,
    engine_name = "native"
  )

  .sm_done("Parsed {n} Overton results into sm_corpus.")

  new_sm_corpus(
    works = works,
    authors = author_data$authors,
    authorships = author_data$authorships,
    provenance = provenance
  )
}

#' @noRd
.parse_overton_authors <- function(items, work_ids) {
  author_map <- list()
  authorship_rows <- list()

  for (i in seq_along(items)) {
    authors_raw <- items[[i]][["authors"]] %||% list()
    if (is.character(authors_raw)) {
      # Sometimes authors come as a single string
      authors_raw <- as.list(trimws(strsplit(authors_raw, ";|,")[[1]]))
    }

    for (j in seq_along(authors_raw)) {
      name <- if (is.list(authors_raw[[j]])) {
        authors_raw[[j]][["name"]] %||% NA_character_
      } else {
        as.character(authors_raw[[j]])
      }
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

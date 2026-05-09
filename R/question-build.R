#' Build a corpus from a research question
#'
#' @description
#' Takes a structured [sm_question()] object, translates its fields into
#' database-specific query strings, fetches results from the requested
#' bibliographic sources, deduplicates on DOI, and returns an `sm_corpus`
#' with `metadata$question_id` linked to the question.
#'
#' This function requires the appropriate API-client packages to be installed
#' for each source (`openalexR` for OpenAlex, `rcrossref` for Crossref,
#' `rentrez` for PubMed).
#'
#' @param question An `sm_question` object created with [sm_question()].
#' @param sources Character vector of sources to query. Subset of
#'   `"pubmed"`, `"openalex"`, `"crossref"`.
#' @param n_max Integer. Maximum total number of works to retrieve
#'   (across all sources, before deduplication). Default `1000`.
#' @param verbose Logical. Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` with `metadata$question_id` set to the
#'   question's content-hash ID.
#'
#' @family question
#' @export
#' @examples
#' q <- sm_question(
#'   text = "Does immunotherapy improve survival in melanoma?",
#'   framework = "PICO",
#'   population = "melanoma",
#'   intervention = "immunotherapy",
#'   outcome = "survival"
#' )
#' # Would query live APIs:
#' # corpus <- sm_corpus_for_question(q)
sm_corpus_for_question <- function(question,
                                   sources = c("pubmed", "openalex",
                                               "crossref"),
                                   n_max = 1000L,
                                   verbose = TRUE,
                                   call = rlang::caller_env()) {
  if (!is_sm_question(question)) {
    cli::cli_abort(
      "{.arg question} must be an {.cls sm_question} object.",
      call = call
    )
  }

  sources <- match.arg(sources, several.ok = TRUE)
  n_max <- .check_positive_int(n_max, call = call)
  n_per_source <- ceiling(n_max / length(sources))

  .sm_verbose(
    "Building corpus for question {.val {question$id}} from {length(sources)} source{?s}.",
    verbose
  )

  all_works <- list()
  all_prov <- list()
  pkg_version <- tryCatch(
    as.character(utils::packageVersion("scimapR")),
    error = function(e) "0.1.0"
  )

  for (src in sources) {
    .sm_verbose("Querying {.val {src}}...", verbose)

    result <- tryCatch(
      .fetch_from_source(
        source = src,
        query_strings = question$query_strings,
        n_max = n_per_source,
        languages = question$languages,
        call = call
      ),
      error = function(e) {
        cli::cli_inform(c(
          "!" = "Failed to fetch from {.val {src}}: {conditionMessage(e)}"
        ))
        list(works = .empty_works(), n_fetched = 0L)
      }
    )

    if (nrow(result$works) > 0L) {
      # Assign work IDs
      existing_ids <- unlist(lapply(all_works, function(w) w$work_id))
      start_num <- length(existing_ids)
      new_ids <- paste0("W", formatC(
        seq(start_num + 1L, start_num + nrow(result$works)),
        width = 9, flag = "0"
      ))
      result$works$work_id <- new_ids

      all_works[[src]] <- result$works

      all_prov[[src]] <- tibble::tibble(
        work_id = new_ids,
        source = src,
        source_id_external = result$works$openalex_id %||% NA_character_,
        fetch_date = Sys.time(),
        query = question$query_strings[[src]] %||%
          question$query_strings$generic,
        engine = "native",
        scimapR_version = pkg_version,
        prompt_hash = NA_character_
      )
    }

    .sm_verbose(
      "  Retrieved {nrow(result$works)} work{?s} from {.val {src}}.",
      verbose
    )
  }

  if (length(all_works) == 0L) {
    .sm_verbose("No works retrieved from any source.", verbose)
    return(sm_corpus(
      works = .empty_works(),
      metadata = list(question_id = question$id)
    ))
  }

  # Combine and deduplicate
  combined_works <- dplyr::bind_rows(all_works)
  combined_prov <- dplyr::bind_rows(all_prov)

  # Deduplicate on DOI
  dedup_result <- .deduplicate_works(combined_works)
  keep_ids <- dedup_result$work_id

  combined_works <- dplyr::filter(combined_works, .data$work_id %in% keep_ids)
  combined_prov <- dplyr::filter(combined_prov, .data$work_id %in% keep_ids)

  n_dupes <- nrow(dplyr::bind_rows(all_works)) - nrow(combined_works)
  .sm_verbose(
    "Deduplicated: removed {n_dupes} duplicate{?s}. {nrow(combined_works)} unique work{?s} remain.",
    verbose
  )

  # Enforce n_max
  if (nrow(combined_works) > n_max) {
    combined_works <- utils::head(combined_works, n_max)
    keep_ids <- combined_works$work_id
    combined_prov <- dplyr::filter(combined_prov, .data$work_id %in% keep_ids)
  }

  corpus <- sm_corpus(
    works = combined_works,
    provenance = combined_prov,
    metadata = list(question_id = question$id)
  )

  .sm_verbose(
    "Corpus built: {nrow(corpus$works)} works from {length(sources)} source{?s}.",
    verbose
  )

  corpus
}

#' Fetch works from a bibliographic source
#' @noRd
.fetch_from_source <- function(source, query_strings, n_max, languages,
                               call = rlang::caller_env()) {
  query <- query_strings[[source]] %||% query_strings$generic

  if (source == "openalex") {
    .check_installed_soft("openalexR",
      reason = "to fetch from OpenAlex",
      call = call
    )
    result <- openalexR::oa_fetch(
      entity = "works",
      search = query,
      count_only = FALSE,
      verbose = FALSE
    )
    works <- .openalex_to_works(result, n_max)
  } else if (source == "pubmed") {
    .check_installed_soft("rentrez",
      reason = "to fetch from PubMed",
      call = call
    )
    search_result <- rentrez::entrez_search(
      db = "pubmed",
      term = query,
      retmax = n_max
    )
    if (length(search_result$ids) == 0L) {
      return(list(works = .empty_works(), n_fetched = 0L))
    }
    works <- .pubmed_ids_to_works(search_result$ids)
  } else if (source == "crossref") {
    .check_installed_soft("rcrossref",
      reason = "to fetch from Crossref",
      call = call
    )
    result <- rcrossref::cr_works(
      query = query,
      limit = min(n_max, 1000L)
    )
    works <- .crossref_to_works(result$data)
  } else {
    cli::cli_abort("Unknown source: {.val {source}}.", call = call)
  }

  list(works = works, n_fetched = nrow(works))
}

#' Convert OpenAlex results to works tibble
#' @noRd
.openalex_to_works <- function(result, n_max) {
  if (is.null(result) || nrow(result) == 0L) return(.empty_works())

  result <- utils::head(result, n_max)

  tibble::tibble(
    work_id = NA_character_,
    doi = .normalize_doi(result$doi %||% rep(NA_character_, nrow(result))),
    title = result$display_name %||% rep(NA_character_, nrow(result)),
    abstract = result$ab %||% rep(NA_character_, nrow(result)),
    year = as.integer(result$publication_year %||%
                        rep(NA_integer_, nrow(result))),
    type = result$type %||% rep(NA_character_, nrow(result)),
    source_id = NA_character_,
    cited_by_count = as.integer(
      result$cited_by_count %||% rep(NA_integer_, nrow(result))
    ),
    oa_status = result$oa_status %||% rep(NA_character_, nrow(result)),
    language = result$language %||% rep(NA_character_, nrow(result)),
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = result$id %||% rep(NA_character_, nrow(result)),
    is_retracted = result$is_retracted %||% rep(FALSE, nrow(result)),
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
}

#' Convert PubMed IDs to works tibble
#' @noRd
.pubmed_ids_to_works <- function(pmids) {
  if (length(pmids) == 0L) return(.empty_works())

  summaries <- tryCatch(
    rentrez::entrez_summary(db = "pubmed", id = pmids),
    error = function(e) NULL
  )

  if (is.null(summaries)) return(.empty_works())

  # Handle single vs multiple results
  if (inherits(summaries, "esummary")) {
    summaries <- list(summaries)
  }

  rows <- lapply(summaries, function(s) {
    tibble::tibble(
      work_id = NA_character_,
      doi = .normalize_doi(s$elocationid %||% NA_character_),
      title = s$title %||% NA_character_,
      abstract = NA_character_,
      year = as.integer(substr(s$pubdate %||% "", 1, 4)),
      type = "journal-article",
      source_id = NA_character_,
      cited_by_count = NA_integer_,
      oa_status = NA_character_,
      language = NA_character_,
      pmid = s$uid %||% NA_character_,
      arxiv_id = NA_character_,
      openalex_id = NA_character_,
      is_retracted = FALSE,
      retraction_date = as.Date(NA),
      last_refreshed = Sys.time()
    )
  })

  dplyr::bind_rows(rows)
}

#' Convert Crossref results to works tibble
#' @noRd
.crossref_to_works <- function(data) {
  if (is.null(data) || nrow(data) == 0L) return(.empty_works())

  tibble::tibble(
    work_id = NA_character_,
    doi = .normalize_doi(data$doi %||% rep(NA_character_, nrow(data))),
    title = data$title %||% rep(NA_character_, nrow(data)),
    abstract = NA_character_,
    year = as.integer(
      data$published.print %||% data$issued %||%
        rep(NA_character_, nrow(data))
    ),
    type = data$type %||% rep(NA_character_, nrow(data)),
    source_id = NA_character_,
    cited_by_count = as.integer(
      data$is.referenced.by.count %||% rep(NA_integer_, nrow(data))
    ),
    oa_status = NA_character_,
    language = data$language %||% rep(NA_character_, nrow(data)),
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
}

#' Deduplicate works by DOI
#' @noRd
.deduplicate_works <- function(works) {
  if (nrow(works) == 0L) return(works)

  # Keep first occurrence for each non-NA DOI
  has_doi <- !is.na(works$doi) & nzchar(works$doi)
  doi_works <- works[has_doi, ]
  no_doi_works <- works[!has_doi, ]

  if (nrow(doi_works) > 0L) {
    doi_works <- dplyr::distinct(doi_works, .data$doi, .keep_all = TRUE)
  }

  dplyr::bind_rows(doi_works, no_doi_works)
}

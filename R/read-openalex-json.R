#' Read OpenAlex JSON files
#'
#' @description
#' Parse OpenAlex JSON export files into an `sm_corpus` object. Handles
#' both JSON arrays of works and newline-delimited JSON (JSONL) files.
#' Extracts fields from the OpenAlex works schema including id, doi, title,
#' publication year, type, cited_by_count, authorships, host venue,
#' concepts, open access status, and referenced works.
#'
#' @param path Character scalar. Path to a `.json` or `.jsonl` file.
#' @param encoding Character scalar. File encoding (default `"UTF-8"`).
#' @param verbose Logical. Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An [sm_corpus] object.
#'
#' @section Implementation:
#' The parser reads the OpenAlex works JSON schema as documented at
#' \url{https://developers.openalex.org/api-entities/works/work-object}.
#' Both standard JSON arrays and newline-delimited JSON (one work per line)
#' are supported. No bibliometrix engine is available since OpenAlex is not
#' a shared bibliometric export format.
#'
#' @references
#' Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
#' comprehensive science mapping analysis. *Journal of Informetrics*,
#' 11(4), 959--975. \doi{10.1016/j.joi.2017.08.007}
#'
#' @family readers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_read_openalex_json("openalex_works.json")
#' corpus$works
#' }
sm_read_openalex_json <- function(path,
                                  encoding = "UTF-8",
                                  verbose = TRUE,
                                  call = rlang::caller_env()) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.file {path}}", call = call)
  }

  .sm_verbose("Reading OpenAlex JSON: {.file {path}}", verbose)

  # Read and parse JSON - support both array and JSONL
  raw <- readr::read_file(path, locale = readr::locale(encoding = encoding))
  raw <- trimws(raw)

  works_list <- if (startsWith(raw, "[")) {
    # Standard JSON array
    jsonlite::fromJSON(raw, simplifyVector = FALSE)
  } else if (startsWith(raw, "{")) {
    # Might be a single object or JSONL
    lines <- readr::read_lines(path,
      locale = readr::locale(encoding = encoding))
    lines <- lines[nzchar(trimws(lines))]
    lapply(lines, function(l) jsonlite::fromJSON(l, simplifyVector = FALSE))
  } else {
    cli::cli_abort(
      "Cannot parse OpenAlex JSON: file does not start with '[' or '{{'}.",
      call = call
    )
  }

  if (length(works_list) == 0L) {
    .sm_verbose("No OpenAlex works found.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_openalex_json")
    ))
  }

  # If the JSON had a top-level "results" key (API response envelope)
  if (is.list(works_list) && "results" %in% names(works_list)) {
    works_list <- works_list[["results"]]
  }

  n <- length(works_list)
  work_ids <- .generate_work_id(n)

  .safe <- function(x, default = NA_character_) {
    if (is.null(x) || length(x) == 0L) default else x
  }

  # --- works ---------------------------------------------------------------
  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(vapply(works_list, function(w) {
      .safe(w$doi)
    }, character(1))),
    title     = vapply(works_list, function(w) .safe(w$title), character(1)),
    abstract  = vapply(works_list, function(w) {
      # OpenAlex uses abstract_inverted_index; some exports have plain abstract
      if (!is.null(w$abstract)) return(w$abstract)
      if (!is.null(w$abstract_inverted_index)) {
        return(.openalex_reconstruct_abstract(w$abstract_inverted_index))
      }
      NA_character_
    }, character(1)),
    year      = suppressWarnings(as.integer(vapply(works_list, function(w) {
      .safe(w$publication_year, NA_integer_)
    }, integer(1)))),
    type      = vapply(works_list, function(w) .safe(w$type), character(1)),
    source_id = NA_character_,
    cited_by_count = suppressWarnings(as.integer(vapply(works_list, function(w) {
      .safe(w$cited_by_count, NA_integer_)
    }, integer(1)))),
    oa_status = vapply(works_list, function(w) {
      oa <- w$open_access
      if (!is.null(oa) && !is.null(oa$oa_status)) oa$oa_status
      else NA_character_
    }, character(1)),
    language  = vapply(works_list, function(w) .safe(w$language), character(1)),
    pmid      = vapply(works_list, function(w) {
      ids <- w$ids
      if (!is.null(ids) && !is.null(ids$pmid)) {
        sub("^https://pubmed\\.ncbi\\.nlm\\.nih\\.gov/", "", ids$pmid)
      } else {
        NA_character_
      }
    }, character(1)),
    arxiv_id  = NA_character_,
    openalex_id = vapply(works_list, function(w) .safe(w$id), character(1)),
    is_retracted = vapply(works_list, function(w) {
      isTRUE(w$is_retracted)
    }, logical(1)),
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
  works <- .ensure_works_schema(works)

  # --- authors & authorships -----------------------------------------------
  auth_result <- .openalex_build_authors(works_list, work_ids)

  # --- sources (host venue) ------------------------------------------------
  sources <- .openalex_build_sources(works_list, work_ids, works)

  # --- concepts -------------------------------------------------------------
  concepts <- .openalex_build_concepts(works_list, work_ids)

  # --- references -----------------------------------------------------------
  references <- .openalex_build_references(works_list, work_ids)

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "openalex",
    source_id_external = vapply(works_list, function(w) .safe(w$id),
                                 character(1)),
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {n} OpenAlex work{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    references  = references,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_openalex_json")
  )
}

# ---- OpenAlex helpers -------------------------------------------------------

#' Reconstruct abstract from OpenAlex inverted index
#' @noRd
.openalex_reconstruct_abstract <- function(inv_index) {
  if (is.null(inv_index) || length(inv_index) == 0L) return(NA_character_)

  # inv_index is a named list: word -> positions
  tryCatch({
    max_pos <- 0L
    for (positions in inv_index) {
      pos <- unlist(positions)
      if (length(pos) > 0L) max_pos <- max(max_pos, pos)
    }
    if (max_pos == 0L) return(NA_character_)

    words <- rep("", max_pos + 1L)
    for (word in names(inv_index)) {
      positions <- unlist(inv_index[[word]])
      for (p in positions) {
        words[p + 1L] <- word
      }
    }
    result <- paste(words, collapse = " ")
    result <- gsub("\\s+", " ", trimws(result))
    if (nzchar(result)) result else NA_character_
  }, error = function(e) NA_character_)
}

#' Build authors from OpenAlex authorships
#' @noRd
.openalex_build_authors <- function(works_list, work_ids) {
  all_authors <- character()
  all_orcids <- character()
  all_oa_ids <- character()
  authorship_rows <- list()

  for (i in seq_along(works_list)) {
    w <- works_list[[i]]
    aships <- w$authorships
    if (is.null(aships) || length(aships) == 0L) next

    for (j in seq_along(aships)) {
      a <- aships[[j]]
      author_info <- a$author
      if (is.null(author_info)) next

      display_name <- author_info$display_name %||% NA_character_
      if (is.na(display_name) || !nzchar(display_name)) next

      orcid_raw <- author_info$orcid %||% NA_character_
      orcid <- if (!is.na(orcid_raw)) {
        sub("^https://orcid\\.org/", "", orcid_raw)
      } else {
        NA_character_
      }

      oa_id <- author_info$id %||% NA_character_

      all_authors <- c(all_authors, display_name)
      all_orcids <- c(all_orcids, orcid)
      all_oa_ids <- c(all_oa_ids, oa_id)

      # Affiliation from institutions
      raw_aff <- NA_character_
      country <- NA_character_
      inst_id <- NA_character_
      insts <- a$institutions
      if (!is.null(insts) && length(insts) > 0L) {
        first_inst <- insts[[1]]
        raw_aff <- first_inst$display_name %||% NA_character_
        country <- first_inst$country_code %||% NA_character_
        inst_id <- first_inst$id %||% NA_character_
      }

      authorship_rows[[length(authorship_rows) + 1L]] <- tibble::tibble(
        work_id = work_ids[i],
        author_name = display_name,
        orcid = orcid,
        oa_id = oa_id,
        position = as.integer(j),
        is_corresponding = isTRUE(a$is_corresponding),
        institution_id = inst_id,
        raw_affiliation = raw_aff,
        country_code = country
      )
    }
  }

  if (length(authorship_rows) == 0L) {
    return(list(authors = .empty_authors(), authorships = .empty_authorships()))
  }

  aships_df <- dplyr::bind_rows(authorship_rows)

  # Deduplicate authors: prefer OpenAlex ID, then ORCID, then name
  auth_key <- ifelse(!is.na(aships_df$oa_id), aships_df$oa_id,
                ifelse(!is.na(aships_df$orcid), aships_df$orcid,
                  aships_df$author_name))

  unique_keys <- unique(auth_key)
  author_ids <- .generate_author_id(length(unique_keys))
  key_to_id <- stats::setNames(author_ids, unique_keys)

  # Build unique authors table
  first_idx <- match(unique_keys, auth_key)
  authors <- tibble::tibble(
    author_id = author_ids,
    orcid = aships_df$orcid[first_idx],
    display_name = aships_df$author_name[first_idx],
    display_name_alternatives = lapply(seq_along(author_ids), function(x) character()),
    inferred_gender = NA_character_,
    gender_confidence = NA_real_,
    gender_method = NA_character_
  )

  authorships <- tibble::tibble(
    work_id = aships_df$work_id,
    author_id = unname(key_to_id[auth_key]),
    position = aships_df$position,
    is_corresponding = aships_df$is_corresponding,
    institution_id = aships_df$institution_id,
    raw_affiliation = aships_df$raw_affiliation,
    country_code = aships_df$country_code
  )

  list(authors = authors, authorships = authorships)
}

#' Build sources from OpenAlex host_venue / primary_location
#' @noRd
.openalex_build_sources <- function(works_list, work_ids, works_tbl) {
  source_data <- list()

  for (i in seq_along(works_list)) {
    w <- works_list[[i]]

    # Try primary_location first (newer schema), then host_venue
    loc <- w$primary_location %||% w$host_venue
    if (is.null(loc)) next

    src <- loc$source %||% loc
    sname <- src$display_name %||% NA_character_
    if (is.na(sname)) next

    source_data[[length(source_data) + 1L]] <- list(
      work_idx = i,
      display_name = sname,
      issn_l = src$issn_l %||% NA_character_,
      issn = src$issn %||% list(),
      type = src$type %||% "journal",
      is_oa = src$is_oa %||% NA,
      host_org = src$host_organization_name %||% NA_character_
    )
  }

  if (length(source_data) == 0L) return(.empty_sources())

  src_names <- vapply(source_data, function(s) s$display_name, character(1))
  unames <- unique(src_names)
  sids <- .generate_source_id(length(unames))

  # Build source table from first occurrence
  first_idx <- match(unames, src_names)
  sources <- tibble::tibble(
    source_id = sids,
    issn_l = vapply(first_idx, function(j) source_data[[j]]$issn_l, character(1)),
    issn = lapply(first_idx, function(j) {
      is <- source_data[[j]]$issn
      if (is.null(is)) character() else unlist(is)
    }),
    display_name = unames,
    type = vapply(first_idx, function(j) source_data[[j]]$type, character(1)),
    is_oa = vapply(first_idx, function(j) {
      v <- source_data[[j]]$is_oa
      if (is.null(v) || is.na(v)) NA else v
    }, logical(1)),
    publisher = vapply(first_idx, function(j) source_data[[j]]$host_org, character(1)),
    publisher_country = NA_character_
  )

  # Map works to source_ids
  name_to_sid <- stats::setNames(sids, unames)
  for (sd in source_data) {
    works_tbl$source_id[sd$work_idx] <- unname(name_to_sid[sd$display_name])
  }

  sources
}

#' Build concepts from OpenAlex concepts/topics
#' @noRd
.openalex_build_concepts <- function(works_list, work_ids) {
  rows <- list()
  for (i in seq_along(works_list)) {
    w <- works_list[[i]]
    concepts <- w$concepts %||% w$topics
    if (is.null(concepts) || length(concepts) == 0L) next

    concept_names <- character()
    concept_ids <- character()
    concept_levels <- integer()
    concept_scores <- double()

    for (c in concepts) {
      cname <- c$display_name %||% NA_character_
      if (is.na(cname)) next
      concept_names <- c(concept_names, cname)
      concept_ids <- c(concept_ids, c$id %||% NA_character_)
      concept_levels <- c(concept_levels,
        as.integer(c$level %||% NA_integer_))
      concept_scores <- c(concept_scores,
        as.double(c$score %||% NA_real_))
    }

    if (length(concept_names) == 0L) next

    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      concept_id = concept_ids,
      concept_name = concept_names,
      level = concept_levels,
      score = concept_scores,
      vocabulary = "openalex"
    )
  }
  if (length(rows) == 0L) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

#' Build references from OpenAlex referenced_works
#' @noRd
.openalex_build_references <- function(works_list, work_ids) {
  rows <- list()
  for (i in seq_along(works_list)) {
    w <- works_list[[i]]
    refs <- w$referenced_works
    if (is.null(refs) || length(refs) == 0L) next
    ref_ids <- unlist(refs)
    ref_ids <- ref_ids[nzchar(ref_ids)]
    if (length(ref_ids) == 0L) next

    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      ref_index = seq_along(ref_ids),
      cited_work_id = NA_character_,
      cited_doi = NA_character_,
      cited_raw = ref_ids
    )
  }
  if (length(rows) == 0L) return(.empty_references())
  dplyr::bind_rows(rows)
}

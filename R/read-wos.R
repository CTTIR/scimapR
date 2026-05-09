#' Read Web of Science plaintext files
#'
#' @description
#' Parse Web of Science (WoS) plaintext export files into an `sm_corpus`
#' object. Handles the standard WoS tagged format with two-letter field codes.
#'
#' @param path Character scalar. Path to a WoS plaintext file (`.txt`).
#' @param encoding Character scalar. File encoding (default `"UTF-8"`).
#' @param engine Character scalar. One of `"native"` (built-in parser),
#'   `"bibliometrix"` (delegate to `bibliometrix::convert2df()`), or
#'   `"auto"` (try bibliometrix first, fall back to native).
#' @param verbose Logical. Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An [sm_corpus] object.
#'
#' @section Implementation:
#' The native parser follows the Web of Science Core Collection export format.
#' Each record begins with `PT ` (publication type) and ends with `ER`.
#' Field tags are two uppercase letters followed by a single space.
#' Continuation lines begin with three spaces. Key tags parsed:
#' AU (authors), TI (title), SO (source), AB (abstract), DI (DOI),
#' PY (year), DT (document type), C1 (addresses), RP (reprint author),
#' CR (cited references), NR (number of references), TC (times cited),
#' SC (subject category), UT (unique identifier), LA (language).
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
#' corpus <- sm_read_wos("savedrecs.txt")
#' corpus$works
#' }
sm_read_wos <- function(path,
                        encoding = "UTF-8",
                        engine = c("native", "bibliometrix", "auto"),
                        verbose = TRUE,
                        call = rlang::caller_env()) {
  engine <- rlang::arg_match(engine, error_call = call)

  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.file {path}}", call = call)
  }

  # --- bibliometrix engines ------------------------------------------------
  if (engine == "bibliometrix") {
    return(.wos_via_bibliometrix(path, call = call))
  }

  if (engine == "auto") {
    corpus <- tryCatch(
      .wos_via_bibliometrix(path, call = call),
      error = function(e) NULL
    )
    if (!is.null(corpus)) return(corpus)
    .sm_verbose("bibliometrix engine failed; falling back to native parser.",
                verbose)
  }

  # --- native parser -------------------------------------------------------
  .sm_verbose("Reading Web of Science file: {.file {path}}", verbose)

  lines <- readr::read_lines(path, locale = readr::locale(encoding = encoding))

  records <- .wos_split_records(lines)

  if (length(records) == 0L) {
    .sm_verbose("No WoS records found.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_wos")
    ))
  }

  parsed <- lapply(records, .wos_parse_record)
  parsed <- Filter(Negate(is.null), parsed)

  if (length(parsed) == 0L) {
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_wos")
    ))
  }

  n <- length(parsed)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(vapply(parsed, function(r) r$doi, character(1))),
    title     = vapply(parsed, function(r) r$title, character(1)),
    abstract  = vapply(parsed, function(r) r$abstract, character(1)),
    year      = as.integer(vapply(parsed, function(r) r$year, character(1))),
    type      = vapply(parsed, function(r) r$doc_type, character(1)),
    source_id = NA_character_,
    cited_by_count = suppressWarnings(
      as.integer(vapply(parsed, function(r) r$tc, character(1)))
    ),
    oa_status = NA_character_,
    language  = vapply(parsed, function(r) r$language, character(1)),
    pmid      = vapply(parsed, function(r) r$pmid, character(1)),
    arxiv_id  = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
  works <- .ensure_works_schema(works)

  # --- authors & authorships -----------------------------------------------
  author_lists <- lapply(parsed, function(r) r$authors)
  aff_lists <- lapply(parsed, function(r) r$affiliations)
  auth_result <- .wos_build_authors(author_lists, aff_lists, work_ids)

  # --- sources -------------------------------------------------------------
  source_names <- vapply(parsed, function(r) r$source, character(1))
  sources <- .empty_sources()
  if (any(!is.na(source_names))) {
    unames <- unique(stats::na.omit(source_names))
    sids <- .generate_source_id(length(unames))
    sources <- tibble::tibble(
      source_id = sids,
      issn_l = NA_character_,
      issn = lapply(seq_along(sids), function(i) character()),
      display_name = unames,
      type = "journal",
      is_oa = NA,
      publisher = NA_character_,
      publisher_country = NA_character_
    )
    works$source_id <- sids[match(source_names, unames)]
  }

  # --- references -----------------------------------------------------------
  references <- .wos_build_references(parsed, work_ids)

  # --- concepts (subject categories) ----------------------------------------
  concepts <- .wos_build_concepts(parsed, work_ids)

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "wos",
    source_id_external = vapply(parsed, function(r) r$ut, character(1)),
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {n} WoS record{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    references  = references,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_wos")
  )
}

# ---- bibliometrix delegation ------------------------------------------------

.wos_via_bibliometrix <- function(path, call = rlang::caller_env()) {
  rlang::check_installed("bibliometrix",
    reason = "to use the bibliometrix engine for WoS files.",
    call = call
  )
  bib_df <- bibliometrix::convert2df(file = path, dbsource = "wos",
                                      format = "plaintext")
  .bibliometrix_df_to_corpus(bib_df, source_label = "wos",
                              source_file = path)
}

# ---- WoS parsing helpers ---------------------------------------------------

#' Split WoS plaintext lines into records (PT ... ER)
#' @noRd
.wos_split_records <- function(lines) {
  pt_lines <- which(grepl("^PT\\s", lines))
  er_lines <- which(grepl("^ER\\s*$", lines))

  if (length(pt_lines) == 0L) return(list())

  records <- list()
  for (i in seq_along(pt_lines)) {
    start <- pt_lines[i]
    end_candidates <- er_lines[er_lines > start]
    end <- if (length(end_candidates) > 0L) end_candidates[1] else length(lines)
    records[[i]] <- lines[start:end]
  }
  records
}

#' Parse WoS tagged lines into a named list
#' @noRd
.wos_parse_record <- function(record_lines) {
  tags <- list()
  current_tag <- NULL

  for (line in record_lines) {
    # Check for a tag line: 2 uppercase letters + space + value
    if (nchar(line) >= 3L && grepl("^[A-Z][A-Z0-9] ", substring(line, 1, 3))) {
      tag <- substring(line, 1, 2)
      value <- trimws(substring(line, 4))
      if (tag %in% names(tags)) {
        tags[[tag]] <- c(tags[[tag]], value)
      } else {
        tags[[tag]] <- value
      }
      current_tag <- tag
    } else if (grepl("^   ", line) && !is.null(current_tag)) {
      # Continuation line (3 leading spaces)
      value <- trimws(line)
      n_vals <- length(tags[[current_tag]])
      # For multi-value tags like AU, add as new; for text tags, append
      if (current_tag %in% c("AU", "AF", "CR", "C1")) {
        tags[[current_tag]] <- c(tags[[current_tag]], value)
      } else {
        tags[[current_tag]][n_vals] <- paste(
          tags[[current_tag]][n_vals], value
        )
      }
    }
  }

  .get_single <- function(...) {
    nms <- c(...)
    for (nm in nms) {
      if (nm %in% names(tags) && length(tags[[nm]]) > 0L && nzchar(tags[[nm]][1])) {
        return(paste(tags[[nm]], collapse = " "))
      }
    }
    NA_character_
  }

  # Extract PMID from identifier fields if present
  pmid <- NA_character_
  if ("PM" %in% names(tags)) {
    pmid <- trimws(tags[["PM"]][1])
  }

  list(
    pub_type    = .get_single("PT"),
    authors     = tags[["AU"]] %||% tags[["AF"]] %||% character(),
    title       = .get_single("TI"),
    source      = .get_single("SO"),
    abstract    = .get_single("AB"),
    doi         = .get_single("DI"),
    year        = .get_single("PY"),
    doc_type    = .get_single("DT"),
    language    = .get_single("LA"),
    tc          = .get_single("TC"),
    ut          = .get_single("UT"),
    pmid        = pmid,
    affiliations = tags[["C1"]] %||% character(),
    cited_refs  = tags[["CR"]] %||% character(),
    subject_cat = tags[["SC"]] %||% character(),
    keywords    = tags[["DE"]] %||% character(),
    keywords_plus = tags[["ID"]] %||% character()
  )
}

#' Build authors from WoS author lists
#' @noRd
.wos_build_authors <- function(author_lists, aff_lists, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(author_lists)) {
    names <- trimws(author_lists[[i]])
    names <- names[nzchar(names)]
    if (length(names) == 0L) next

    # Normalize "Last, First" -> "First Last"
    names <- vapply(names, function(nm) {
      if (grepl(",", nm, fixed = TRUE)) {
        parts <- trimws(strsplit(nm, ",", fixed = TRUE)[[1]])
        if (length(parts) >= 2L) paste(parts[2], parts[1]) else nm
      } else {
        nm
      }
    }, character(1), USE.NAMES = FALSE)

    all_authors <- c(all_authors, names)

    # Try to extract affiliations
    affs <- aff_lists[[i]]
    raw_aff <- rep(NA_character_, length(names))
    if (length(affs) > 0L) {
      # C1 lines often look like: [AuthorName] Institution, ...
      for (j in seq_along(names)) {
        pattern <- paste0("\\[.*", gsub("([[:punct:]])", "\\\\\\1",
                    strsplit(names[j], " ")[[1]][length(strsplit(names[j], " ")[[1]])]),
                    ".*\\]\\s*(.*)")
        matches <- grep(pattern, affs, value = TRUE, ignore.case = TRUE)
        if (length(matches) > 0L) {
          raw_aff[j] <- sub("^\\[.*?\\]\\s*", "", matches[1])
        }
      }
    }

    authorship_rows[[length(authorship_rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      author_name = names,
      position = seq_along(names),
      is_corresponding = c(TRUE, rep(FALSE, max(0L, length(names) - 1L))),
      raw_affiliation = raw_aff
    )
  }

  if (length(authorship_rows) == 0L) {
    return(list(authors = .empty_authors(), authorships = .empty_authorships()))
  }

  aships_df <- dplyr::bind_rows(authorship_rows)
  unique_names <- unique(all_authors)
  author_ids <- .generate_author_id(length(unique_names))

  authors <- tibble::tibble(
    author_id = author_ids,
    orcid = NA_character_,
    display_name = unique_names,
    display_name_alternatives = lapply(seq_along(unique_names), function(x) character()),
    inferred_gender = NA_character_,
    gender_confidence = NA_real_,
    gender_method = NA_character_
  )

  name_to_id <- stats::setNames(author_ids, unique_names)

  authorships <- tibble::tibble(
    work_id = aships_df$work_id,
    author_id = unname(name_to_id[aships_df$author_name]),
    position = aships_df$position,
    is_corresponding = aships_df$is_corresponding,
    institution_id = NA_character_,
    raw_affiliation = aships_df$raw_affiliation,
    country_code = NA_character_
  )

  list(authors = authors, authorships = authorships)
}

#' Build references from WoS CR tag
#' @noRd
.wos_build_references <- function(parsed, work_ids) {
  rows <- list()
  for (i in seq_along(parsed)) {
    refs <- parsed[[i]]$cited_refs
    if (length(refs) == 0L) next
    refs <- trimws(refs)
    refs <- refs[nzchar(refs)]
    if (length(refs) == 0L) next

    # Try to extract DOI from CR strings
    dois <- vapply(refs, function(r) {
      m <- regmatches(r, regexpr("DOI\\s+(10\\.[^,;\\s]+)", r, perl = TRUE))
      if (length(m) > 0L) sub("^DOI\\s+", "", m) else NA_character_
    }, character(1), USE.NAMES = FALSE)

    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      ref_index = seq_along(refs),
      cited_work_id = NA_character_,
      cited_doi = .normalize_doi(dois),
      cited_raw = refs
    )
  }
  if (length(rows) == 0L) return(.empty_references())
  dplyr::bind_rows(rows)
}

#' Build concepts from WoS DE/ID/SC tags
#' @noRd
.wos_build_concepts <- function(parsed, work_ids) {
  rows <- list()
  for (i in seq_along(parsed)) {
    r <- parsed[[i]]
    terms <- character()
    vocab <- character()

    # Author keywords (DE)
    if (length(r$keywords) > 0L) {
      kw <- trimws(unlist(strsplit(paste(r$keywords, collapse = ";"), ";")))
      kw <- kw[nzchar(kw)]
      if (length(kw) > 0L) {
        terms <- c(terms, kw)
        vocab <- c(vocab, rep("author-keywords", length(kw)))
      }
    }

    # KeyWords Plus (ID)
    if (length(r$keywords_plus) > 0L) {
      kp <- trimws(unlist(strsplit(paste(r$keywords_plus, collapse = ";"), ";")))
      kp <- kp[nzchar(kp)]
      if (length(kp) > 0L) {
        terms <- c(terms, kp)
        vocab <- c(vocab, rep("keywords-plus", length(kp)))
      }
    }

    # Subject categories (SC)
    if (length(r$subject_cat) > 0L) {
      sc <- trimws(unlist(strsplit(paste(r$subject_cat, collapse = ";"), ";")))
      sc <- sc[nzchar(sc)]
      if (length(sc) > 0L) {
        terms <- c(terms, sc)
        vocab <- c(vocab, rep("wos-subject-category", length(sc)))
      }
    }

    if (length(terms) == 0L) next

    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      concept_id = NA_character_,
      concept_name = terms,
      level = NA_integer_,
      score = NA_real_,
      vocabulary = vocab
    )
  }
  if (length(rows) == 0L) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

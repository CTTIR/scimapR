#' Read RIS files
#'
#' @description
#' Parse RIS (Research Information Systems) tag-value format files into an
#' `sm_corpus` object. Supports the standard RIS specification with two-letter
#' tags followed by two spaces, a dash, and a space.
#'
#' @param path Character scalar. Path to a `.ris` file.
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
#' The native parser follows the RIS format specification (Thomson Reuters).
#' Each record starts with `TY  -` and ends with `ER  -`. Tags are two
#' uppercase letters followed by two spaces, a hyphen, and a space. Repeating
#' tags (AU, KW) generate multiple values per record.
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
#' corpus <- sm_read_ris("references.ris")
#' corpus$works
#' }
sm_read_ris <- function(path,
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
    return(.ris_via_bibliometrix(path, call = call))
  }

  if (engine == "auto") {
    corpus <- tryCatch(
      .ris_via_bibliometrix(path, call = call),
      error = function(e) NULL
    )
    if (!is.null(corpus)) return(corpus)
    .sm_verbose("bibliometrix engine failed; falling back to native parser.",
                verbose)
  }

  # --- native parser -------------------------------------------------------
  .sm_verbose("Reading RIS file: {.file {path}}", verbose)


  lines <- readr::read_lines(path, locale = readr::locale(encoding = encoding))

  records <- .ris_split_records(lines)

  if (length(records) == 0L) {
    .sm_verbose("No RIS records found.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_ris")
    ))
  }

  parsed <- lapply(records, .ris_parse_record)
  parsed <- Filter(Negate(is.null), parsed)

  if (length(parsed) == 0L) {
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_ris")
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
    type      = vapply(parsed, function(r) r$type, character(1)),
    source_id = NA_character_,
    cited_by_count = NA_integer_,
    oa_status = NA_character_,
    language  = NA_character_,
    pmid      = NA_character_,
    arxiv_id  = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
  works <- .ensure_works_schema(works)

  # --- authors & authorships -----------------------------------------------
  author_lists <- lapply(parsed, function(r) r$authors)
  auth_result <- .ris_build_authors(author_lists, work_ids)

  # --- sources -------------------------------------------------------------
  source_names <- vapply(parsed, function(r) r$journal, character(1))
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

  # --- concepts (keywords) -------------------------------------------------
  kw_lists <- lapply(parsed, function(r) r$keywords)
  concepts <- .ris_build_concepts(kw_lists, work_ids)

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "ris",
    source_id_external = NA_character_,
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {n} RIS record{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_ris")
  )
}

# ---- bibliometrix delegation ------------------------------------------------

.ris_via_bibliometrix <- function(path, call = rlang::caller_env()) {
  rlang::check_installed("bibliometrix",
    reason = "to use the bibliometrix engine for RIS files.",
    call = call
  )
  bib_df <- bibliometrix::convert2df(file = path, dbsource = "generic",
                                      format = "plaintext")
  .bibliometrix_df_to_corpus(bib_df, source_label = "ris",
                              source_file = path)
}

# ---- RIS parsing helpers ----------------------------------------------------

#' Split RIS lines into records (between TY and ER tags)
#' @noRd
.ris_split_records <- function(lines) {
  # Find TY and ER lines
  ty_lines <- which(grepl("^TY\\s{2}-\\s", lines))
  er_lines <- which(grepl("^ER\\s{2}-", lines))

  if (length(ty_lines) == 0L) return(list())

  records <- list()
  for (i in seq_along(ty_lines)) {
    start <- ty_lines[i]
    # Find the next ER after this TY
    end_candidates <- er_lines[er_lines > start]
    if (length(end_candidates) == 0L) {
      end <- length(lines)
    } else {
      end <- end_candidates[1]
    }
    records[[i]] <- lines[start:end]
  }
  records
}

#' Parse a single RIS record (vector of lines) into a named list
#' @noRd
.ris_parse_record <- function(record_lines) {
  tags <- list()

  current_tag <- NULL
  for (line in record_lines) {
    # Check if this line starts a new tag
    m <- regmatches(line, regexec("^([A-Z][A-Z0-9])\\s{2}-\\s?(.*)", line))[[1]]
    if (length(m) == 3L) {
      tag <- m[2]
      value <- trimws(m[3])
      # Some tags can repeat (AU, KW, etc.)
      if (tag %in% names(tags)) {
        tags[[tag]] <- c(tags[[tag]], value)
      } else {
        tags[[tag]] <- value
      }
      current_tag <- tag
    } else {
      # Continuation line (no tag) - append to previous tag
      if (!is.null(current_tag)) {
        n <- length(tags[[current_tag]])
        tags[[current_tag]][n] <- paste(tags[[current_tag]][n], trimws(line))
      }
    }
  }

  .get_first <- function(...) {
    nms <- c(...)
    for (nm in nms) {
      if (nm %in% names(tags) && nzchar(tags[[nm]][1])) {
        return(tags[[nm]][1])
      }
    }
    NA_character_
  }

  list(
    type     = .get_first("TY"),
    title    = .get_first("TI", "T1"),
    authors  = tags[["AU"]] %||% tags[["A1"]] %||% character(),
    year     = .get_first("PY", "Y1"),
    doi      = .get_first("DO", "DI"),
    journal  = .get_first("JO", "JF", "T2", "J2"),
    abstract = .get_first("AB", "N2"),
    volume   = .get_first("VL"),
    start_page = .get_first("SP"),
    end_page = .get_first("EP"),
    keywords = tags[["KW"]] %||% character()
  )
}

#' Build authors and authorships from RIS author lists
#' @noRd
.ris_build_authors <- function(author_lists, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(author_lists)) {
    names <- author_lists[[i]]
    if (length(names) == 0L) next
    names <- trimws(names)
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
    authorship_rows[[length(authorship_rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      author_name = names,
      position = seq_along(names),
      is_corresponding = c(TRUE, rep(FALSE, max(0L, length(names) - 1L)))
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
    raw_affiliation = NA_character_,
    country_code = NA_character_
  )

  list(authors = authors, authorships = authorships)
}

#' Build concepts from RIS keyword lists
#' @noRd
.ris_build_concepts <- function(kw_lists, work_ids) {
  rows <- list()
  for (i in seq_along(kw_lists)) {
    terms <- kw_lists[[i]]
    if (length(terms) == 0L) next
    terms <- trimws(terms)
    terms <- terms[nzchar(terms)]
    if (length(terms) == 0L) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      concept_id = NA_character_,
      concept_name = terms,
      level = NA_integer_,
      score = NA_real_,
      vocabulary = "author-keywords"
    )
  }
  if (length(rows) == 0L) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

#' Read Cochrane Library export files
#'
#' @description
#' Parse Cochrane Library (CDSR) export files into an `sm_corpus` object.
#' Supports both CSV/tab-delimited exports and RIS-format exports from the
#' Cochrane Library search interface.
#'
#' @param path Character scalar. Path to a Cochrane export file
#'   (`.csv`, `.tsv`, or `.ris`).
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
#' The Cochrane Library exports records in CSV or RIS format. The CSV export
#' typically contains columns such as: Record Number (or #), Authors, Title,
#' Source, Year, DOI, Abstract. RIS exports follow the standard RIS
#' specification and are delegated to the RIS parser.
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
#' corpus <- sm_read_cochrane("cochrane_export.csv")
#' corpus$works
#' }
sm_read_cochrane <- function(path,
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
    return(.cochrane_via_bibliometrix(path, call = call))
  }

  if (engine == "auto") {
    corpus <- tryCatch(
      .cochrane_via_bibliometrix(path, call = call),
      error = function(e) NULL
    )
    if (!is.null(corpus)) return(corpus)
    .sm_verbose("bibliometrix engine failed; falling back to native parser.",
                verbose)
  }

  # --- detect format (CSV vs RIS) ------------------------------------------
  ext <- tolower(tools::file_ext(path))
  first_lines <- readr::read_lines(path, n_max = 5L,
    locale = readr::locale(encoding = encoding))

  is_ris <- any(grepl("^TY\\s{2}-", first_lines))

  if (is_ris || ext == "ris") {
    .sm_verbose("Detected RIS format; delegating to RIS parser.", verbose)
    corpus <- sm_read_ris(path, encoding = encoding, engine = "native",
                           verbose = verbose, call = call)
    # Update provenance source to "cochrane"
    corpus$provenance$source <- "cochrane"
    corpus$metadata$reader <- "sm_read_cochrane"
    return(corpus)
  }

  # --- CSV/TSV parser ------------------------------------------------------
  .sm_verbose("Reading Cochrane CSV: {.file {path}}", verbose)

  # Detect delimiter
  if (ext == "tsv" || any(grepl("\t", first_lines))) {
    df <- readr::read_tsv(path, locale = readr::locale(encoding = encoding),
                           show_col_types = FALSE, name_repair = "unique")
  } else {
    df <- readr::read_csv(path, locale = readr::locale(encoding = encoding),
                           show_col_types = FALSE, name_repair = "unique")
  }

  if (nrow(df) == 0L) {
    .sm_verbose("No records found in Cochrane file.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_cochrane")
    ))
  }

  # Flexible column matching
  .col <- function(df, ...) {
    patterns <- c(...)
    cn <- names(df)
    for (p in patterns) {
      idx <- grep(p, cn, ignore.case = TRUE)
      if (length(idx) > 0L) return(df[[idx[1]]])
    }
    rep(NA_character_, nrow(df))
  }

  n <- nrow(df)
  work_ids <- .generate_work_id(n)

  raw_authors  <- .col(df, "^Authors?$", "^AU$")
  raw_title    <- .col(df, "^Title$", "^TI$")
  raw_source   <- .col(df, "^Source$", "^Journal$", "^SO$")
  raw_year     <- .col(df, "^Year$", "^PY$")
  raw_doi      <- .col(df, "^DOI$", "^DI$")
  raw_abstract <- .col(df, "^Abstract$", "^AB$")
  raw_doctype  <- .col(df, "^Type$", "^Document.Type$", "^DT$")
  raw_recnum   <- .col(df, "^Record.Number$", "^#$", "^RecordNumber$")

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(as.character(raw_doi)),
    title     = as.character(raw_title),
    abstract  = as.character(raw_abstract),
    year      = suppressWarnings(as.integer(raw_year)),
    type      = as.character(raw_doctype),
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
  auth_strings <- as.character(raw_authors)
  auth_result <- .cochrane_build_authors(auth_strings, work_ids)

  # --- sources -------------------------------------------------------------
  source_names <- as.character(raw_source)
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

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "cochrane",
    source_id_external = as.character(raw_recnum),
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {n} Cochrane record{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_cochrane")
  )
}

# ---- bibliometrix delegation ------------------------------------------------

.cochrane_via_bibliometrix <- function(path, call = rlang::caller_env()) {
  rlang::check_installed("bibliometrix",
    reason = "to use the bibliometrix engine for Cochrane files.",
    call = call
  )
  bib_df <- bibliometrix::convert2df(file = path, dbsource = "cochrane",
                                      format = "plaintext")
  .bibliometrix_df_to_corpus(bib_df, source_label = "cochrane",
                              source_file = path)
}

# ---- Cochrane helpers -------------------------------------------------------

#' Build authors from Cochrane author strings
#' @noRd
.cochrane_build_authors <- function(auth_strings, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(auth_strings)) {
    au <- auth_strings[i]
    if (is.na(au) || !nzchar(trimws(au))) next

    # Cochrane uses comma or semicolon separation
    if (grepl(";", au, fixed = TRUE)) {
      names <- trimws(strsplit(au, ";")[[1]])
    } else {
      names <- trimws(strsplit(au, ",\\s*(?=[A-Z])", perl = TRUE)[[1]])
    }
    names <- names[nzchar(names)]
    if (length(names) == 0L) next

    # Normalize "Last First" or "Last, First" forms
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

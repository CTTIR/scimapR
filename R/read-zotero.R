#' Read Zotero CSV export files
#'
#' @description
#' Parse Zotero CSV export files into an `sm_corpus` object.
#' Handles the standard Zotero CSV export format with columns for
#' Key, Title, Author, Publication Year, DOI, Publication Title,
#' Abstract, and Item Type.
#'
#' @param path Character scalar. Path to a Zotero CSV file.
#' @param encoding Character scalar. File encoding (default `"UTF-8"`).
#' @param verbose Logical. Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An [sm_corpus] object.
#'
#' @section Implementation:
#' The parser reads the Zotero CSV export format using [readr::read_csv()].
#' Zotero CSV exports have a standard set of column names. Key columns
#' matched (case-insensitive): Key, Title, Author, Publication Year,
#' DOI, Publication Title, Abstract Note, Item Type, ISSN, Language,
#' Manual Tags, Automatic Tags. No bibliometrix engine is available since
#' Zotero CSV is not a format supported by `bibliometrix::convert2df()`.
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
#' corpus <- sm_read_zotero("zotero_export.csv")
#' corpus$works
#' }
sm_read_zotero <- function(path,
                           encoding = "UTF-8",
                           verbose = TRUE,
                           call = rlang::caller_env()) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.file {path}}", call = call)
  }

  .sm_verbose("Reading Zotero CSV: {.file {path}}", verbose)

  df <- readr::read_csv(path, locale = readr::locale(encoding = encoding),
                         show_col_types = FALSE, name_repair = "unique")

  if (nrow(df) == 0L) {
    .sm_verbose("No records found in Zotero CSV.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_zotero")
    ))
  }

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

  raw_key       <- .col(df, "^Key$")
  raw_title     <- .col(df, "^Title$")
  raw_authors   <- .col(df, "^Author$", "^Authors$")
  raw_year      <- .col(df, "^Publication.Year$", "^Publication Year$", "^Year$")
  raw_doi       <- .col(df, "^DOI$")
  raw_source    <- .col(df, "^Publication.Title$", "^Publication Title$",
                         "^Journal$", "^Source$")
  raw_abstract  <- .col(df, "^Abstract.Note$", "^Abstract Note$",
                         "^Abstract$", "^abstractNote$")
  raw_type      <- .col(df, "^Item.Type$", "^Item Type$", "^Type$",
                         "^itemType$")
  raw_issn      <- .col(df, "^ISSN$")
  raw_lang      <- .col(df, "^Language$")
  raw_man_tags  <- .col(df, "^Manual.Tags$", "^Manual Tags$")
  raw_auto_tags <- .col(df, "^Automatic.Tags$", "^Automatic Tags$")
  raw_pages     <- .col(df, "^Pages$")
  raw_volume    <- .col(df, "^Volume$")

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(as.character(raw_doi)),
    title     = as.character(raw_title),
    abstract  = as.character(raw_abstract),
    year      = suppressWarnings(as.integer(raw_year)),
    type      = as.character(raw_type),
    source_id = NA_character_,
    cited_by_count = NA_integer_,
    oa_status = NA_character_,
    language  = as.character(raw_lang),
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
  auth_result <- .zotero_build_authors(auth_strings, work_ids)

  # --- sources -------------------------------------------------------------
  source_names <- as.character(raw_source)
  sources <- .empty_sources()
  if (any(!is.na(source_names))) {
    unames <- unique(stats::na.omit(source_names))
    sids <- .generate_source_id(length(unames))
    issns <- as.character(raw_issn)
    src_issn <- vapply(unames, function(nm) {
      idx <- which(source_names == nm & !is.na(issns))[1]
      if (!is.na(idx)) issns[idx] else NA_character_
    }, character(1), USE.NAMES = FALSE)

    sources <- tibble::tibble(
      source_id = sids,
      issn_l = src_issn,
      issn = lapply(seq_along(sids), function(i) character()),
      display_name = unames,
      type = "journal",
      is_oa = NA,
      publisher = NA_character_,
      publisher_country = NA_character_
    )
    works$source_id <- sids[match(source_names, unames)]
  }

  # --- concepts (tags) -----------------------------------------------------
  concepts <- .zotero_build_concepts(
    as.character(raw_man_tags), as.character(raw_auto_tags), work_ids
  )

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "zotero",
    source_id_external = as.character(raw_key),
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {n} Zotero record{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_zotero")
  )
}

# ---- Zotero helpers ---------------------------------------------------------

#' Build authors from Zotero author strings (semicolon separated)
#' @noRd
.zotero_build_authors <- function(auth_strings, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(auth_strings)) {
    au <- auth_strings[i]
    if (is.na(au) || !nzchar(trimws(au))) next

    # Zotero CSV uses semicolons between authors: "Last, First; Last, First"
    names <- trimws(strsplit(au, ";")[[1]])
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

#' Build concepts from Zotero tag columns
#' @noRd
.zotero_build_concepts <- function(man_tags, auto_tags, work_ids) {
  rows <- list()
  for (i in seq_along(work_ids)) {
    terms <- character()
    vocab <- character()

    mt <- man_tags[i]
    if (!is.na(mt) && nzchar(trimws(mt))) {
      ts <- trimws(strsplit(mt, ";")[[1]])
      ts <- ts[nzchar(ts)]
      if (length(ts) > 0L) {
        terms <- c(terms, ts)
        vocab <- c(vocab, rep("manual-tags", length(ts)))
      }
    }

    at <- auto_tags[i]
    if (!is.na(at) && nzchar(trimws(at))) {
      ts <- trimws(strsplit(at, ";")[[1]])
      ts <- ts[nzchar(ts)]
      if (length(ts) > 0L) {
        terms <- c(terms, ts)
        vocab <- c(vocab, rep("automatic-tags", length(ts)))
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

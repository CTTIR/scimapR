#' Read Dimensions CSV files
#'
#' @description
#' Parse Dimensions CSV export files into an `sm_corpus` object.
#' Handles the standard Dimensions analytics platform CSV export format.
#'
#' @param path Character scalar. Path to a Dimensions CSV file.
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
#' The native parser reads the Dimensions CSV export using [readr::read_csv()].
#' Dimensions CSV files may begin with informational rows before the header;
#' the parser skips lines that do not look like the header. Key columns
#' matched (case-insensitive): Title, DOI, Authors, Source title
#' (or Source Title), PubYear (or Publication Year), Times cited,
#' Document Type (or Publication Type), Abstract, Dimensions ID,
#' MeSH terms, Author Keywords, ISSN.
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
#' corpus <- sm_read_dimensions("dimensions_export.csv")
#' corpus$works
#' }
sm_read_dimensions <- function(path,
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
    return(.dimensions_via_bibliometrix(path, call = call))
  }

  if (engine == "auto") {
    corpus <- tryCatch(
      .dimensions_via_bibliometrix(path, call = call),
      error = function(e) NULL
    )
    if (!is.null(corpus)) return(corpus)
    .sm_verbose("bibliometrix engine failed; falling back to native parser.",
                verbose)
  }

  # --- native parser -------------------------------------------------------
  .sm_verbose("Reading Dimensions CSV: {.file {path}}", verbose)

  # Dimensions CSVs sometimes have preamble lines; detect header row
  all_lines <- readr::read_lines(path,
    locale = readr::locale(encoding = encoding), n_max = 20L)
  skip <- 0L
  for (k in seq_along(all_lines)) {
    if (grepl("Title", all_lines[k], ignore.case = TRUE) &&
        grepl("DOI|Author", all_lines[k], ignore.case = TRUE)) {
      skip <- k - 1L
      break
    }
  }

  df <- readr::read_csv(path, skip = skip,
    locale = readr::locale(encoding = encoding),
    show_col_types = FALSE, name_repair = "unique")

  if (nrow(df) == 0L) {
    .sm_verbose("No records found in Dimensions CSV.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_dimensions")
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

  raw_title    <- .col(df, "^Title$")
  raw_doi      <- .col(df, "^DOI$")
  raw_authors  <- .col(df, "^Authors$", "^Author$")
  raw_source   <- .col(df, "^Source.title$", "^Source title$",
                        "^Source.Title$", "^Journal$")
  raw_year     <- .col(df, "^PubYear$", "^Pub.Year$",
                        "^Publication.Year$", "^Publication Year$", "^Year$")
  raw_cited    <- .col(df, "^Times.cited$", "^Times cited$",
                        "^Citations$", "^Cited.by$")
  raw_doctype  <- .col(df, "^Document.Type$", "^Document Type$",
                        "^Publication.Type$", "^Publication Type$", "^Type$")
  raw_abstract <- .col(df, "^Abstract$")
  raw_dim_id   <- .col(df, "^Dimensions.ID$", "^Dimensions ID$", "^Publication.ID$")
  raw_mesh     <- .col(df, "^MeSH", "^Mesh")
  raw_authkw   <- .col(df, "^Author.Keywords$", "^Author Keywords$", "^Keywords$")
  raw_issn     <- .col(df, "^ISSN$")
  raw_pmid     <- .col(df, "^PubMed.ID$", "^PubMed ID$", "^PMID$")
  raw_oa       <- .col(df, "^Open.Access$", "^Open Access$")

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(as.character(raw_doi)),
    title     = as.character(raw_title),
    abstract  = as.character(raw_abstract),
    year      = suppressWarnings(as.integer(raw_year)),
    type      = as.character(raw_doctype),
    source_id = NA_character_,
    cited_by_count = suppressWarnings(as.integer(raw_cited)),
    oa_status = as.character(raw_oa),
    language  = NA_character_,
    pmid      = as.character(raw_pmid),
    arxiv_id  = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
  works <- .ensure_works_schema(works)

  # --- authors & authorships -----------------------------------------------
  auth_strings <- as.character(raw_authors)
  auth_result <- .dimensions_build_authors(auth_strings, work_ids)

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

  # --- concepts (keywords + MeSH) ------------------------------------------
  concepts <- .dimensions_build_concepts(
    as.character(raw_authkw), as.character(raw_mesh), work_ids
  )

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "dimensions",
    source_id_external = as.character(raw_dim_id),
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {n} Dimensions record{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_dimensions")
  )
}

# ---- bibliometrix delegation ------------------------------------------------

.dimensions_via_bibliometrix <- function(path, call = rlang::caller_env()) {
  rlang::check_installed("bibliometrix",
    reason = "to use the bibliometrix engine for Dimensions files.",
    call = call
  )
  bib_df <- bibliometrix::convert2df(file = path, dbsource = "dimensions",
                                      format = "csv")
  .bibliometrix_df_to_corpus(bib_df, source_label = "dimensions",
                              source_file = path)
}

# ---- Dimensions helpers -----------------------------------------------------

#' Build authors from Dimensions author strings (semicolon separated)
#' @noRd
.dimensions_build_authors <- function(auth_strings, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(auth_strings)) {
    au <- auth_strings[i]
    if (is.na(au) || !nzchar(trimws(au))) next

    # Dimensions uses semicolons between authors
    names <- trimws(strsplit(au, ";")[[1]])
    names <- names[nzchar(names)]
    if (length(names) == 0L) next

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

#' Build concepts from Dimensions keyword and MeSH columns
#' @noRd
.dimensions_build_concepts <- function(kw_vec, mesh_vec, work_ids) {
  rows <- list()
  for (i in seq_along(work_ids)) {
    terms <- character()
    vocab <- character()

    k <- kw_vec[i]
    if (!is.na(k) && nzchar(trimws(k))) {
      ks <- trimws(strsplit(k, ";")[[1]])
      ks <- ks[nzchar(ks)]
      if (length(ks) > 0L) {
        terms <- c(terms, ks)
        vocab <- c(vocab, rep("author-keywords", length(ks)))
      }
    }

    m <- mesh_vec[i]
    if (!is.na(m) && nzchar(trimws(m))) {
      ms <- trimws(strsplit(m, ";")[[1]])
      ms <- ms[nzchar(ms)]
      if (length(ms) > 0L) {
        terms <- c(terms, ms)
        vocab <- c(vocab, rep("mesh", length(ms)))
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

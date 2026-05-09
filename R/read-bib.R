#' Read BibTeX files
#'
#' @description
#' Parse standard BibTeX (`.bib`) files into an `sm_corpus` object.
#' Extracts entry type, title, author, year, DOI, journal, abstract, volume,
#' pages, and keywords from each `@type{key, ...}` entry.
#'
#' @param path Character scalar. Path to a `.bib` file.
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
#' The native parser follows the BibTeX format specification as described in
#' the original BibTeX documentation (Patashnik, 1988). Field values may be
#' enclosed in braces or double-quotes and may span multiple lines. String
#' concatenation with `#` is not supported; `@string` and `@preamble`
#' entries are skipped.
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
#' corpus <- sm_read_bib("references.bib")
#' corpus$works
#' }
sm_read_bib <- function(path,
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
    return(.bib_via_bibliometrix(path, call = call))
  }

  if (engine == "auto") {
    corpus <- tryCatch(
      .bib_via_bibliometrix(path, call = call),
      error = function(e) NULL
    )
    if (!is.null(corpus)) return(corpus)
    .sm_verbose("bibliometrix engine failed; falling back to native parser.",
                verbose)
  }

  # --- native parser -------------------------------------------------------
  .sm_verbose("Reading BibTeX file: {.file {path}}", verbose)

  raw <- readr::read_file(path, locale = readr::locale(encoding = encoding))
  entries <- .bib_parse_entries(raw)

  if (length(entries) == 0L) {
    .sm_verbose("No BibTeX entries found.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_bib")
    ))
  }

  records <- lapply(entries, .bib_entry_to_record)
  df <- dplyr::bind_rows(records)

  work_ids <- .generate_work_id(nrow(df))

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(df$doi),
    title     = df$title %||% NA_character_,
    abstract  = df$abstract %||% NA_character_,
    year      = as.integer(df$year),
    type      = df$entry_type %||% NA_character_,
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
  auth_result <- .bib_build_authors(df$author, work_ids)

  # --- sources -------------------------------------------------------------
  source_names <- df$journal
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
  concepts <- .bib_build_concepts(df$keywords, work_ids)

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "bibtex",
    source_id_external = df$cite_key %||% NA_character_,
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {nrow(works)} BibTeX entr{?y/ies}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_bib")
  )
}

# ---- bibliometrix delegation ------------------------------------------------

.bib_via_bibliometrix <- function(path, call = rlang::caller_env()) {
  rlang::check_installed("bibliometrix",
    reason = "to use the bibliometrix engine for BibTeX files.",
    call = call
  )
  bib_df <- bibliometrix::convert2df(file = path, dbsource = "generic",
                                      format = "bibtex")
  .bibliometrix_df_to_corpus(bib_df, source_label = "bibtex",
                              source_file = path)
}

# ---- BibTeX parsing helpers -------------------------------------------------

#' Parse raw BibTeX text into a list of entry strings
#' @noRd
.bib_parse_entries <- function(raw) {
  # Match @type{key, ... } blocks. We find the positions of @type{ and then

  # match balanced braces to find the end.
  pattern <- "@\\s*(\\w+)\\s*\\{"
  starts <- gregexpr(pattern, raw, perl = TRUE)[[1]]
  if (starts[1] == -1L) return(list())

  entries <- list()
  for (s in starts) {
    # find the opening brace
    brace_pos <- regexpr("\\{", substring(raw, s))
    if (brace_pos == -1L) next
    open <- s + brace_pos - 1L
    # walk forward counting braces
    depth <- 0L
    pos <- open
    n <- nchar(raw)
    while (pos <= n) {
      ch <- substr(raw, pos, pos)
      if (ch == "{") depth <- depth + 1L
      if (ch == "}") depth <- depth - 1L
      if (depth == 0L) break
      pos <- pos + 1L
    }
    if (depth != 0L) next
    entry_text <- substring(raw, s, pos)
    entries <- c(entries, list(entry_text))
  }
  entries
}

#' Parse a single BibTeX entry string into a named list
#' @noRd
.bib_entry_to_record <- function(entry) {
  # Extract entry type and cite key
  header <- regmatches(entry, regexpr("^@\\s*(\\w+)\\s*\\{\\s*([^,]*)", entry,
                                       perl = TRUE))
  parts <- regmatches(header, regexec("^@\\s*(\\w+)\\s*\\{\\s*(.*)", header,
                                       perl = TRUE))[[1]]
  entry_type <- tolower(parts[2])
  cite_key   <- trimws(parts[3])

  # Skip non-record types
  if (entry_type %in% c("string", "preamble", "comment")) {
    return(NULL)
  }

  # Remove header and trailing brace
  body <- sub("^@\\s*\\w+\\s*\\{[^,]*,?", "", entry, perl = TRUE)
  body <- sub("\\}\\s*$", "", body)

  # Parse fields: name = {value} or name = "value" or name = number
  fields <- .bib_parse_fields(body)

  .bib_null_to_na <- function(x) if (is.null(x) || !nzchar(trimws(x))) NA_character_ else trimws(x)

  tibble::tibble(
    cite_key   = cite_key,
    entry_type = entry_type,
    title      = .bib_null_to_na(fields[["title"]]),
    author     = .bib_null_to_na(fields[["author"]]),
    year       = .bib_null_to_na(fields[["year"]]),
    doi        = .bib_null_to_na(fields[["doi"]]),
    journal    = .bib_null_to_na(
      fields[["journal"]] %||% fields[["journaltitle"]] %||%
      fields[["booktitle"]]
    ),
    abstract   = .bib_null_to_na(fields[["abstract"]]),
    volume     = .bib_null_to_na(fields[["volume"]]),
    pages      = .bib_null_to_na(fields[["pages"]]),
    keywords   = .bib_null_to_na(fields[["keywords"]])
  )
}

#' Parse BibTeX field assignments from the body of an entry
#' @noRd
.bib_parse_fields <- function(body) {
  fields <- list()
  i <- 1L
  n <- nchar(body)

  while (i <= n) {
    # skip whitespace/commas
    while (i <= n && grepl("[\\s,]", substr(body, i, i), perl = TRUE)) i <- i + 1L
    if (i > n) break

    # read field name
    name_start <- i
    while (i <= n && !grepl("[=\\s]", substr(body, i, i), perl = TRUE)) i <- i + 1L
    field_name <- tolower(trimws(substring(body, name_start, i - 1L)))
    if (!nzchar(field_name)) break

    # skip to =
    while (i <= n && substr(body, i, i) != "=") i <- i + 1L
    i <- i + 1L  # skip =

    # skip whitespace
    while (i <= n && grepl("\\s", substr(body, i, i), perl = TRUE)) i <- i + 1L
    if (i > n) break

    ch <- substr(body, i, i)
    if (ch == "{") {
      # brace-delimited value
      depth <- 0L
      val_start <- i + 1L
      while (i <= n) {
        c2 <- substr(body, i, i)
        if (c2 == "{") depth <- depth + 1L
        if (c2 == "}") depth <- depth - 1L
        if (depth == 0L) break
        i <- i + 1L
      }
      value <- substring(body, val_start, i - 1L)
      i <- i + 1L  # skip closing }
    } else if (ch == "\"") {
      # quote-delimited value
      i <- i + 1L
      val_start <- i
      while (i <= n && substr(body, i, i) != "\"") i <- i + 1L
      value <- substring(body, val_start, i - 1L)
      i <- i + 1L  # skip closing "
    } else {
      # bare value (number or macro)
      val_start <- i
      while (i <= n && !grepl("[,}\\s]", substr(body, i, i), perl = TRUE)) i <- i + 1L
      value <- substring(body, val_start, i - 1L)
    }

    # Clean up value: collapse whitespace
    value <- gsub("\\s+", " ", trimws(value))
    fields[[field_name]] <- value
  }

  fields
}

#' Build authors and authorships from BibTeX author strings
#' @noRd
.bib_build_authors <- function(author_strings, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(author_strings)) {
    au_str <- author_strings[i]
    if (is.na(au_str)) next

    # Split on " and "
    names <- trimws(strsplit(au_str, "\\s+and\\s+", perl = TRUE)[[1]])
    names <- names[nzchar(names)]
    if (length(names) == 0L) next

    # Normalize "Last, First" -> "First Last"
    names <- vapply(names, function(nm) {
      if (grepl(",", nm, fixed = TRUE)) {
        parts <- trimws(strsplit(nm, ",", fixed = TRUE)[[1]])
        if (length(parts) >= 2L) {
          paste(parts[2], parts[1])
        } else {
          nm
        }
      } else {
        nm
      }
    }, character(1), USE.NAMES = FALSE)

    all_authors <- c(all_authors, names)

    authorship_rows[[i]] <- tibble::tibble(
      work_id = work_ids[i],
      author_name = names,
      position = seq_along(names),
      is_corresponding = c(TRUE, rep(FALSE, max(0L, length(names) - 1L)))
    )
  }

  if (length(authorship_rows) == 0L) {
    return(list(
      authors = .empty_authors(),
      authorships = .empty_authorships()
    ))
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

#' Build concepts from BibTeX keywords strings
#' @noRd
.bib_build_concepts <- function(keywords_vec, work_ids) {
  rows <- list()
  for (i in seq_along(keywords_vec)) {
    kw <- keywords_vec[i]
    if (is.na(kw)) next
    terms <- trimws(strsplit(kw, "[;,]")[[1]])
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

# ---- shared bibliometrix converter ------------------------------------------

#' Convert a bibliometrix data.frame to sm_corpus
#' @noRd
.bibliometrix_df_to_corpus <- function(bib_df, source_label, source_file) {
  if (nrow(bib_df) == 0L) {
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = source_file,
                       reader = paste0("bibliometrix/", source_label))
    ))
  }

  .col <- function(df, ...) {
    nms <- c(...)
    for (nm in nms) {
      if (nm %in% names(df)) return(df[[nm]])
    }
    rep(NA_character_, nrow(df))
  }

  n <- nrow(bib_df)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(.col(bib_df, "DI", "DOI")),
    title     = .col(bib_df, "TI", "Title"),
    abstract  = .col(bib_df, "AB", "Abstract"),
    year      = as.integer(.col(bib_df, "PY", "Year")),
    type      = .col(bib_df, "DT", "Document.Type"),
    source_id = NA_character_,
    cited_by_count = suppressWarnings(as.integer(.col(bib_df, "TC", "Cited.by"))),
    oa_status = NA_character_,
    language  = .col(bib_df, "LA", "Language"),
    pmid      = NA_character_,
    arxiv_id  = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )
  works <- .ensure_works_schema(works)

  # Authors from AU field
  au_strings <- .col(bib_df, "AU", "Author")
  auth_result <- .bib_build_authors_from_bibliometrix(au_strings, work_ids)

  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = source_label,
    source_id_external = NA_character_,
    fetch_date = Sys.time(),
    query     = source_file,
    engine    = "bibliometrix",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    provenance  = provenance,
    metadata    = list(source_file = source_file,
                        reader = paste0("bibliometrix/", source_label))
  )
}

#' Build authors from bibliometrix AU-style strings (semicolon separated)
#' @noRd
.bib_build_authors_from_bibliometrix <- function(au_strings, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(au_strings)) {
    au <- au_strings[i]
    if (is.na(au) || !nzchar(trimws(au))) next
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

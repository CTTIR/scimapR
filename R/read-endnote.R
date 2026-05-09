#' Read EndNote XML export files
#'
#' @description
#' Parse EndNote XML export files into an `sm_corpus` object.
#' Uses [xml2] to extract record metadata from the EndNote XML format.
#'
#' @param path Character scalar. Path to an EndNote XML file.
#' @param encoding Character scalar. File encoding (default `"UTF-8"`).
#' @param verbose Logical. Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An [sm_corpus] object.
#'
#' @section Implementation:
#' The parser uses [xml2::read_xml()] to read the EndNote XML format. Each
#' `xml/records/record` element (or `records/record`) is processed. The
#' following fields are extracted:
#' - `titles/title/style` for the title
#' - `contributors/authors/author/style` for author names
#' - `dates/year/style` for year
#' - `periodical/full-title/style` or `secondary-title/style` for journal
#' - `electronic-resource-num/style` for DOI
#' - `abstract/style` for abstract
#' - `ref-type` attribute for document type
#' - `keywords/keyword/style` for keywords
#' - `accession-num/style` for record identifier
#'
#' No bibliometrix engine is available since EndNote XML is not directly
#' supported as a format by `bibliometrix::convert2df()`.
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
#' corpus <- sm_read_endnote("library.xml")
#' corpus$works
#' }
sm_read_endnote <- function(path,
                            encoding = "UTF-8",
                            verbose = TRUE,
                            call = rlang::caller_env()) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.file {path}}", call = call)
  }

  .sm_verbose("Reading EndNote XML: {.file {path}}", verbose)

  doc <- xml2::read_xml(path, encoding = encoding)

  # EndNote XML can have various root elements: xml, records, etc.
  records <- xml2::xml_find_all(doc, ".//record")

  if (length(records) == 0L) {
    .sm_verbose("No records found in EndNote XML.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_endnote")
    ))
  }

  parsed <- lapply(records, .endnote_parse_record)
  n <- length(parsed)
  work_ids <- .generate_work_id(n)

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(vapply(parsed, function(r) r$doi, character(1))),
    title     = vapply(parsed, function(r) r$title, character(1)),
    abstract  = vapply(parsed, function(r) r$abstract, character(1)),
    year      = suppressWarnings(
      as.integer(vapply(parsed, function(r) r$year, character(1)))
    ),
    type      = vapply(parsed, function(r) r$ref_type, character(1)),
    source_id = NA_character_,
    cited_by_count = NA_integer_,
    oa_status = NA_character_,
    language  = vapply(parsed, function(r) r$language, character(1)),
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
  auth_result <- .endnote_build_authors(author_lists, work_ids)

  # --- sources (journals) --------------------------------------------------
  source_names <- vapply(parsed, function(r) r$journal, character(1))
  source_issns <- vapply(parsed, function(r) r$issn, character(1))
  sources <- .empty_sources()
  if (any(!is.na(source_names))) {
    unames <- unique(stats::na.omit(source_names))
    sids <- .generate_source_id(length(unames))
    s_issn <- vapply(unames, function(nm) {
      idx <- which(source_names == nm & !is.na(source_issns))[1]
      if (!is.na(idx)) source_issns[idx] else NA_character_
    }, character(1), USE.NAMES = FALSE)

    sources <- tibble::tibble(
      source_id = sids,
      issn_l = s_issn,
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
  concepts <- .endnote_build_concepts(kw_lists, work_ids)

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "endnote",
    source_id_external = vapply(parsed, function(r) r$accession_num,
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

  .sm_verbose("Parsed {n} EndNote record{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_endnote")
  )
}

# ---- EndNote XML parsing helpers -------------------------------------------

#' Parse a single EndNote XML record node
#' @noRd
.endnote_parse_record <- function(node) {
  .get_text <- function(node, xpath) {
    # EndNote wraps text in <style> elements; try with and without
    found <- xml2::xml_find_first(node, xpath)
    if (is.na(found)) {
      # Try without /style suffix
      alt_xpath <- sub("/style$", "", xpath)
      found <- xml2::xml_find_first(node, alt_xpath)
    }
    if (is.na(found)) return(NA_character_)
    txt <- xml2::xml_text(found, trim = TRUE)
    if (!nzchar(txt)) NA_character_ else txt
  }

  # Title
  title <- .get_text(node, ".//titles/title/style")
  if (is.na(title)) {
    title <- .get_text(node, ".//titles/title")
  }

  # Authors
  author_nodes <- xml2::xml_find_all(node, ".//contributors/authors/author")
  authors <- if (length(author_nodes) > 0L) {
    vapply(author_nodes, function(an) {
      txt <- xml2::xml_text(an, trim = TRUE)
      if (nzchar(txt)) txt else NA_character_
    }, character(1))
  } else {
    character()
  }
  authors <- authors[!is.na(authors)]

  # Year
  year <- .get_text(node, ".//dates/year/style")
  if (is.na(year)) year <- .get_text(node, ".//dates/year")

  # Journal (secondary-title or periodical/full-title)
  journal <- .get_text(node, ".//periodical/full-title/style")
  if (is.na(journal)) journal <- .get_text(node, ".//periodical/full-title")
  if (is.na(journal)) journal <- .get_text(node, ".//secondary-title/style")
  if (is.na(journal)) journal <- .get_text(node, ".//secondary-title")

  # DOI (electronic-resource-num)
  doi <- .get_text(node, ".//electronic-resource-num/style")
  if (is.na(doi)) doi <- .get_text(node, ".//electronic-resource-num")

  # Abstract
  abstract <- .get_text(node, ".//abstract/style")
  if (is.na(abstract)) abstract <- .get_text(node, ".//abstract")

  # ref-type attribute
  ref_type_attr <- xml2::xml_attr(node, "ref-type")
  ref_type <- if (!is.na(ref_type_attr)) {
    # EndNote uses numeric ref-type codes; map common ones
    ref_type_map <- c(
      "0" = "generic", "1" = "journal-article", "2" = "book",
      "3" = "book-section", "4" = "conference-paper", "5" = "book-section",
      "6" = "edited-book", "7" = "thesis", "10" = "conference-paper",
      "12" = "report", "13" = "report", "15" = "patent",
      "17" = "journal-article", "21" = "journal-article",
      "25" = "thesis", "27" = "report", "28" = "report",
      "31" = "dataset", "43" = "webpage", "47" = "preprint"
    )
    ref_type_map[ref_type_attr] %||% ref_type_attr
  } else {
    NA_character_
  }

  # ISSN
  issn <- .get_text(node, ".//isbn/style")
  if (is.na(issn)) issn <- .get_text(node, ".//isbn")

  # Language
  language <- .get_text(node, ".//language/style")
  if (is.na(language)) language <- .get_text(node, ".//language")

  # Keywords
  kw_nodes <- xml2::xml_find_all(node, ".//keywords/keyword")
  keywords <- if (length(kw_nodes) > 0L) {
    vapply(kw_nodes, function(kn) {
      xml2::xml_text(kn, trim = TRUE)
    }, character(1))
  } else {
    character()
  }
  keywords <- keywords[nzchar(keywords)]

  # Accession number
  accession_num <- .get_text(node, ".//accession-num/style")
  if (is.na(accession_num)) {
    accession_num <- .get_text(node, ".//accession-num")
  }
  # Also try rec-number
  if (is.na(accession_num)) {
    accession_num <- .get_text(node, ".//rec-number")
  }

  list(
    title         = title,
    authors       = authors,
    year          = year,
    journal       = journal,
    doi           = doi,
    abstract      = abstract,
    ref_type      = ref_type,
    issn          = issn,
    language      = language,
    keywords      = keywords,
    accession_num = accession_num
  )
}

#' Build authors from EndNote author lists
#' @noRd
.endnote_build_authors <- function(author_lists, work_ids) {
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

#' Build concepts from EndNote keyword lists
#' @noRd
.endnote_build_concepts <- function(kw_lists, work_ids) {
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

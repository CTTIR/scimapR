#' Read PubMed XML files
#'
#' @description
#' Parse PubMed XML export files (NCBI DTD format) into an `sm_corpus`
#' object. Extracts article metadata from `PubmedArticle` nodes including
#' PMID, title, abstract, journal, authors, MeSH terms, DOI, and
#' publication type.
#'
#' @param path Character scalar. Path to a PubMed XML file.
#' @param encoding Character scalar. File encoding (default `"UTF-8"`).
#' @param engine Character scalar. One of `"native"` (built-in parser using
#'   [xml2]), `"bibliometrix"` (delegate to `bibliometrix::convert2df()`),
#'   or `"auto"` (try bibliometrix first, fall back to native).
#' @param verbose Logical. Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An [sm_corpus] object.
#'
#' @section Implementation:
#' The native parser uses [xml2::read_xml()] to parse the NCBI PubMed XML
#' DTD. Each `PubmedArticle` element is processed to extract:
#' - `MedlineCitation/PMID` for the PubMed identifier
#' - `MedlineCitation/Article/ArticleTitle` for the title
#' - `MedlineCitation/Article/Abstract/AbstractText` for the abstract
#'   (multiple sections are concatenated)
#' - `MedlineCitation/Article/Journal/Title` and `/ISSN` for the journal
#' - `MedlineCitation/Article/Journal/JournalIssue/PubDate/Year` for year
#' - `MedlineCitation/Article/AuthorList/Author` for authors
#' - `MedlineCitation/MeshHeadingList/MeshHeading` for MeSH terms
#' - `PubmedData/ArticleIdList/ArticleId[@IdType='doi']` for DOI
#' - `MedlineCitation/Article/PublicationTypeList` for document type
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
#' corpus <- sm_read_pubmed_xml("pubmed_result.xml")
#' corpus$works
#' }
sm_read_pubmed_xml <- function(path,
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
    return(.pubmed_via_bibliometrix(path, call = call))
  }

  if (engine == "auto") {
    corpus <- tryCatch(
      .pubmed_via_bibliometrix(path, call = call),
      error = function(e) NULL
    )
    if (!is.null(corpus)) return(corpus)
    .sm_verbose("bibliometrix engine failed; falling back to native parser.",
                verbose)
  }

  # --- native parser -------------------------------------------------------
  .sm_verbose("Reading PubMed XML: {.file {path}}", verbose)

  doc <- xml2::read_xml(path, encoding = encoding)
  articles <- xml2::xml_find_all(doc, ".//PubmedArticle")

  if (length(articles) == 0L) {
    .sm_verbose("No PubmedArticle nodes found.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_pubmed_xml")
    ))
  }

  parsed <- lapply(articles, .pubmed_parse_article)
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
    type      = vapply(parsed, function(r) r$pub_type, character(1)),
    source_id = NA_character_,
    cited_by_count = NA_integer_,
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
  auth_result <- .pubmed_build_authors(author_lists, aff_lists, work_ids)

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

  # --- concepts (MeSH terms) -----------------------------------------------
  mesh_lists <- lapply(parsed, function(r) r$mesh_terms)
  concepts <- .pubmed_build_concepts(mesh_lists, work_ids)

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "pubmed",
    source_id_external = vapply(parsed, function(r) r$pmid, character(1)),
    fetch_date = Sys.time(),
    query     = path,
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  .sm_verbose("Parsed {n} PubMed article{?s}.", verbose)

  new_sm_corpus(
    works       = works,
    authors     = auth_result$authors,
    authorships = auth_result$authorships,
    sources     = sources,
    concepts    = concepts,
    provenance  = provenance,
    metadata    = list(source_file = path, reader = "sm_read_pubmed_xml")
  )
}

# ---- bibliometrix delegation ------------------------------------------------

.pubmed_via_bibliometrix <- function(path, call = rlang::caller_env()) {
  rlang::check_installed("bibliometrix",
    reason = "to use the bibliometrix engine for PubMed XML files.",
    call = call
  )
  bib_df <- bibliometrix::convert2df(file = path, dbsource = "pubmed",
                                      format = "xml")
  .bibliometrix_df_to_corpus(bib_df, source_label = "pubmed",
                              source_file = path)
}

# ---- PubMed XML parsing helpers --------------------------------------------

#' Parse a single PubmedArticle XML node
#' @noRd
.pubmed_parse_article <- function(node) {
  .xml_text_or_na <- function(node, xpath) {
    found <- xml2::xml_find_first(node, xpath)
    if (is.na(found)) return(NA_character_)
    txt <- xml2::xml_text(found, trim = TRUE)
    if (!nzchar(txt)) NA_character_ else txt
  }

  # PMID
  pmid <- .xml_text_or_na(node,
    ".//MedlineCitation/PMID")

  # Title
  title <- .xml_text_or_na(node,
    ".//MedlineCitation/Article/ArticleTitle")

  # Abstract (may have multiple AbstractText sections)
  abs_nodes <- xml2::xml_find_all(node,
    ".//MedlineCitation/Article/Abstract/AbstractText")
  if (length(abs_nodes) > 0L) {
    abs_parts <- vapply(abs_nodes, function(an) {
      label <- xml2::xml_attr(an, "Label")
      txt <- xml2::xml_text(an, trim = TRUE)
      if (!is.na(label) && nzchar(label)) {
        paste0(label, ": ", txt)
      } else {
        txt
      }
    }, character(1))
    abstract <- paste(abs_parts, collapse = " ")
  } else {
    abstract <- NA_character_
  }

  # Journal
  journal <- .xml_text_or_na(node,
    ".//MedlineCitation/Article/Journal/Title")
  issn <- .xml_text_or_na(node,
    ".//MedlineCitation/Article/Journal/ISSN")

  # Year - try multiple paths
  year <- .xml_text_or_na(node,
    ".//MedlineCitation/Article/Journal/JournalIssue/PubDate/Year")
  if (is.na(year)) {
    # Try MedlineDate
    medline_date <- .xml_text_or_na(node,
      ".//MedlineCitation/Article/Journal/JournalIssue/PubDate/MedlineDate")
    if (!is.na(medline_date)) {
      yr_match <- regmatches(medline_date,
                              regexpr("\\d{4}", medline_date))
      if (length(yr_match) > 0L) year <- yr_match
    }
  }

  # Authors
  author_nodes <- xml2::xml_find_all(node,
    ".//MedlineCitation/Article/AuthorList/Author")
  authors <- character()
  affiliations <- character()
  if (length(author_nodes) > 0L) {
    authors <- vapply(author_nodes, function(an) {
      last <- xml2::xml_text(xml2::xml_find_first(an, ".//LastName"),
                              trim = TRUE)
      fore <- xml2::xml_text(xml2::xml_find_first(an, ".//ForeName"),
                              trim = TRUE)
      if (is.na(last) || !nzchar(last)) {
        # Collective name
        coll <- xml2::xml_text(xml2::xml_find_first(an, ".//CollectiveName"),
                                trim = TRUE)
        if (!is.na(coll) && nzchar(coll)) return(coll)
        return(NA_character_)
      }
      if (!is.na(fore) && nzchar(fore)) {
        paste(fore, last)
      } else {
        last
      }
    }, character(1))

    affiliations <- vapply(author_nodes, function(an) {
      aff <- xml2::xml_text(
        xml2::xml_find_first(an, ".//AffiliationInfo/Affiliation"),
        trim = TRUE
      )
      if (is.na(aff) || !nzchar(aff)) NA_character_ else aff
    }, character(1))

    # Remove NAs from authors
    keep <- !is.na(authors)
    authors <- authors[keep]
    affiliations <- affiliations[keep]
  }

  # DOI
  doi <- .xml_text_or_na(node,
    ".//PubmedData/ArticleIdList/ArticleId[@IdType='doi']")

  # Publication type
  pub_type_nodes <- xml2::xml_find_all(node,
    ".//MedlineCitation/Article/PublicationTypeList/PublicationType")
  pub_type <- if (length(pub_type_nodes) > 0L) {
    xml2::xml_text(pub_type_nodes[1], trim = TRUE)
  } else {
    NA_character_
  }

  # Language
  language <- .xml_text_or_na(node,
    ".//MedlineCitation/Article/Language")

  # MeSH terms
  mesh_nodes <- xml2::xml_find_all(node,
    ".//MedlineCitation/MeshHeadingList/MeshHeading/DescriptorName")
  mesh_terms <- if (length(mesh_nodes) > 0L) {
    vapply(mesh_nodes, function(mn) xml2::xml_text(mn, trim = TRUE),
           character(1))
  } else {
    character()
  }

  list(
    pmid         = pmid,
    title        = title,
    abstract     = abstract,
    journal      = journal,
    issn         = issn,
    year         = year,
    doi          = doi,
    authors      = authors,
    affiliations = affiliations,
    pub_type     = pub_type,
    language     = language,
    mesh_terms   = mesh_terms
  )
}

#' Build authors from PubMed author lists
#' @noRd
.pubmed_build_authors <- function(author_lists, aff_lists, work_ids) {
  all_authors <- character()
  authorship_rows <- list()

  for (i in seq_along(author_lists)) {
    names <- author_lists[[i]]
    if (length(names) == 0L) next
    names <- trimws(names)
    names <- names[nzchar(names)]
    if (length(names) == 0L) next

    affs <- aff_lists[[i]]
    raw_aff <- if (length(affs) == length(names)) {
      affs
    } else {
      rep(NA_character_, length(names))
    }

    all_authors <- c(all_authors, names)
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

#' Build concepts from PubMed MeSH terms
#' @noRd
.pubmed_build_concepts <- function(mesh_lists, work_ids) {
  rows <- list()
  for (i in seq_along(mesh_lists)) {
    terms <- mesh_lists[[i]]
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
      vocabulary = "mesh"
    )
  }
  if (length(rows) == 0L) return(.empty_concepts())
  dplyr::bind_rows(rows)
}

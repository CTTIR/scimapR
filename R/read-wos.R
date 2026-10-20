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
#' Continuation lines begin with three spaces. Tags parsed:
#' AU or AF (authors), TI (title), SO (source), SN and EI (ISSN and
#' electronic ISSN), J9 and JI (source abbreviations), AB (abstract),
#' DI (DOI), PY (year), DT (document type), LA (language), TC (times
#' cited), UT (accession number, kept in `provenance`), PM (PubMed ID),
#' C1 (addresses), RP (corresponding authors), CR (cited references),
#' DE (author keywords),
#' ID (Keywords Plus), WC (Web of Science categories) and SC (research
#' areas). Other tags are not read.
#'
#' Each distinct SO becomes a row of `sources`, with `issn_l` from SN
#' (EI when SN is missing), `issn` holding SN and EI, and the abbreviations
#' J9 and JI in the columns `abbreviation` and `iso_abbreviation`.
#'
#' DE, ID, WC and SC become `concepts`, one row per `;`-separated term, in
#' the vocabularies `"author-keywords"`, `"keywords-plus"`, `"wos-category"`
#' and `"wos-subject-category"` of [sm_concept_vocabularies()]. Terms keep
#' the case of the file.
#'
#' Author names are stored in the AU form, such as "J Smith" for
#' "Smith, J", and `authors$display_name_alternatives` keeps the name as
#' the file writes it, which tells a surname of several words such as
#' "Garcia Lopez" from the initials.
#'
#' Both parsers write one authorship row per author and address. The names
#' in the brackets of C1 link authors to addresses: each name belongs to
#' the author with the same full name (from AF), else to the one with the
#' same surname and initials, else to the one with the same surname and
#' first initial, so a short surname such as "He" never takes the address
#' of "Chen". An address that C1 lists without names, as older records do,
#' belongs to every author of the record, so each of them gets a row for
#' it. An address whose names designate none of the authors belongs to the
#' author of a single-author record and else to nobody.
#'
#' The corresponding authors come from RP, which names them before
#' "(corresponding author)" ("(reprint author)" in older files), in any
#' case, with each name and its address on a line of its own or on one
#' line. The authors these names designate, matched like the names of C1,
#' get `is_corresponding = TRUE` on all their rows and the other authors
#' `FALSE`. When a name fits several authors equally (namesakes with the
#' same surname and initials), the one whose C1 addresses include the
#' address RP gives with the name is meant; if that does not tell them
#' apart, they get `NA`. A record without RP, or whose RP designates none
#' of its authors for certain, gets `NA` (unknown) for all its authors;
#' the native parser reports the number of such records when
#' `verbose = TRUE`.
#'
#' The `"bibliometrix"` engine (also used by `"auto"` when bibliometrix can
#' read the file) converts the data frame of `bibliometrix::convert2df()`
#' as [as_sm_corpus()] does: it reads the same tags into `sources`,
#' `references` and `concepts`, tells authors apart by the full names of AF
#' and links C1 and RP to the authors by the same rule.
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
      sources = .empty_sources_abbrev(),
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
      sources = .empty_sources_abbrev(),
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
  auth_result <- .wos_build_authors(parsed, work_ids)
  n_unknown <- auth_result$n_unknown
  if (n_unknown > 0L) {
    .sm_verbose(paste0(
      "The corresponding author of {n_unknown} record{?s} is unknown ",
      "({.field is_corresponding} is {.code NA}): no RP field, or its ",
      "names designate none of the authors for certain."
    ), verbose)
  }

  # --- sources -------------------------------------------------------------
  source_names <- vapply(parsed, function(r) r$source, character(1))
  sources <- .empty_sources_abbrev()
  if (any(!is.na(source_names))) {
    unames <- unique(stats::na.omit(source_names))
    sids <- .generate_source_id(length(unames))
    # ISSNs and abbreviations from the first record of each source
    first <- parsed[match(unames, source_names)]
    field <- function(nm) vapply(first, function(r) r[[nm]], character(1))
    sn <- field("sn")
    ei <- field("ei")
    issn_l <- sn
    issn_l[is.na(issn_l)] <- ei[is.na(issn_l)]
    sources <- tibble::tibble(
      source_id = sids,
      issn_l = issn_l,
      issn = lapply(seq_along(sids), function(i) {
        x <- c(sn[i], ei[i])
        unique(x[!is.na(x)])
      }),
      display_name = unames,
      type = "journal",
      is_oa = NA,
      publisher = NA_character_,
      publisher_country = NA_character_,
      abbreviation = field("j9"),
      iso_abbreviation = field("ji")
    )
    works$source_id <- sids[match(source_names, unames)]
  }

  # --- references -----------------------------------------------------------
  references <- .wos_build_references(parsed, work_ids)

  # --- concepts (keywords and categories) ------------------------------------
  concepts <- .wos_build_concepts(parsed, work_ids)

  # --- provenance -----------------------------------------------------------
  provenance <- tibble::tibble(
    work_id   = work_ids,
    source    = "wos",
    source_id_external = vapply(parsed, function(r) r$ut, character(1)),
    fetch_date = Sys.time(),
    query     = .file_step_path(path),
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_,
    kind      = "file"
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
      if (current_tag %in% c("AU", "AF", "CR", "C1", "RP")) {
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
    full_names  = tags[["AF"]] %||% character(),
    reprint     = tags[["RP"]] %||% character(),
    title       = .get_single("TI"),
    source      = .get_single("SO"),
    sn          = .get_single("SN"),
    ei          = .get_single("EI"),
    j9          = .get_single("J9"),
    ji          = .get_single("JI"),
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
    wos_cat     = tags[["WC"]] %||% character(),
    keywords    = tags[["DE"]] %||% character(),
    keywords_plus = tags[["ID"]] %||% character()
  )
}

#' Build authors and authorships from WoS AU, AF, C1 and RP
#'
#' One authorship row per author and address, as in the bibliometrix
#' conversion: the names in the brackets of C1 link authors to addresses
#' (`.bx_link_addresses()`), with AF giving the full names, and the names
#' of RP mark the corresponding authors (`.bx_rp_flags()`).
#' @return A list: `authors`, `authorships` and `n_unknown`, the number of
#'   records with authors whose corresponding author is unknown.
#' @noRd
.wos_build_authors <- function(parsed, work_ids) {
  n <- length(parsed)
  entries <- function(nm) {
    lapply(parsed, function(r) {
      x <- trimws(r[[nm]])
      x[nzchar(x)]
    })
  }
  spelled <- entries("authors")
  k <- lengths(spelled)
  if (sum(k) == 0L) {
    return(list(authors = .empty_authors(),
                authorships = .empty_authorships(), n_unknown = 0L))
  }
  row <- rep(seq_len(n), k)
  all_spelled <- unlist(spelled, use.names = FALSE)

  # Normalize "Last, First" -> "First Last"
  all_authors <- vapply(all_spelled, function(nm) {
    if (grepl(",", nm, fixed = TRUE)) {
      parts <- trimws(strsplit(nm, ",", fixed = TRUE)[[1]])
      if (length(parts) >= 2L) paste(parts[2], parts[1]) else nm
    } else {
      nm
    }
  }, character(1), USE.NAMES = FALSE)

  # AF entries belong to the AU entries when a record has as many of each
  af <- entries("full_names")
  same <- lengths(af) == k
  af_item <- rep(NA_character_, length(all_spelled))
  af_item[same[row]] <- unlist(af[same], use.names = FALSE)
  who <- .bx_parse_authors(all_spelled, af_item)

  joined <- function(nm) {
    vapply(entries(nm), function(x) {
      if (length(x) > 0L) paste(x, collapse = "; ") else NA_character_
    }, character(1))
  }
  segments <- .bx_c1_segments(joined("affiliations"))
  linked <- .bx_link_addresses(who, row, segments, n)
  corresponding <- .bx_rp_flags(who, row, joined("reprint"), n, linked)
  n_unknown <- sum(tapply(is.na(corresponding), row, all))

  unique_names <- unique(all_authors)
  author_ids <- .generate_author_id(length(unique_names))
  # the names as the file writes them ("Garcia Lopez, M"), which tell the
  # surname from the initials
  by_name <- split(all_spelled, factor(all_authors, levels = unique_names))

  authors <- tibble::tibble(
    author_id = author_ids,
    orcid = NA_character_,
    display_name = unique_names,
    display_name_alternatives = unname(Map(setdiff, by_name, unique_names)),
    inferred_gender = NA_character_,
    gender_confidence = NA_real_,
    gender_method = NA_character_
  )

  m <- lengths(linked)
  position <- sequence(k)
  authorships <- tibble::tibble(
    work_id = rep(work_ids[row], m),
    author_id = rep(author_ids[match(all_authors, unique_names)], m),
    position = rep(position, m),
    is_corresponding = rep(corresponding, m),
    institution_id = NA_character_,
    raw_affiliation = unlist(linked, use.names = FALSE),
    country_code = NA_character_
  )

  list(authors = authors, authorships = authorships, n_unknown = n_unknown)
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

    rows[[length(rows) + 1L]] <- tibble::tibble(
      work_id = work_ids[i],
      ref_index = seq_along(refs),
      cited_work_id = NA_character_,
      cited_doi = .cr_doi(refs),
      cited_raw = refs
    )
  }
  if (length(rows) == 0L) return(.empty_references())
  dplyr::bind_rows(rows)
}

#' Build concepts from WoS DE/ID/SC/WC tags
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

    # Research areas (SC)
    if (length(r$subject_cat) > 0L) {
      sc <- trimws(unlist(strsplit(paste(r$subject_cat, collapse = ";"), ";")))
      sc <- sc[nzchar(sc)]
      if (length(sc) > 0L) {
        terms <- c(terms, sc)
        vocab <- c(vocab, rep("wos-subject-category", length(sc)))
      }
    }

    # Web of Science categories (WC)
    if (length(r$wos_cat) > 0L) {
      wc <- trimws(unlist(strsplit(paste(r$wos_cat, collapse = ";"), ";")))
      wc <- wc[nzchar(wc)]
      if (length(wc) > 0L) {
        terms <- c(terms, wc)
        vocab <- c(vocab, rep("wos-category", length(wc)))
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

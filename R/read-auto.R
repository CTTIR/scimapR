#' Auto-detect bibliographic file format and read
#'
#' @description
#' Detect the bibliographic file format from the file extension and content,
#' then dispatch to the appropriate reader function.
#'
#' @param path Character scalar. Path to a bibliographic file.
#' @param encoding Character scalar. File encoding (default `"UTF-8"`).
#' @param engine Character scalar. One of `"native"` (built-in parser),
#'   `"bibliometrix"` (delegate to `bibliometrix::convert2df()`), or
#'   `"auto"` (try bibliometrix first, fall back to native). Passed through
#'   to the selected reader. Ignored for formats without engine support
#'   (OpenAlex JSON, Zotero, EndNote XML).
#' @param verbose Logical. Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An [sm_corpus] object.
#'
#' @section Implementation:
#' Format detection proceeds in two stages:
#' 1. **Extension-based**: `.bib` (BibTeX), `.ris` (RIS), `.json`/`.jsonl`
#'    (OpenAlex JSON), `.xml` (PubMed XML or EndNote XML).
#' 2. **Content-based**: For `.csv`, `.tsv`, and `.txt` files, the first
#'    few lines are inspected for format-specific signatures:
#'    - WoS plaintext: begins with `FN ` or `PT ` tags
#'    - WoS tab-delimited: header contains PT, AU, TI and UT; also detected
#'      in `.tab` files and files without an extension
#'    - Scopus CSV: contains `EID` column header
#'    - Lens CSV: contains `Lens ID` column header
#'    - Dimensions CSV: contains `Dimensions ID` or `PubYear` header
#'    - Cochrane CSV: contains `Cochrane` in header or record-like structure
#'    - Zotero CSV: contains `Key` and `Item Type` columns
#'    - RIS-format content in non-`.ris` files
#'
#' For XML files, the parsed root distinguishes PubMed XML
#' (`PubmedArticleSet`, `PubmedArticle`, `PubmedBookArticleSet`) from
#' EndNote XML (`xml/records` or `records`). Unknown roots are unsupported;
#' malformed XML raises a file-reading error.
#'
#' For `.nbib` and `.enw`, the first 20 lines determine the content: RIS
#' records are accepted, but MEDLINE text (`PMID- ` in `.nbib`, `.txt` or
#' files without extensions) and Refer text (`%` tags in `.enw`) are not
#' supported. Export MEDLINE records as PubMed XML, or use
#' [sm_fetch_pubmed()]; export Refer libraries as RIS or EndNote XML.
#' A leading UTF-8 BOM is ignored for text format detection.
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
#' corpus <- sm_read_auto("references.bib")
#' corpus <- sm_read_auto("exported_data.csv")
#' }
sm_read_auto <- function(path,
                         encoding = "UTF-8",
                         engine = c("native", "bibliometrix", "auto"),
                         verbose = TRUE,
                         call = rlang::caller_env()) {
  engine <- rlang::arg_match(engine, error_call = call)

  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.file {path}}", call = call)
  }

  ext <- tolower(tools::file_ext(path))
  format <- .detect_format(path, ext, encoding, call)

  .sm_verbose("Detected format: {.val {format}}", verbose)

  switch(format,
    "bibtex" = sm_read_bib(path, encoding = encoding, engine = engine,
                            verbose = verbose, call = call),
    "ris" = sm_read_ris(path, encoding = encoding, engine = engine,
                         verbose = verbose, call = call),
    "wos" = sm_read_wos(path, encoding = encoding, engine = engine,
                         verbose = verbose, call = call),
    "scopus" = sm_read_scopus(path, encoding = encoding, engine = engine,
                               verbose = verbose, call = call),
    "pubmed-xml" = sm_read_pubmed_xml(path, encoding = encoding,
                                       engine = engine, verbose = verbose,
                                       call = call),
    "openalex-json" = sm_read_openalex_json(path, encoding = encoding,
                                             verbose = verbose, call = call),
    "cochrane" = sm_read_cochrane(path, encoding = encoding, engine = engine,
                                   verbose = verbose, call = call),
    "lens" = sm_read_lens(path, encoding = encoding, engine = engine,
                           verbose = verbose, call = call),
    "dimensions" = sm_read_dimensions(path, encoding = encoding,
                                       engine = engine, verbose = verbose,
                                       call = call),
    "zotero" = sm_read_zotero(path, encoding = encoding, verbose = verbose,
                               call = call),
    "endnote-xml" = sm_read_endnote(path, encoding = encoding,
                                     verbose = verbose, call = call),
    "medline" = cli::cli_abort(c(
      "{.file {path}} is MEDLINE text (PubMed {.file .nbib} format),
       which scimapR cannot read.",
      "i" = "Save the records from PubMed as XML and read them with
             {.fn sm_read_pubmed_xml}, or fetch them with
             {.fn sm_fetch_pubmed}."
    ), class = "scimapR_unsupported_format", call = call),
    "refer" = cli::cli_abort(c(
      "{.file {path}} is Refer/EndNote tagged text ({.file .enw}),
       which scimapR cannot read.",
      "i" = "Export the library as RIS or EndNote XML."
    ), class = "scimapR_unsupported_format", call = call),
    cli::cli_abort(c(
      "Cannot detect bibliographic file format for {.file {path}}.",
      "i" = "Extension: {.val {ext}}",
      "i" = paste0(
        "Supported formats: BibTeX (.bib), RIS (.ris),",
        " WoS plaintext or tab-delimited (.txt),",
        " Scopus CSV, Lens CSV, Dimensions CSV, Cochrane CSV/RIS,",
        " PubMed XML, OpenAlex JSON, Zotero CSV, EndNote XML."
      )
    ), class = "scimapR_unsupported_format", call = call)
  )
}

# ---- format detection -------------------------------------------------------

#' Detect bibliographic file format from extension and content
#' @noRd
.detect_format <- function(path, ext, encoding, call) {
  # --- unambiguous extensions first ----------------------------------------
  if (ext == "bib") return("bibtex")
  if (ext == "ris") return("ris")
  if (ext %in% c("json", "jsonl", "ndjson")) return("openalex-json")

  # --- XML: distinguish PubMed vs EndNote ----------------------------------
  if (ext == "xml") {
    return(.detect_xml_format(path, encoding, call = call))
  }

  # --- text / CSV / TSV: content-based detection ---------------------------
  first_lines <- tryCatch(
    readr::read_lines(path, n_max = 20L,
      locale = readr::locale(encoding = encoding)),
    error = function(e) character()
  )

  if (length(first_lines) == 0L) {
    cli::cli_abort(
      "Cannot read file for format detection: {.file {path}}",
      call = call
    )
  }

  first_lines[1] <- sub("^\ufeff", "", first_lines[1])
  header <- paste(first_lines, collapse = " ")
  if (ext %in% c("nbib", "enw")) {
    if (any(grepl("^TY  -", first_lines))) return("ris")
    if (ext == "nbib" && any(grepl("^PMID- ", first_lines))) return("medline")
    if (ext == "enw" && any(grepl("^%[A-Z0-9] ", first_lines))) return("refer")
    return("unknown")
  }
  if (ext %in% c("txt", "tsv", "tab", "")) {
    if (.wos_is_tabdelim(first_lines)) return("wos")
    if (any(grepl("^FN |^PT ", first_lines))) return("wos")
    if (ext %in% c("txt", "") && any(grepl("^PMID- ", first_lines))) {
      return("medline")
    }
    if (any(grepl("^TY  -", first_lines))) return("ris")
  }

  # CSV/TSV formats: check header columns

  if (ext %in% c("csv", "tsv", "txt", "tab", "")) {
    # Check for RIS content first (some Cochrane exports use .csv extension)
    if (any(grepl("^TY\\s{2}-", first_lines))) {
      return("ris")
    }

    header_upper <- toupper(header)

    # Scopus: has EID column
    if (grepl("\\bEID\\b", header_upper) &&
        grepl("\\bAUTHOR", header_upper, ignore.case = TRUE)) {
      return("scopus")
    }

    # Lens: has "Lens ID"
    if (grepl("LENS.ID|LENS ID", header_upper)) {
      return("lens")
    }

    # Dimensions: has "Dimensions ID" or "PubYear" column
    if (grepl("DIMENSIONS.ID|DIMENSIONS ID", header_upper) ||
        (grepl("\\bPUBYEAR\\b", header_upper) &&
         grepl("\\bTITLE\\b", header_upper))) {
      return("dimensions")
    }

    # Zotero: has "Key" and "Item Type" columns
    if (grepl("\\bKEY\\b", header_upper) &&
        grepl("ITEM.TYPE|ITEM TYPE", header_upper)) {
      return("zotero")
    }

    # Cochrane: check for cochrane-specific patterns
    if (grepl("COCHRANE", header_upper) ||
        (grepl("RECORD.NUMBER|RECORD NUMBER", header_upper))) {
      return("cochrane")
    }

    # Generic CSV with standard bibliometric columns - try Scopus as default
    if (grepl("\\bDOI\\b", header_upper) &&
        grepl("\\bTITLE\\b", header_upper) &&
        grepl("\\bAUTHOR", header_upper, ignore.case = TRUE)) {
      # Fall through to Scopus as the most common CSV format
      return("scopus")
    }
  }

  # Could not determine format
  "unknown"
}

#' Detect XML format (PubMed vs EndNote)
#' @noRd
.detect_xml_format <- function(path, encoding, call = rlang::caller_env()) {
  doc <- tryCatch(
    xml2::read_xml(path, encoding = encoding),
    error = function(e) {
      cli::cli_abort("Cannot parse {.file {path}} as XML.",
                     class = "scimapR_unreadable_file", parent = e, call = call)
    }
  )
  root <- xml2::xml_name(xml2::xml_root(doc))
  pubmed <- c("PubmedArticleSet", "PubmedArticle", "PubmedBookArticleSet")
  if (root %in% pubmed) return("pubmed-xml")
  children <- xml2::xml_name(xml2::xml_children(doc))
  if (root == "records" || (root == "xml" && "records" %in% children)) {
    return("endnote-xml")
  }
  "unknown"
}

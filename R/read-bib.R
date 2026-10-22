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
#' Protective braces are removed from titles, journals, abstracts, keywords
#' and DOIs; escaped braces remain literal. Common LaTeX accent commands
#' (`\"`, `\'`, `\^`, `\~`, `\=`, `\.`, `\c`, `\v`, `\u`,
#' `\H`, `\k`, `\r`, and backslash followed by a grave accent) decode
#' to precomposed letters where available, else the bare letter.
#' Letter commands `\ss`, `\o`, `\O`, `\aa`, `\AA`,
#' `\ae`, `\AE`, `\oe`, `\OE`, `\l`, `\L` and `\i` also decode, as do
#' `\&`, `\%`, `\$`, `\#` and `\_`. DOI cleaning only removes braces
#' and decodes those five escapes. Ties (`~`), `--` and math expressions
#' remain as written. Whitespace outside math is collapsed and trimmed.
#'
#' Only a lowercase `and` outside braces separates authors; a comma outside
#' braces flips a name from surname-first to given-name-first. Braced
#' corporate names stay together, and a trailing `and others` is retained.
#' Quoted field values end only at a quote outside braces. The first
#' isolated four-digit year (1000--2999) in `year` is used, falling back to
#' the BibLaTeX `date` field when no such year is present.
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
    return(.bib_via_bibliometrix(path, encoding = encoding,
                                 verbose = verbose, call = call))
  }

  if (engine == "auto") {
    corpus <- tryCatch(
      .bib_via_bibliometrix(path, encoding = encoding,
                            verbose = verbose, call = call),
      error = function(e) NULL
    )
    if (!is.null(corpus)) return(corpus)
    .sm_verbose("bibliometrix engine failed; falling back to native parser.",
                verbose)
  }

  # --- native parser -------------------------------------------------------
  .bib_via_native(path, encoding = encoding, verbose = verbose, call = call)
}

# ---- native engine ----------------------------------------------------------

#' Parse a BibTeX file with the built-in native parser
#' @noRd
.bib_via_native <- function(path, encoding = "UTF-8", verbose = TRUE,
                            call = rlang::caller_env()) {
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
  records <- records[!vapply(records, is.null, logical(1))]

  if (length(records) == 0L) {
    .sm_verbose("No BibTeX entries found.", verbose)
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      metadata = list(source_file = path, reader = "sm_read_bib")
    ))
  }

  .rec_col <- function(nm) {
    vapply(records, function(r) {
      v <- r[[nm]]
      if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)
    }, character(1))
  }

  df <- tibble::tibble(
    cite_key   = .rec_col("cite_key"),
    entry_type = .rec_col("entry_type"),
    title      = .rec_col("title"),
    author     = .rec_col("author"),
    year       = .rec_col("year"),
    date       = .rec_col("date"),
    doi        = .rec_col("doi"),
    journal    = .rec_col("journal"),
    abstract   = .rec_col("abstract"),
    volume     = .rec_col("volume"),
    pages      = .rec_col("pages"),
    keywords   = .rec_col("keywords")
  )

  for (field in c("title", "journal", "abstract", "keywords")) {
    df[[field]] <- .bib_clean_text(df[[field]])
  }
  df$doi <- .bib_clean_text(df$doi, doi = TRUE)
  year <- .year_from_text(df$year)
  year[is.na(year)] <- .year_from_text(df$date[is.na(year)])
  work_ids <- .generate_work_id(nrow(df))

  works <- tibble::tibble(
    work_id   = work_ids,
    doi       = .normalize_doi(df$doi),
    title     = df$title %||% NA_character_,
    abstract  = df$abstract %||% NA_character_,
    year      = year,
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
    query     = .file_step_path(path),
    engine    = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_,
    kind      = "file"
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

.bib_via_bibliometrix <- function(path, encoding = "UTF-8", verbose = TRUE,
                                  call = rlang::caller_env()) {
  rlang::check_installed("bibliometrix",
    reason = "to use the bibliometrix engine for BibTeX files.",
    call = call
  )

  # `bibliometrix::convert2df()` throws "undefined columns selected" on
  # field-sparse BibTeX entries (e.g. an @article missing journal/volume/
  # pages). We cannot patch bibliometrix (clean-room rule), so we defensively
  # catch that failure in scimapR's own normalization layer and fall back to
  # the native parser, which fills missing expected columns with typed NA and
  # maps robustly to the sm_corpus schema.
  bib_df <- tryCatch(
    suppressWarnings(
      bibliometrix::convert2df(file = path, dbsource = "generic",
                               format = "bibtex")
    ),
    error = function(e) e
  )

  if (inherits(bib_df, "error")) {
    cli::cli_warn(c(
      "!" = "The {.pkg bibliometrix} engine failed on {.file {path}}.",
      "i" = "Reason: {conditionMessage(bib_df)}",
      "i" = "Falling back to the native BibTeX parser."
    ))
    return(.bib_via_native(path, encoding = encoding, verbose = verbose,
                           call = call))
  }

  .bibliometrix_df_to_corpus(bib_df, source_label = "bibtex",
                              source_file = path)
}

# ---- BibTeX parsing helpers -------------------------------------------------

#' Collapse a character-vector slice, returning "" for an empty range
#' @noRd
.bib_slice <- function(chars, a, b) {
  if (b < a) return("")
  paste(chars[a:b], collapse = "")
}

#' Parse raw BibTeX text into a list of entry strings
#' @noRd
.bib_parse_entries <- function(raw) {
  # Match @type{ headers, then balance braces to find each entry's end.
  #
  # Performance (G4): the previous implementation called `substr(raw, pos, pos)`
  # and `substring(raw, s)` inside the brace-matching loop, each of which copies
  # from the (potentially multi-megabyte) source string -- O(n^2) overall on
  # large files. We split the source into a single character vector once and
  # index into it in O(1), making the whole scan linear.
  pattern <- "@\\s*(\\w+)\\s*\\{"
  m <- gregexpr(pattern, raw, perl = TRUE)[[1]]
  if (m[1] == -1L) return(list())
  match_len <- attr(m, "match.length")

  chars <- strsplit(raw, "", fixed = TRUE)[[1]]
  n <- length(chars)

  entries <- vector("list", length(m))
  k <- 0L
  for (mi in seq_along(m)) {
    s <- m[mi]
    # The matched header ends with the opening brace.
    open <- s + match_len[mi] - 1L
    depth <- 0L
    pos <- open
    while (pos <= n) {
      ch <- chars[pos]
      if (ch == "{") {
        depth <- depth + 1L
      } else if (ch == "}") {
        depth <- depth - 1L
      }
      if (depth == 0L) break
      pos <- pos + 1L
    }
    if (depth != 0L) next
    k <- k + 1L
    entries[[k]] <- paste(chars[s:pos], collapse = "")
  }

  if (k == 0L) return(list())
  entries[seq_len(k)]
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
  cite_key   <- parts[3]
  # Lightweight trim only when the cite key actually has surrounding space,
  # avoiding `trimws()`'s per-call overhead on every entry (G4).
  if (length(cite_key) && nzchar(cite_key) &&
      (startsWith(cite_key, " ") || endsWith(cite_key, " "))) {
    cite_key <- gsub("^\\s+|\\s+$", "", cite_key, perl = TRUE)
  }

  # Skip non-record types
  if (entry_type %in% c("string", "preamble", "comment")) {
    return(NULL)
  }

  # Remove header and trailing brace using cheap position arithmetic rather
  # than per-entry regex substitution, which dominated runtime on large
  # files (G4: `sub()` was ~60% of parse time).
  open <- regexpr("{", entry, fixed = TRUE)
  after <- substring(entry, open + 1L)              # "key, field = ..."
  comma_rel <- regexpr(",", after, fixed = TRUE)
  body <- if (comma_rel > 0L) substring(after, comma_rel + 1L) else after
  bl <- nchar(body)
  if (bl > 0L && substr(body, bl, bl) == "}") {
    body <- substr(body, 1L, bl - 1L)
  }

  # Parse fields: name = {value} or name = "value" or name = number
  fields <- .bib_parse_fields(body)

  # Field values arrive already whitespace-normalised from .bib_parse_fields(),
  # so no further trimming is needed here.
  .bib_null_to_na <- function(x) if (is.null(x) || !nzchar(x)) NA_character_ else x

  # Return a plain named character vector rather than a one-row tibble. Building
  # thousands of tibbles (one per entry) dominated parse time on large files
  # (G4); the caller assembles a single tibble from these vectors instead.
  c(
    cite_key   = cite_key,
    entry_type = entry_type,
    title      = .bib_null_to_na(fields[["title"]]),
    author     = .bib_null_to_na(fields[["author"]]),
    year       = .bib_null_to_na(fields[["year"]]),
    date       = .bib_null_to_na(fields[["date"]]),
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
#'
#' Like `.bib_parse_entries()`, this avoids per-character `substr()`/`grepl()`
#' calls (G4): the body is split into a character vector once and scanned with
#' O(1) indexing and set-membership whitespace tests rather than a regex per
#' character.
#' @noRd
.bib_parse_fields <- function(body) {
  fields <- list()
  chars <- strsplit(body, "", fixed = TRUE)[[1]]
  n <- length(chars)
  ws <- c(" ", "\t", "\n", "\r", "\f", "\v")
  i <- 1L

  while (i <= n) {
    # skip whitespace/commas
    while (i <= n && (chars[i] %in% ws || chars[i] == ",")) i <- i + 1L
    if (i > n) break

    # read field name (until '=' or whitespace); the scan already stops at
    # whitespace, so no trimming is required.
    name_start <- i
    while (i <= n && chars[i] != "=" && !(chars[i] %in% ws)) i <- i + 1L
    field_name <- tolower(.bib_slice(chars, name_start, i - 1L))
    if (!nzchar(field_name)) break

    # skip to =
    while (i <= n && chars[i] != "=") i <- i + 1L
    i <- i + 1L  # skip =

    # skip whitespace
    while (i <= n && chars[i] %in% ws) i <- i + 1L
    if (i > n) break

    ch <- chars[i]
    if (ch == "{") {
      # brace-delimited value
      depth <- 0L
      val_start <- i + 1L
      while (i <= n) {
        c2 <- chars[i]
        if (c2 == "{") {
          depth <- depth + 1L
        } else if (c2 == "}") {
          depth <- depth - 1L
        }
        if (depth == 0L) break
        i <- i + 1L
      }
      value <- .bib_slice(chars, val_start, i - 1L)
      i <- i + 1L  # skip closing }
    } else if (ch == "\"") {
      # quote-delimited value
      i <- i + 1L
      val_start <- i
      depth <- 0L
      escaped <- FALSE
      while (i <= n) {
        c2 <- chars[i]
        if (!escaped) {
          if (c2 == "\"" && depth == 0L) break
          if (c2 == "{") depth <- depth + 1L
          if (c2 == "}") depth <- depth - 1L
        }
        escaped <- !escaped && c2 == "\\"
        i <- i + 1L
      }
      value <- .bib_slice(chars, val_start, i - 1L)
      i <- i + 1L  # skip closing "
    } else {
      # bare value (number or macro)
      val_start <- i
      while (i <= n && chars[i] != "," && chars[i] != "}" &&
             !(chars[i] %in% ws)) i <- i + 1L
      value <- .bib_slice(chars, val_start, i - 1L)
    }

    # Clean up value: collapse internal whitespace runs (incl. newlines) to a
    # single space, then strip the at most one resulting leading/trailing space.
    # Avoids `trimws()` (whose internal per-call `sub()`/`match.arg()` dominated
    # runtime on large files, G4) in favour of one `gsub` + cheap C predicates.
    value <- gsub("\\s+", " ", value, perl = TRUE)
    if (startsWith(value, " ")) value <- substring(value, 2L)
    if (endsWith(value, " ")) value <- substring(value, 1L, nchar(value) - 1L)
    fields[[field_name]] <- value
  }

  fields
}

#' Build authors and authorships from BibTeX author strings
#' @noRd
.bib_build_authors <- function(author_strings, work_ids) {
  # Accumulate into per-work vector lists and combine once, avoiding the
  # O(n^2) `c()` growth and thousands of one-row tibbles of the original (G4).
  wid_chunks <- vector("list", length(author_strings))
  name_chunks <- vector("list", length(author_strings))
  pos_chunks <- vector("list", length(author_strings))
  corr_chunks <- vector("list", length(author_strings))
  k <- 0L

  for (i in seq_along(author_strings)) {
    au_str <- author_strings[i]
    if (is.na(au_str)) next

    names <- .bib_split_names(au_str)
    names <- names[nzchar(names)]
    if (length(names) == 0L) next
    names <- vapply(names, function(nm) {
      parts <- .bib_split_depth(nm, ",")
      if (length(parts) >= 2L) paste(parts[2], parts[1]) else nm
    }, character(1), USE.NAMES = FALSE)

    k <- k + 1L
    wid_chunks[[k]] <- rep(work_ids[i], length(names))
    name_chunks[[k]] <- names
    pos_chunks[[k]] <- seq_along(names)
    corr_chunks[[k]] <- .corresponding_flags(length(names))
  }

  if (k == 0L) {
    return(list(
      authors = .empty_authors(),
      authorships = .empty_authorships()
    ))
  }

  aships_df <- tibble::tibble(
    work_id = unlist(wid_chunks, use.names = FALSE),
    author_name = .bib_clean_text(unlist(name_chunks, use.names = FALSE)),
    position = as.integer(unlist(pos_chunks, use.names = FALSE)),
    is_corresponding = unlist(corr_chunks, use.names = FALSE)
  )
  unique_names <- unique(aships_df$author_name)
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
  wid_chunks <- vector("list", length(keywords_vec))
  term_chunks <- vector("list", length(keywords_vec))
  k <- 0L
  for (i in seq_along(keywords_vec)) {
    kw <- keywords_vec[i]
    if (is.na(kw)) next
    terms <- trimws(strsplit(kw, "[;,]")[[1]])
    terms <- terms[nzchar(terms)]
    if (length(terms) == 0L) next
    k <- k + 1L
    wid_chunks[[k]] <- rep(work_ids[i], length(terms))
    term_chunks[[k]] <- terms
  }
  if (k == 0L) return(.empty_concepts())
  tibble::tibble(
    work_id = unlist(wid_chunks, use.names = FALSE),
    concept_id = NA_character_,
    concept_name = unlist(term_chunks, use.names = FALSE),
    level = NA_integer_,
    score = NA_real_,
    vocabulary = "author-keywords"
  )
}


.bib_accent_map <- c(
  "\"a" = "\u00e4", "\"e" = "\u00eb", "\"h" = "\u1e27", "\"i" = "\u00ef",
  "\"o" = "\u00f6", "\"t" = "\u1e97", "\"u" = "\u00fc", "\"w" = "\u1e85",
  "\"x" = "\u1e8d", "\"y" = "\u00ff", "\"A" = "\u00c4", "\"E" = "\u00cb",
  "\"H" = "\u1e26", "\"I" = "\u00cf", "\"O" = "\u00d6", "\"U" = "\u00dc",
  "\"W" = "\u1e84", "\"X" = "\u1e8c", "\"Y" = "\u0178", "'a" = "\u00e1",
  "'c" = "\u0107", "'e" = "\u00e9", "'g" = "\u01f5", "'i" = "\u00ed",
  "'k" = "\u1e31", "'l" = "\u013a", "'m" = "\u1e3f", "'n" = "\u0144",
  "'o" = "\u00f3", "'p" = "\u1e55", "'r" = "\u0155", "'s" = "\u015b",
  "'u" = "\u00fa", "'w" = "\u1e83", "'y" = "\u00fd", "'z" = "\u017a",
  "'A" = "\u00c1", "'C" = "\u0106", "'E" = "\u00c9", "'G" = "\u01f4",
  "'I" = "\u00cd", "'K" = "\u1e30", "'L" = "\u0139", "'M" = "\u1e3e",
  "'N" = "\u0143", "'O" = "\u00d3", "'P" = "\u1e54", "'R" = "\u0154",
  "'S" = "\u015a", "'U" = "\u00da", "'W" = "\u1e82", "'Y" = "\u00dd",
  "'Z" = "\u0179", "`a" = "\u00e0", "`e" = "\u00e8", "`i" = "\u00ec",
  "`n" = "\u01f9", "`o" = "\u00f2", "`u" = "\u00f9", "`w" = "\u1e81",
  "`y" = "\u1ef3", "`A" = "\u00c0", "`E" = "\u00c8", "`I" = "\u00cc",
  "`N" = "\u01f8", "`O" = "\u00d2", "`U" = "\u00d9", "`W" = "\u1e80",
  "`Y" = "\u1ef2", "^a" = "\u00e2", "^c" = "\u0109", "^e" = "\u00ea",
  "^g" = "\u011d", "^h" = "\u0125", "^i" = "\u00ee", "^j" = "\u0135",
  "^o" = "\u00f4", "^s" = "\u015d", "^u" = "\u00fb", "^w" = "\u0175",
  "^y" = "\u0177", "^z" = "\u1e91", "^A" = "\u00c2", "^C" = "\u0108",
  "^E" = "\u00ca", "^G" = "\u011c", "^H" = "\u0124", "^I" = "\u00ce",
  "^J" = "\u0134", "^O" = "\u00d4", "^S" = "\u015c", "^U" = "\u00db",
  "^W" = "\u0174", "^Y" = "\u0176", "^Z" = "\u1e90", "~a" = "\u00e3",
  "~e" = "\u1ebd", "~i" = "\u0129", "~n" = "\u00f1", "~o" = "\u00f5",
  "~u" = "\u0169", "~v" = "\u1e7d", "~y" = "\u1ef9", "~A" = "\u00c3",
  "~E" = "\u1ebc", "~I" = "\u0128", "~N" = "\u00d1", "~O" = "\u00d5",
  "~U" = "\u0168", "~V" = "\u1e7c", "~Y" = "\u1ef8", "=a" = "\u0101",
  "=e" = "\u0113", "=g" = "\u1e21", "=i" = "\u012b", "=o" = "\u014d",
  "=u" = "\u016b", "=y" = "\u0233", "=A" = "\u0100", "=E" = "\u0112",
  "=G" = "\u1e20", "=I" = "\u012a", "=O" = "\u014c", "=U" = "\u016a",
  "=Y" = "\u0232", ".a" = "\u0227", ".b" = "\u1e03", ".c" = "\u010b",
  ".d" = "\u1e0b", ".e" = "\u0117", ".f" = "\u1e1f", ".g" = "\u0121",
  ".h" = "\u1e23", ".m" = "\u1e41", ".n" = "\u1e45", ".o" = "\u022f",
  ".p" = "\u1e57", ".r" = "\u1e59", ".s" = "\u1e61", ".t" = "\u1e6b",
  ".w" = "\u1e87", ".x" = "\u1e8b", ".y" = "\u1e8f", ".z" = "\u017c",
  ".A" = "\u0226", ".B" = "\u1e02", ".C" = "\u010a", ".D" = "\u1e0a",
  ".E" = "\u0116", ".F" = "\u1e1e", ".G" = "\u0120", ".H" = "\u1e22",
  ".I" = "\u0130", ".M" = "\u1e40", ".N" = "\u1e44", ".O" = "\u022e",
  ".P" = "\u1e56", ".R" = "\u1e58", ".S" = "\u1e60", ".T" = "\u1e6a",
  ".W" = "\u1e86", ".X" = "\u1e8a", ".Y" = "\u1e8e", ".Z" = "\u017b",
  "cc" = "\u00e7", "cd" = "\u1e11", "ce" = "\u0229", "cg" = "\u0123",
  "ch" = "\u1e29", "ck" = "\u0137", "cl" = "\u013c", "cn" = "\u0146",
  "cr" = "\u0157", "cs" = "\u015f", "ct" = "\u0163", "cC" = "\u00c7",
  "cD" = "\u1e10", "cE" = "\u0228", "cG" = "\u0122", "cH" = "\u1e28",
  "cK" = "\u0136", "cL" = "\u013b", "cN" = "\u0145", "cR" = "\u0156",
  "cS" = "\u015e", "cT" = "\u0162", "va" = "\u01ce", "vc" = "\u010d",
  "vd" = "\u010f", "ve" = "\u011b", "vg" = "\u01e7", "vh" = "\u021f",
  "vi" = "\u01d0", "vj" = "\u01f0", "vk" = "\u01e9", "vl" = "\u013e",
  "vn" = "\u0148", "vo" = "\u01d2", "vr" = "\u0159", "vs" = "\u0161",
  "vt" = "\u0165", "vu" = "\u01d4", "vz" = "\u017e", "vA" = "\u01cd",
  "vC" = "\u010c", "vD" = "\u010e", "vE" = "\u011a", "vG" = "\u01e6",
  "vH" = "\u021e", "vI" = "\u01cf", "vK" = "\u01e8", "vL" = "\u013d",
  "vN" = "\u0147", "vO" = "\u01d1", "vR" = "\u0158", "vS" = "\u0160",
  "vT" = "\u0164", "vU" = "\u01d3", "vZ" = "\u017d", "ua" = "\u0103",
  "ue" = "\u0115", "ug" = "\u011f", "ui" = "\u012d", "uo" = "\u014f",
  "uu" = "\u016d", "uA" = "\u0102", "uE" = "\u0114", "uG" = "\u011e",
  "uI" = "\u012c", "uO" = "\u014e", "uU" = "\u016c", "Ho" = "\u0151",
  "Hu" = "\u0171", "HO" = "\u0150", "HU" = "\u0170", "ka" = "\u0105",
  "ke" = "\u0119", "ki" = "\u012f", "ko" = "\u01eb", "ku" = "\u0173",
  "kA" = "\u0104", "kE" = "\u0118", "kI" = "\u012e", "kO" = "\u01ea",
  "kU" = "\u0172", "ra" = "\u00e5", "ru" = "\u016f", "rw" = "\u1e98",
  "ry" = "\u1e99", "rA" = "\u00c5", "rU" = "\u016e"
)


.bib_clean_text <- function(x, doi = FALSE) {
  has_math <- !doi & !is.na(x) & grepl("$", x, fixed = TRUE)
  out <- x
  out[!has_math] <- .bib_decode_text(x[!has_math], doi = doi)
  if (any(has_math)) {
    pattern <- r"((?<!\\)\$(?:\\.|[^$])*\$|(?:\\.|[^\\$])+|.)"
    replace <- function(m) {
      math <- startsWith(m, "$") & endsWith(m, "$") & nchar(m) > 1L
      m[!math] <- .bib_decode_text(m[!math])
      m
    }
    out[has_math] <- stringr::str_replace_all(x[has_math], pattern, replace)
  }
  out <- trimws(out)
  out[!is.na(out) & !nzchar(out)] <- NA_character_
  out
}

.bib_decode_text <- function(x, doi = FALSE) {
  if (!doi) {
    letters <- c(ss = "\u00df", o = "\u00f8", O = "\u00d8",
                 aa = "\u00e5", AA = "\u00c5", ae = "\u00e6", AE = "\u00c6",
                 oe = "\u0153", OE = "\u0152", l = "\u0142", L = "\u0141",
                 i = "\u0131")
    x <- stringr::str_replace_all(
      x, r"(\\(ss|aa|AA|ae|AE|oe|OE|o|O|l|L|i)(?![A-Za-z]))",
      function(m) unname(letters[substring(m, 2L)])
    )
    accent <- r"(\\(["'`^~=.]|[cvuHkr](?=[{\s]))\s*\{?([A-Za-z\u0131])\}?)"
    x <- stringr::str_replace_all(x, accent, function(m) {
      parts <- stringr::str_match(m, accent)
      base <- parts[, 3]
      base[base == "\u0131"] <- "i"
      value <- unname(.bib_accent_map[paste0(parts[, 2], base)])
      value[is.na(value)] <- base[is.na(value)]
      value
    })
  }
  x <- gsub(r"(\\([&%$#_]))", "\\1", x, perl = TRUE)
  x <- gsub(r"((?<!\\)[{}])", "", x, perl = TRUE)
  x <- gsub(r"(\\([{}]))", "\\1", x, perl = TRUE)
  gsub("\\s+", " ", x, perl = TRUE)
}

.bib_split_depth <- function(x, pattern) {
  if (!grepl("{", x, fixed = TRUE)) {
    return(trimws(strsplit(x, pattern, perl = TRUE)[[1]]))
  }
  chars <- strsplit(x, "", fixed = TRUE)[[1]]
  depths <- integer(length(chars))
  depth <- 0L
  escaped <- FALSE
  for (i in seq_along(chars)) {
    depths[i] <- depth
    if (!escaped) {
      if (chars[i] == "{") depth <- depth + 1L
      if (chars[i] == "}") depth <- max(0L, depth - 1L)
    }
    escaped <- !escaped && chars[i] == "\\"
  }
  matches <- gregexpr(pattern, x, perl = TRUE)[[1]]
  keep <- matches > 0L
  keep[keep] <- depths[matches[keep]] == 0L
  starts <- matches[keep]
  widths <- attr(matches, "match.length")[keep]
  if (length(starts) == 0L) return(trimws(x))
  begin <- c(1L, starts + widths)
  end <- c(starts - 1L, length(chars))
  trimws(vapply(seq_along(begin), function(i) {
    .bib_slice(chars, begin[i], end[i])
  }, character(1)))
}

.bib_split_names <- function(x) {
  .bib_split_depth(x, "\\s+and\\s+")
}

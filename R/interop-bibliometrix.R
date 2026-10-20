#' Convert sm_corpus to bibliometrix format
#'
#' @description
#' Converts an `sm_corpus` to the data frame format used by
#' `bibliometrix::biblioAnalysis()` and the other functions of bibliometrix:
#' one row per work and one column per Web of Science field tag. This
#' enables using bibliometrix's analysis functions on corpora built with
#' scimapR.
#'
#' @param corpus An `sm_corpus` object.
#' @param keep_extra Logical. If `TRUE` (default), the columns without a
#'   field tag follow the tag columns, as in earlier versions: the other
#'   `works` columns (such as `work_id` and `source_id`), `country_code`
#'   and `SO_ISSN`. `FALSE` returns the tag columns only.
#' @param db Value of the `DB` column. `"auto"` (default) writes `"ISI"`
#'   when every work comes from Web of Science and `"scimapR"` otherwise;
#'   `"ISI"` and `"scimapR"` write that value. See Details.
#' @param ... Additional arguments (currently unused).
#'
#' @return A data frame with class `c("bibliometrixDB", "data.frame")`, one
#'   row per work in the order of `corpus$works`, with `SR` as row names.
#'   Every tag column is present, `NA` where the corpus holds no data.
#'
#' @details
#' ## Field tags
#'
#' * `AU`: authors as `SURNAME INITIALS`, `AF`: full names as
#'   `SURNAME, GIVEN NAMES`; one entry per author of the work, in
#'   `position` order and separated by `;`, from `authors$display_name`
#'   through `authorships`. An author with several address rows appears
#'   once; authors without a name are left out.
#' * `TI`, `AB`: `works$title`, `works$abstract`; `TI_raw` and `AB_raw` hold
#'   them in their stored case, as `bibliometrix::convert2df()` does.
#' * `SO`, `J9`, `JI`: `sources$display_name`, and the optional columns
#'   `sources$abbreviation` and `sources$iso_abbreviation`.
#' * `SN`, `EI`: `sources$issn_l` (else the first value of `sources$issn`)
#'   and the next distinct value of `sources$issn`.
#' * `C1`: one segment per distinct address of the work,
#'   `[AUTHOR A; AUTHOR B] ADDRESS`, with the authors (`AF` form) in
#'   `position` order, joined by `; `; from `authorships$raw_affiliation`.
#' * `RP`: one segment per corresponding author
#'   (`authorships$is_corresponding`), `SURNAME, INITIALS (CORRESPONDING
#'   AUTHOR), ADDRESS` with the author's first address, joined by `; `.
#' * `EM`: the e-mail addresses of the optional column
#'   `authorships$email`.
#' * `CR`: `references$cited_raw` in `ref_index` order, separated by `;`;
#'   `NR`: the number of items in `CR`.
#' * `DE`: author keywords, see below; `DE_raw` holds them in their stored
#'   case. `ID`: the concepts of the `indexer_keyword` family of
#'   [sm_concept_vocabularies()] (such as Keywords Plus or MeSH). `WC`: the
#'   vocabulary `wos-category` (Web of Science categories); `SC`: the
#'   vocabulary `wos-subject-category` (research areas). Terms are joined
#'   by `; `.
#' * `DT`, `LA`, `PY`, `TC`, `DI`, `PM`: `works$type`, `language`, `year`,
#'   `cited_by_count`, `doi` and `pmid`.
#' * `UT`: the Web of Science accession number,
#'   `provenance$source_id_external` of the work's first provenance row
#'   with `source == "wos"`, else a `work_id` that starts with `WOS:`.
#' * `DB`: see below. `SR`: the short reference `FIRST AUTHOR, YEAR, J9`
#'   (with `SO` where `J9` is missing), made unique by appending `-a`,
#'   `-b`, ... to repeats; `SR_FULL` keeps it without the suffixes.
#'
#' With `keep_extra = TRUE`, `country_code` holds the country codes of
#' `authorships$country_code`, one per authorship row (author and
#' address), and `SO_ISSN` holds `sources$issn_l`. The export has no
#' `AU_CO` column, as data from `bibliometrix::convert2df()` has none:
#' `bibliometrix::metaTagExtraction(M, "AU_CO")` adds the country names
#' that bibliometrix reads from `C1` and uses for its country analyses.
#'
#' ## Conventions
#'
#' Like `bibliometrix::convert2df()` for Web of Science files, the export
#' upper-cases `AU`, `AF`, `TI`, `SO`, `J9`, `JI`, `AB`, `C1`, `RP`, `EM`,
#' `CR` (including the DOIs in it), `DE`, `ID`, `WC`, `SC`, `DT` and `LA`.
#' `DI`, `UT`, `SN`, `EI` and `PM` are written as stored, so `DI` keeps the
#' lower-case DOIs of the scimapR readers. Upper-casing uses [toupper()],
#' whose result for non-ASCII letters depends on the locale.
#'
#' Names: a `display_name` with a comma is read as `Surname, Given names`.
#' Otherwise an entry of `authors$display_name_alternatives` in that form
#' that agrees with the name gives the surname, so a surname of several
#' words such as "Garcia Lopez" stays whole; [sm_read_wos()] keeps the
#' names of the file there. Else initials at the end of the name (single
#' letters, or capitals with periods, as in "Chen W." from
#' [sm_read_scopus()]) follow the surname, and otherwise the last word is
#' the surname, together with the lower-case particles before it ("Anna
#' van der Berg" gives `VAN DER BERG A`). Particles never become initials.
#' Without such a spelling, a surname of several words without particles
#' ("Maria Garcia Lopez") keeps only its last word, and a name such as
#' "SMITH JA" is read as given names followed by the surname. The given
#' names of `AF` are the longest spelling at hand, the initials of `AU`
#' the shortest. Corpora read by [sm_read_wos()] store the `AU` form of a
#' name (such as "J Smith"), so their `AF` holds initials.
#'
#' `CR` items are written in the Web of Science form `SURNAME INITIALS,
#' YEAR, SOURCE, ...`: an item `Surname, IN, YEAR, ...` (with a comma after
#' the surname, as some exports write it) becomes `SURNAME IN, YEAR, ...`.
#' Other items, such as titles or OpenAlex IDs, are only upper-cased.
#' Because `;` separates the items of `AU`, `AF`, `C1`, `RP`, `CR`, `DE`,
#' `ID`, `WC` and `SC`, a `;` inside an item becomes `,`.
#'
#' `DE` holds the author keywords of each work: the concepts of the
#' `author_keyword` family of [sm_concept_vocabularies()] (`author-keywords`,
#' `manual-tags`). A work without author keywords gets its OpenAlex
#' concepts (`openalex`) instead, so corpora built from OpenAlex keep their
#' `DE`; other vocabularies (Keywords Plus, MeSH, categories, arXiv and
#' bioRxiv subjects) never enter `DE`. A work with neither has `DE = NA`.
#'
#' `DB`: with `db = "auto"`, a corpus whose works all come from Web of
#' Science (each has a provenance row with `source == "wos"`, or a
#' `work_id` that starts with `WOS:`) gets `"ISI"`, the value
#' `bibliometrix::convert2df()` writes for Web of Science files, so that
#' `bibliometrix::histNetwork()` and `bibliometrix::rpys()` accept it.
#' Other corpora get `"scimapR"`, because bibliometrix reads `"ISI"` data
#' as Web of Science records; `db = "ISI"` declares a corpus whose `CR`
#' items are in Web of Science form anyway.
#'
#' `RP` follows `authorships$is_corresponding`: it names the authors
#' flagged `TRUE` and is `NA` for a work without one. [sm_read_wos()] takes
#' the corresponding authors from the RP field of the file,
#' [sm_read_openalex_json()] and [sm_fetch_openalex()] from the OpenAlex
#' records, [sm_read_dimensions()] from the Corresponding Authors column,
#' [sm_fetch_biorxiv()] from the bioRxiv API and [as_sm_corpus()] from
#' `RP`. The other readers and fetchers record the corresponding author as
#' unknown (`NA`), so their corpora export `RP = NA`. Corpora built from
#' tables keep the flags of their tables.
#'
#' [as_sm_corpus()] reads the result back: the round trip keeps the works,
#' their DOIs and years, the authors of each work, their addresses and the
#' corresponding authors.
#'
#' @references
#' Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
#' comprehensive science mapping analysis. *Journal of Informetrics*,
#' 11(4), 959-975. \doi{10.1016/j.joi.2017.08.007}
#'
#' @family interop
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
#'                             with_embeddings = FALSE)
#' M <- sm_to_bibliometrix(corpus, keep_extra = FALSE)
#' class(M)
#' M[1:3, c("AU", "PY", "SO", "DB")]
#'
#' # a corpus from Web of Science records
#' fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
#' M <- sm_to_bibliometrix(fix)
#' unique(M$DB)
#' M$C1[1]
#' \donttest{
#' if (requireNamespace("bibliometrix", quietly = TRUE)) {
#'   results <- bibliometrix::biblioAnalysis(M, sep = ";")
#' }
#' }
sm_to_bibliometrix <- function(corpus, keep_extra = TRUE,
                               db = c("auto", "ISI", "scimapR"), ...) {
  .check_sm_corpus(corpus)
  .check_flag(keep_extra)
  db <- rlang::arg_match(db)

  works <- corpus$works
  ids <- as.character(works$work_id)
  wcol <- function(col) .bx_col(works, col)

  au <- .bx_author_tags(corpus, ids, country = keep_extra)
  cr <- .bx_reference_tags(corpus$references, ids)
  kw <- .bx_concept_tags(corpus$concepts, ids)
  so <- .bx_source_tags(wcol("source_id"), corpus$sources)
  if (db == "auto") {
    from_wos <- .bx_from_wos(corpus$provenance, ids)
    db <- if (length(ids) > 0L && all(from_wos)) "ISI" else "scimapR"
  }

  year <- as.integer(wcol("year"))
  title <- as.character(wcol("title"))
  abstract <- as.character(wcol("abstract"))
  first_au <- sub(";.*", "", au$AU)
  first_au[is.na(first_au)] <- "Unknown"
  journal <- so$J9
  journal[is.na(journal)] <- so$SO[is.na(journal)]
  sr <- paste(first_au, year, journal, sep = ", ")

  out <- tibble::tibble(
    AU = au$AU, AF = au$AF, TI = toupper(title), SO = so$SO, J9 = so$J9,
    JI = so$JI, AB = toupper(abstract), C1 = au$C1, RP = au$RP,
    EM = au$EM, CR = cr$CR, NR = cr$NR, DE = kw$DE, ID = kw$ID,
    WC = kw$WC, SC = kw$SC, DT = toupper(as.character(wcol("type"))),
    LA = toupper(as.character(wcol("language"))), PY = year,
    TC = as.integer(wcol("cited_by_count")),
    DI = as.character(wcol("doi")), PM = as.character(wcol("pmid")),
    UT = .bx_accession(corpus$provenance, ids), SN = so$SN, EI = so$EI,
    DB = rep(db, length(ids)), SR = .bx_unique_sr(sr), SR_FULL = sr,
    TI_raw = title, AB_raw = abstract, DE_raw = kw$DE_raw
  )

  if (keep_extra) {
    tagged <- c("doi", "title", "abstract", "year", "type",
                "cited_by_count", "language", "pmid")
    extra <- tibble::tibble(country_code = au$country_code,
                            SO_ISSN = so$SO_ISSN)
    other <- setdiff(names(works), c(tagged, names(out), names(extra)))
    out <- dplyr::bind_cols(out, tibble::as_tibble(works)[other], extra)
  }

  out <- as.data.frame(out, stringsAsFactors = FALSE)
  rownames(out) <- out$SR
  class(out) <- c("bibliometrixDB", "data.frame")
  out
}

#' Convert bibliometrix data frame to sm_corpus
#'
#' @rdname as_sm_corpus
#' @param source_label Label for provenance tracking. For a bibliometrix
#'   data frame, rows with `DB = "ISI"` are labelled `"wos"` unless
#'   `source_label` is given.
#' @section bibliometrix data frames:
#' `as_sm_corpus()` reads a data frame made by `bibliometrix::convert2df()`
#' or [sm_to_bibliometrix()] (class `bibliometrixDB`), and the file readers
#' with `engine = "bibliometrix"` use the same conversion:
#' * `works` from `TI`, `AB` (`TI_raw` and `AB_raw` where present, which
#'   keep the case of the file), `PY`, `DT`, `TC`, `LA`, `DI` and `PM`;
#' * `authors` and `authorships` from `AU` and `AF`, with one authorship
#'   row per author and address: the names in the brackets of `C1`
#'   (`C1raw` where present) link authors to addresses. An address
#'   without names, as in older records, belongs to every author of the
#'   work; one whose names designate none of the authors belongs to the
#'   author of a single-author work and else to nobody. Authors are told
#'   apart by the full names of `AF`; an entry whose given names are only
#'   initials, or that has no `AF`, belongs to the author with that
#'   surname and those initials when there is just one such author with a
#'   full name. `RP` gives `is_corresponding`: the authors it names before
#'   "(corresponding author)" or "(reprint author)", in any case, are
#'   `TRUE` on all their rows and the other authors of the work `FALSE`.
#'   Namesakes (the same surname and initials) are told apart by the
#'   address that `RP` gives with the name, and stay `NA` when it does not
#'   tell them apart; a work without `RP`, or whose `RP` designates none
#'   of its authors for certain, gets `NA` (unknown);
#' * `sources` from `SO`, `SN`, `EI`, `J9` and `JI` (`issn_l`, `issn`,
#'   `abbreviation`, `iso_abbreviation`);
#' * `references` from `CR`, with the DOI of each item that has one;
#' * `concepts` from `DE` (`DE_raw` where present), `ID`, `SC` and `WC`, in
#'   the vocabularies `author-keywords`, the indexer vocabulary of the
#'   source, `wos-subject-category` and `wos-category`. `ID` is read as
#'   `keywords-plus` for Web of Science data (`DB = "ISI"`), `mesh` for
#'   PubMed, Dimensions, Lens and Cochrane, `author-keywords` for BibTeX
#'   and RIS files (where bibliometrix stores the keywords of the file in
#'   `ID`) and `index-keywords` otherwise;
#' * `provenance` with `UT` as `source_id_external`.
#' @export
as_sm_corpus.bibliometrixDB <- function(x,
                                        source_label = "bibliometrix-import",
                                        ...) {
  .bibliometrix_df_to_corpus(x, source_label = source_label,
                             label_wos = missing(source_label))
}

# ---- export helpers ---------------------------------------------------------

#' Column `nm` of table `x`, or `na` for every row when `x` has no such
#' column (the optional columns of a corpus built with sm_corpus())
#' @noRd
.bx_col <- function(x, nm, na = NA) {
  if (nm %in% names(x)) x[[nm]] else rep(na, nrow(x))
}

#' Text with white space squished; empty strings become NA
#' @noRd
.bx_text <- function(x) {
  x <- trimws(gsub("[[:space:]]+", " ", as.character(x)))
  x[!is.na(x) & !nzchar(x)] <- NA_character_
  x
}

#' One item of a `;`-separated tag: a `;` inside it becomes `,`; with
#' `brackets = FALSE` square brackets are dropped (they delimit C1 names)
#' @noRd
.bx_item <- function(x, brackets = TRUE) {
  x <- gsub(";", ",", as.character(x), fixed = TRUE)
  if (!brackets) x <- gsub("[][]", "", x)
  .bx_text(x)
}

#' Collapse values by work, aligned with `ids`; NA for works without values
#' @noRd
.bx_collapse <- function(values, groups, ids, sep) {
  out <- rep(NA_character_, length(ids))
  if (length(values) == 0L) return(out)
  lv <- unique(ids)
  pasted <- vapply(split(values, factor(groups, levels = lv)), function(x) {
    if (length(x) == 0L) NA_character_ else paste(x, collapse = sep)
  }, character(1))
  unname(pasted[match(ids, lv)])
}

#' Split `;`-separated tags into their items: `item` and the index `row` of
#' the value each comes from
#' @noRd
.bx_split_flat <- function(x) {
  parts <- strsplit(as.character(x), ";", fixed = TRUE)
  row <- rep(seq_along(parts), lengths(parts))
  item <- .bx_text(unlist(parts, use.names = FALSE))
  keep <- !is.na(item)
  list(item = item[keep], row = row[keep])
}

#' Comparison key of a name part: upper case, no periods, squished
#' @noRd
.bx_key <- function(x) {
  x <- .bx_text(gsub(".", " ", x, fixed = TRUE))
  x[is.na(x)] <- ""
  toupper(x)
}

#' Is each word written as initials: a single capital, or capitals with
#' periods ("J.", "J.A.", "J.-P.")? Capitals without periods ("JA") may be
#' a short surname or given name, so they do not count.
#' @noRd
.bx_is_initials <- function(words) {
  bare <- gsub("[.-]", "", words)
  grepl("^[[:upper:]]{1,4}$", bare) &
    (nchar(bare) == 1L | grepl(".", words, fixed = TRUE))
}

#' Is each word a lower-case particle such as "van", "der" or "de"?
#' @noRd
.bx_is_particle <- function(words) {
  !grepl("[[:upper:]]", words) & grepl("[[:lower:]]", words)
}

#' Split a name into surname and given names: `Surname, Given` at the first
#' comma. Otherwise initials at the end ("Chen W.") follow the surname, and
#' else the last word is the surname, with the lower-case particles before
#' it ("Anna van der Berg") other than the first word.
#' @noRd
.bx_split_name <- function(x) {
  comma <- regexpr(",", x, fixed = TRUE)
  if (comma > 0L) {
    return(c(trimws(substr(x, 1L, comma - 1L)),
             trimws(substring(x, comma + 1L))))
  }
  words <- strsplit(x, " ", fixed = TRUE)[[1]]
  k <- length(words)
  if (k < 2L) return(c(x, ""))
  ini <- .bx_is_initials(words)
  s <- k
  while (s > 1L && ini[s]) s <- s - 1L
  if (s < k && !all(ini[seq_len(s)])) {
    return(c(paste(words[seq_len(s)], collapse = " "),
             paste(words[(s + 1L):k], collapse = " ")))
  }
  particle <- .bx_is_particle(words)
  s <- k
  while (s > 2L && particle[s - 1L]) s <- s - 1L
  c(paste(words[s:k], collapse = " "),
    paste(words[seq_len(s - 1L)], collapse = " "))
}

#' The words of `name` before a trailing `surname`, or NA when `name` does
#' not end with it
#' @noRd
.bx_name_rest <- function(name, surname) {
  words <- strsplit(name, " ", fixed = TRUE)[[1]]
  sw <- strsplit(.bx_key(surname), " ", fixed = TRUE)[[1]]
  k <- length(words) - length(sw)
  if (length(sw) == 0L || k < 1L) return(NA_character_)
  tail <- vapply(words[(k + 1L):length(words)], .bx_key, character(1),
                 USE.NAMES = FALSE)
  if (!identical(tail, sw)) return(NA_character_)
  paste(words[seq_len(k)], collapse = " ")
}

#' Initials of given names: the first letter of each word. In a name that
#' is not all upper case (`context`), a word of up to three capitals is a
#' block of initials already ("JA" in "JA Smith"). Lower-case particles
#' ("de" in "Joao de Souza") give no initial when another word is
#' capitalised. Vectorised.
#' @noRd
.bx_initials <- function(given, context = given) {
  given[is.na(given)] <- ""
  words <- strsplit(given, "[[:space:].-]+")
  row <- rep(seq_along(given), lengths(words))
  w <- unlist(words, use.names = FALSE)
  block <- grepl("[[:lower:]]", context)[row] & nchar(w) <= 3L &
    !grepl("[[:lower:]]", w)
  first <- ifelse(block, w, substr(w, 1L, 1L))
  first[.bx_is_particle(w) & grepl("[[:upper:]]", given)[row]] <- ""
  out <- vapply(split(first, factor(row, levels = seq_along(given))),
                paste, character(1), collapse = "")
  unname(toupper(gsub("[^[:alpha:]]", "", out)))
}

#' AU, AF and RP forms of one author name
#' @noRd
.bx_name_form <- function(name, alts = character()) {
  none <- c(au = NA_character_, af = NA_character_, rp = NA_character_)
  name <- .bx_item(name, brackets = FALSE)
  if (length(name) != 1L || is.na(name)) return(none)
  alts <- .bx_item(unlist(alts, use.names = FALSE), brackets = FALSE)
  alts <- unique(alts[!is.na(alts)])
  comma_alts <- alts[grepl(",", alts, fixed = TRUE)]

  parts <- .bx_split_name(name)
  surname <- parts[1]
  given <- parts[2]
  if (!grepl(",", name, fixed = TRUE)) {
    # a "Surname, Given" spelling that agrees with the name names the
    # whole surname ("Garcia Lopez, M" for "M Garcia Lopez")
    for (alt in comma_alts) {
      p <- .bx_split_name(alt)
      rest <- .bx_name_rest(name, p[1])
      if (!is.na(rest) &&
            .bx_initials(rest, name) == .bx_initials(p[2], alt)) {
        surname <- p[1]
        given <- rest
        break
      }
    }
  }

  # other spellings of the given names of the same person
  givens <- given
  context <- name
  for (alt in comma_alts) {
    p <- .bx_split_name(alt)
    if (.bx_key(p[1]) == .bx_key(surname) &&
          .bx_initials(p[2], alt) == .bx_initials(given, name)) {
      givens <- c(givens, p[2])
      context <- c(context, alt)
    }
  }
  letters_in <- nchar(gsub("[^[:alpha:]]", "", givens))
  full <- givens[which.max(letters_in)]
  initials <- ""
  if (any(letters_in > 0L)) {
    short <- which(letters_in == min(letters_in[letters_in > 0L]))[1]
    initials <- .bx_initials(givens[short], context[short])
  }
  # an AU-form spelling ("SURNAME JA") gives the initials as written
  plain <- alts[!grepl(",", alts, fixed = TRUE)]
  for (alt in plain) {
    words <- strsplit(alt, " ", fixed = TRUE)[[1]]
    k <- length(words)
    if (k >= 2L && grepl("^[[:upper:]]{1,4}$", words[k]) &&
          .bx_key(paste(words[-k], collapse = " ")) == .bx_key(surname) &&
          (!nzchar(initials) ||
             substr(words[k], 1L, 1L) == substr(initials, 1L, 1L))) {
      initials <- words[k]
      break
    }
  }

  surname <- toupper(surname)
  c(
    au = trimws(paste(surname, initials)),
    af = if (nzchar(full)) paste0(surname, ", ", toupper(full)) else surname,
    rp = if (nzchar(initials)) paste0(surname, ", ", initials) else surname
  )
}

#' AU, AF and RP forms of author names
#' @noRd
.bx_name_forms <- function(names, alternatives) {
  n <- length(names)
  forms <- vapply(seq_len(n), function(i) {
    .bx_name_form(names[i], alternatives[[i]])
  }, character(3))
  if (n == 0L) forms <- matrix(character(), 3L, 0L)
  list(au = unname(forms[1L, ]), af = unname(forms[2L, ]),
       rp = unname(forms[3L, ]))
}

#' AU, AF, C1, RP and EM of each work and, with `country = TRUE`, the
#' country codes of its authorship rows (`country_code`)
#' @noRd
.bx_author_tags <- function(corpus, ids, country = FALSE) {
  n <- length(ids)
  na <- rep(NA_character_, n)
  out <- list(AU = na, AF = na, C1 = na, RP = na, EM = na,
              country_code = na)
  a <- corpus$authorships
  if (!all(c("work_id", "author_id") %in% names(a))) return(out)
  a <- a[!is.na(a$work_id) & a$work_id %in% ids, , drop = FALSE]
  if (nrow(a) == 0L) return(out)
  ord <- order(match(a$work_id, ids), .bx_col(a, "position", NA_integer_),
               seq_len(nrow(a)))
  a <- a[ord, , drop = FALSE]

  authors <- corpus$authors
  k <- match(a$author_id, .bx_col(authors, "author_id", NA_character_))
  used <- unique(k[!is.na(k)])
  alts <- if ("display_name_alternatives" %in% names(authors)) {
    authors$display_name_alternatives[used]
  } else {
    vector("list", length(used))
  }
  display <- .bx_col(authors, "display_name", NA_character_)
  forms <- .bx_name_forms(display[used], alts)
  j <- match(k, used)
  au_name <- forms$au[j]
  af_name <- forms$af[j]
  rp_name <- forms$rp[j]

  # one author slot per work, author and position
  slot <- paste(a$work_id, a$author_id, .bx_col(a, "position"), sep = "\r")
  named <- !duplicated(slot) & !is.na(au_name)
  out$AU <- .bx_collapse(au_name[named], a$work_id[named], ids, ";")
  out$AF <- .bx_collapse(af_name[named], a$work_id[named], ids, ";")

  # C1: one segment per distinct address, authors in position order
  addr <- .bx_item(.bx_col(a, "raw_affiliation"), brackets = FALSE)
  has <- which(!is.na(addr))
  if (length(has) > 0L) {
    key <- paste(a$work_id[has], addr[has], sep = "\r")
    names_by_addr <- split(af_name[has], factor(key, levels = unique(key)))
    names_by_addr <- vapply(names_by_addr, function(x) {
      x <- unique(x[!is.na(x)])
      if (length(x) == 0L) NA_character_ else paste(x, collapse = "; ")
    }, character(1))
    first <- has[!duplicated(key)]
    segment <- ifelse(is.na(names_by_addr), addr[first],
                      paste0("[", names_by_addr, "] ", addr[first]))
    out$C1 <- toupper(.bx_collapse(segment, a$work_id[first], ids, "; "))
  }

  # RP: each corresponding author with the first address of the slot
  corr <- which(.bx_col(a, "is_corresponding") %in% TRUE & !is.na(rp_name))
  if (length(corr) > 0L) {
    corr <- corr[order(match(slot[corr], unique(slot[corr])),
                       is.na(addr[corr]))]
    corr <- corr[!duplicated(slot[corr])]
    segment <- paste0(rp_name[corr], " (CORRESPONDING AUTHOR)",
                      ifelse(is.na(addr[corr]), "",
                             paste0(", ", addr[corr])))
    out$RP <- toupper(.bx_collapse(segment, a$work_id[corr], ids, "; "))
  }

  if ("email" %in% names(a)) {
    em <- .bx_item(a$email, brackets = FALSE)
    keep <- !is.na(em) &
      !duplicated(paste(a$work_id, tolower(em), sep = "\r"))
    out$EM <- toupper(.bx_collapse(em[keep], a$work_id[keep], ids, "; "))
  }

  # the country code of every authorship row, as AU_CO held them before
  if (country) {
    cc <- as.character(.bx_col(a, "country_code"))
    co <- .bx_collapse(cc[!is.na(cc)], a$work_id[!is.na(cc)], ids, ";")
    co[is.na(co) & ids %in% a$work_id] <- ""
    out$country_code <- co
  }
  out
}

#' CR items in Web of Science form, upper case; NA for empty items
#' @noRd
.bx_cr_items <- function(x) {
  x <- .bx_item(x)
  # drop the comma between the surname and the initials before the year
  pat <- paste0("^([^,]+), (\\p{Lu}[\\p{Lu}. -]{0,7}), ",
                "((?:1[5-9]|20)[0-9]{2})(?=,|$)")
  hit <- which(!is.na(x) & grepl(pat, x, perl = TRUE))
  if (length(hit) > 0L) {
    m <- regmatches(x[hit], regexec(pat, x[hit], perl = TRUE))
    head <- vapply(m, function(g) {
      paste0(g[2], " ", gsub("[^[:alpha:]]", "", g[3]), ", ", g[4])
    }, character(1))
    matched <- vapply(m, function(g) nchar(g[1]), integer(1))
    x[hit] <- paste0(head, substring(x[hit], matched + 1L))
  }
  toupper(x)
}

#' CR and NR of each work
#' @noRd
.bx_reference_tags <- function(references, ids) {
  n <- length(ids)
  out <- list(CR = rep(NA_character_, n), NR = rep(NA_integer_, n))
  if (!"work_id" %in% names(references)) return(out)
  r <- references[!is.na(references$work_id) & references$work_id %in% ids,
                  , drop = FALSE]
  if (nrow(r) == 0L) return(out)
  ord <- order(match(r$work_id, ids), .bx_col(r, "ref_index", NA_integer_),
               seq_len(nrow(r)))
  r <- r[ord, , drop = FALSE]
  item <- .bx_cr_items(.bx_col(r, "cited_raw", NA_character_))
  has <- !is.na(item)
  out$CR <- .bx_collapse(item[has], r$work_id[has], ids, ";")
  nr <- tabulate(match(r$work_id[has], ids), nbins = n)
  nr[!ids %in% r$work_id] <- NA_integer_
  out$NR <- nr
  out
}

#' DE, DE_raw, ID, WC and SC of each work
#' @noRd
.bx_concept_tags <- function(concepts, ids) {
  named <- function(x) {
    x[!is.na(x$work_id) & x$work_id %in% ids &
        !is.na(.bx_item(x$concept_name)), , drop = FALSE]
  }
  terms <- function(x) {
    .bx_collapse(.bx_item(x$concept_name), x$work_id, ids, "; ")
  }
  # DE: author keywords; a work without any falls back to its OpenAlex
  # concepts (only those, so arXiv and bioRxiv categories stay out).
  author_kw <- named(.concepts_in_family(concepts, "author_keyword"))
  openalex <- named(.concepts_in_family(concepts, "openalex"))
  openalex <- openalex[!openalex$work_id %in% author_kw$work_id, ,
                       drop = FALSE]
  de <- terms(dplyr::bind_rows(author_kw, openalex))
  list(
    DE = toupper(de), DE_raw = de,
    ID = toupper(terms(named(.concepts_in_family(concepts,
                                                 "indexer_keyword")))),
    WC = toupper(terms(named(.concepts_in_family(concepts,
                                                 "wos-category")))),
    SC = toupper(terms(named(.concepts_in_family(concepts,
                                                 "wos-subject-category"))))
  )
}

#' SO, J9, JI, SN, EI and SO_ISSN of each work
#' @noRd
.bx_source_tags <- function(source_id, sources) {
  k <- match(source_id, sources$source_id, incomparables = NA)
  scol <- function(col) {
    if (col %in% names(sources)) {
      as.character(sources[[col]])[k]
    } else {
      rep(NA_character_, length(k))
    }
  }
  issn <- if ("issn" %in% names(sources)) {
    sources$issn[k]
  } else {
    vector("list", length(k))
  }
  issn <- lapply(issn, function(x) {
    x <- .bx_text(unlist(x, use.names = FALSE))
    x[!is.na(x)]
  })
  first <- vapply(issn, function(x) {
    if (length(x) > 0L) x[1] else NA_character_
  }, character(1))
  sn <- .bx_text(scol("issn_l"))
  sn[is.na(sn)] <- first[is.na(sn)]
  ei <- vapply(seq_along(issn), function(i) {
    x <- setdiff(issn[[i]], sn[i])
    if (length(x) > 0L) x[1] else NA_character_
  }, character(1))
  list(SO = toupper(scol("display_name")), J9 = toupper(scol("abbreviation")),
       JI = toupper(scol("iso_abbreviation")), SN = sn, EI = ei,
       SO_ISSN = scol("issn_l"))
}

#' Does each work come from Web of Science? A provenance row with source
#' "wos" (rows without a work are ignored) or a work_id starting "WOS:"
#' @noRd
.bx_from_wos <- function(provenance, ids) {
  wos <- character()
  if (all(c("work_id", "source") %in% names(provenance))) {
    wos <- provenance$work_id[tolower(provenance$source) %in% "wos" &
                                !is.na(provenance$work_id)]
  }
  ids %in% wos | (!is.na(ids) & startsWith(ids, "WOS:"))
}

#' UT of each work: the first Web of Science accession in provenance, else
#' a work_id starting "WOS:"
#' @noRd
.bx_accession <- function(provenance, ids) {
  ut <- rep(NA_character_, length(ids))
  cols <- c("work_id", "source", "source_id_external")
  if (all(cols %in% names(provenance))) {
    ext <- .bx_text(provenance$source_id_external)
    keep <- tolower(provenance$source) %in% "wos" &
      !is.na(provenance$work_id) & !is.na(ext)
    ut <- ext[keep][match(ids, provenance$work_id[keep])]
  }
  own <- is.na(ut) & !is.na(ids) & startsWith(ids, "WOS:")
  ut[own] <- ids[own]
  ut
}

#' Unique short references: repeats get "-a", "-b", ...
#' @noRd
.bx_unique_sr <- function(sr) {
  if (!anyDuplicated(sr)) return(sr)
  k <- stats::ave(seq_along(sr), sr, FUN = seq_along) - 1L
  rep_k <- k > 0L
  suffix <- vapply(k[rep_k], function(i) {
    s <- ""
    while (i > 0L) {
      s <- paste0(letters[(i - 1L) %% 26L + 1L], s)
      i <- (i - 1L) %/% 26L
    }
    s
  }, character(1))
  sr[rep_k] <- paste0(sr[rep_k], "-", suffix)
  make.unique(sr, sep = "-")
}

# ---- the shared converter -------------------------------------------------

#' Convert a bibliometrix data frame to an sm_corpus
#'
#' The one converter behind `as_sm_corpus.bibliometrixDB()` and the
#' `engine = "bibliometrix"` / `"auto"` paths of the file readers.
#'
#' @param bib_df A data frame with Web of Science field-tag columns.
#' @param source_label Provenance source of the rows.
#' @param source_file Path of the file read, or `NULL`.
#' @param label_wos If `TRUE`, rows with `DB = "ISI"` get source `"wos"`.
#' @noRd
.bibliometrix_df_to_corpus <- function(bib_df, source_label,
                                       source_file = NULL,
                                       label_wos = FALSE) {
  metadata <- if (is.null(source_file)) {
    list()
  } else {
    list(source_file = source_file,
         reader = paste0("bibliometrix/", source_label))
  }
  n <- nrow(bib_df)
  if (n == 0L) {
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships(),
      sources = .empty_sources_abbrev(),
      metadata = metadata
    ))
  }

  # the first non-missing value of the named columns, row by row
  pick <- function(...) {
    out <- rep(NA_character_, n)
    for (nm in c(...)) {
      if (nm %in% names(bib_df)) {
        v <- .bx_text(bib_df[[nm]])
        out[is.na(out)] <- v[is.na(out)]
      }
    }
    out
  }

  work_ids <- .generate_work_id(n)
  db <- toupper(pick("DB"))
  works <- tibble::tibble(
    work_id = work_ids,
    doi = .normalize_doi(pick("DI", "DOI")),
    title = pick("TI_raw", "TI", "Title"),
    abstract = pick("AB_raw", "AB", "Abstract"),
    year = suppressWarnings(as.integer(pick("PY", "Year"))),
    type = pick("DT", "Document.Type"),
    source_id = NA_character_,
    cited_by_count = suppressWarnings(as.integer(pick("TC", "Cited.by"))),
    oa_status = NA_character_,
    language = pick("LA", "Language"),
    pmid = pick("PM"),
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  auth <- .bx_read_authors(pick("AU", "Author"), pick("AF"),
                           .bx_c1_lines(pick("C1raw"), pick("C1")),
                           pick("RP"), work_ids)
  src <- .bx_read_sources(pick("SO"), pick("SN"), pick("EI"), pick("J9"),
                          pick("JI"))
  works$source_id <- src$source_id
  concepts <- .bx_read_concepts(
    list(pick("DE_raw", "DE"), pick("ID"), pick("SC"), pick("WC")),
    list("author-keywords", .bx_id_vocabulary(source_label, db),
         "wos-subject-category", "wos-category"),
    work_ids
  )

  source <- rep(source_label, n)
  if (label_wos) source[db %in% "ISI"] <- "wos"
  provenance <- tibble::tibble(
    work_id = work_ids,
    source = source,
    source_id_external = pick("UT"),
    fetch_date = Sys.time(),
    query = if (is.null(source_file)) NA_character_ else
      .file_step_path(source_file),
    engine = "bibliometrix",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_,
    kind = "file"
  )

  new_sm_corpus(
    works = .ensure_works_schema(works),
    authors = auth$authors,
    authorships = auth$authorships,
    sources = src$sources,
    references = .bx_read_references(pick("CR"), work_ids),
    concepts = concepts,
    provenance = provenance,
    metadata = metadata
  )
}

#' Vocabulary of ID, by source label and else by DB, for each row
#' @noRd
.bx_id_vocabulary <- function(source_label, db) {
  by_label <- c(wos = "keywords-plus", scopus = "index-keywords",
                pubmed = "mesh", dimensions = "mesh", lens = "mesh",
                cochrane = "mesh", bibtex = "author-keywords",
                ris = "author-keywords")
  by_db <- c(ISI = "keywords-plus", SCOPUS = "index-keywords",
             PUBMED = "mesh", DIMENSIONS = "mesh", LENS = "mesh",
             COCHRANE = "mesh")
  label <- unname(by_label[tolower(source_label)])
  if (length(label) == 1L && !is.na(label)) return(rep(label, length(db)))
  out <- unname(by_db[db])
  out[is.na(out)] <- "index-keywords"
  out
}

#' Is a cited-reference item only a placeholder ("NONE", "NA,0000,NA")?
#' @noRd
.bx_placeholder <- function(x) {
  !nzchar(gsub("\\b(NA|NONE|0+)\\b|[[:space:][:punct:]]", "", toupper(x),
               perl = TRUE))
}

#' References from CR
#' @noRd
.bx_read_references <- function(cr, work_ids) {
  f <- .bx_split_flat(cr)
  keep <- !.bx_placeholder(f$item)
  item <- f$item[keep]
  row <- f$row[keep]
  if (length(item) == 0L) return(.empty_references())
  tibble::tibble(
    work_id = work_ids[row],
    ref_index = as.integer(stats::ave(row, row, FUN = seq_along)),
    cited_work_id = NA_character_,
    cited_doi = .cr_doi(item),
    cited_raw = item
  )
}

#' Sources from SO, SN, EI, J9 and JI; one per distinct SO
#' @noRd
.bx_read_sources <- function(so, sn, ei, j9, ji) {
  first <- which(!is.na(so) & !duplicated(so))
  if (length(first) == 0L) {
    return(list(sources = .empty_sources_abbrev(),
                source_id = rep(NA_character_, length(so))))
  }
  ids <- .generate_source_id(length(first))
  issn_l <- sn[first]
  issn_l[is.na(issn_l)] <- ei[first][is.na(issn_l)]
  sources <- tibble::tibble(
    source_id = ids,
    issn_l = issn_l,
    issn = lapply(first, function(i) {
      x <- c(sn[i], ei[i])
      unique(x[!is.na(x)])
    }),
    display_name = so[first],
    type = "journal",
    is_oa = NA,
    publisher = NA_character_,
    publisher_country = NA_character_,
    abbreviation = j9[first],
    iso_abbreviation = ji[first]
  )
  list(sources = sources, source_id = ids[match(so, so[first])])
}

#' Concepts from `;`-separated fields, one vocabulary (or one per row) for
#' each field; per work in the order of the fields
#' @noRd
.bx_read_concepts <- function(fields, vocab, work_ids) {
  n <- length(work_ids)
  parts <- lapply(seq_along(fields), function(f) {
    terms <- .bx_split_flat(fields[[f]])
    tibble::tibble(row = terms$row, field = f, concept_name = terms$item,
                   vocabulary = rep_len(vocab[[f]], n)[terms$row])
  })
  x <- dplyr::bind_rows(parts)
  if (nrow(x) == 0L) return(.empty_concepts())
  x <- x[order(x$row, x$field), , drop = FALSE]
  x <- x[!duplicated(x[, c("row", "concept_name", "vocabulary")]), ,
         drop = FALSE]
  tibble::tibble(
    work_id = work_ids[x$row],
    concept_id = NA_character_,
    concept_name = x$concept_name,
    level = NA_integer_,
    score = NA_real_,
    vocabulary = x$vocabulary
  )
}

#' Surname, initials and the text after the surname of AU entries
#' ("SURNAME IN" or "Surname, IN"). Vectorised.
#' @noRd
.bx_split_au <- function(au) {
  comma <- grepl(",", au, fixed = TRUE)
  spaced <- !comma & grepl(" ", au, fixed = TRUE)
  surname <- au
  raw <- rep("", length(au))
  surname[comma] <- trimws(sub(",.*$", "", au[comma]))
  raw[comma] <- trimws(sub("^[^,]*,", "", au[comma]))
  surname[spaced] <- sub(" [^ ]*$", "", au[spaced])
  raw[spaced] <- sub("^.* ", "", au[spaced])
  initials <- toupper(gsub("[^[:alpha:]]", "", raw))
  # a full given name in place of the initials
  long <- nchar(initials) > 4L
  initials[long] <- .bx_initials(raw[long], au[long])
  list(surname = surname, initials = initials, raw = raw)
}

#' Parse AU entries and their AF entries ("SURNAME, GIVEN NAMES"):
#' display names, spellings and match keys. Vectorised.
#' @noRd
.bx_parse_authors <- function(au, af) {
  p <- .bx_split_au(au)
  surname <- p$surname
  initials <- p$initials
  given <- rep(NA_character_, length(au))
  comma <- !is.na(af) & grepl(",", af, fixed = TRUE)
  surname[comma] <- trimws(sub(",.*$", "", af[comma]))
  given[comma] <- trimws(sub("^[^,]*,", "", af[comma]))
  # an AF without a comma: the words after the AU surname
  plain <- which(!is.na(af) & !comma)
  if (length(plain) > 0L) {
    key_s <- .bx_key(surname[plain])
    hit <- nzchar(key_s) &
      startsWith(.bx_key(af[plain]), paste0(key_s, " "))
    n_sw <- lengths(strsplit(key_s, " ", fixed = TRUE))
    words <- strsplit(af[plain], " ", fixed = TRUE)
    rest <- vapply(seq_along(plain), function(j) {
      paste(words[[j]][-seq_len(n_sw[j])], collapse = " ")
    }, character(1))
    given[plain[hit]] <- rest[hit]
  }
  no_given <- is.na(given) | !nzchar(given)
  given[no_given] <- initials[no_given]
  no_initials <- !nzchar(initials)
  context <- ifelse(is.na(af), au, af)
  initials[no_initials] <- .bx_initials(given[no_initials],
                                        context[no_initials])
  comma_form <- ifelse(nzchar(given), paste0(surname, ", ", given), surname)
  key <- .bx_key(surname)
  list(
    display = trimws(paste(given, surname)),
    alts = lapply(seq_along(au), function(j) {
      unique(c(au[j], if (!is.na(af[j])) af[j], comma_form[j]))
    }),
    full = paste(key, .bx_key(given)),
    init = paste(key, initials),
    first = paste(key, substr(initials, 1L, 1L)),
    # given names that hold no more than the initials ("P", "J. A.")
    short = gsub("[^[:alpha:]]", "", toupper(given)) == initials
  )
}

#' Author identity of parsed AU/AF entries: the full name; an entry whose
#' given names are only initials joins the one author with a full name,
#' that surname and those initials, and else the entries with that surname
#' and those initials form one author
#' @noRd
.bx_author_keys <- function(who) {
  key <- who$full
  short <- who$short
  long <- unique(data.frame(init = who$init[!short], full = who$full[!short],
                            stringsAsFactors = FALSE))
  sole <- long[!long$init %in% long$init[duplicated(long$init)], ,
               drop = FALSE]
  join <- short & who$init %in% sole$init
  key[join] <- sole$full[match(who$init[join], sole$init)]
  key[short & !join] <- who$init[short & !join]
  key
}

#' Match keys of names in the brackets of C1 ("SURNAME, GIVEN" or
#' "SURNAME IN"). Vectorised.
#' @noRd
.bx_bracket_keys <- function(name) {
  p <- .bx_split_au(name)
  initials <- p$initials
  comma <- grepl(",", name, fixed = TRUE)
  initials[comma] <- .bx_initials(p$raw[comma], name[comma])
  key <- .bx_key(p$surname)
  list(full = paste(key, .bx_key(p$raw)), init = paste(key, initials),
       first = paste(key, substr(initials, 1L, 1L)))
}

#' C1 values with `; ` between the lines of the file
#'
#' `bibliometrix::convert2df()` keeps the names of C1 in `C1raw` but joins
#' the lines there with a space, and separates the lines with `;` in `C1`,
#' where it drops the names. The addresses of `C1`, found in turn in
#' `C1raw`, mark where its lines end, so that an address without names
#' stays apart from the line before it.
#'
#' @param raw,plain `C1raw` and `C1` values, one per work.
#' @return `raw` with `; ` between its lines; `raw` as given where the two
#'   do not agree, and `plain` where `raw` is `NA`.
#' @noRd
.bx_c1_lines <- function(raw, plain) {
  out <- ifelse(is.na(raw), plain, raw)
  for (i in which(!is.na(raw) & !is.na(plain))) {
    addr <- .bx_text(strsplit(plain[i], ";", fixed = TRUE)[[1]])
    addr <- addr[!is.na(addr)]
    lines <- character(length(addr))
    pos <- 1L
    for (k in seq_along(addr)) {
      at <- regexpr(addr[k], substring(raw[i], pos), fixed = TRUE)
      if (at < 0L) break
      end <- pos + at + nchar(addr[k]) - 2L
      lines[k] <- substr(raw[i], pos, end)
      pos <- end + 1L
    }
    if (length(addr) > 0L && all(nzchar(lines)) &&
          !nzchar(trimws(substring(raw[i], pos)))) {
      out[i] <- paste(trimws(lines), collapse = "; ")
    }
  }
  out
}

#' Segments of C1: each address with the names in the bracket group before
#' it (`names`, `NA` for text outside the groups and `""` for text with a
#' stray bracket, whose names cannot be read) and the index `row` of
#' the C1 value
#' @noRd
.bx_c1_segments <- function(c1) {
  groups <- gregexpr("\\[[^\\[\\]]*\\]", c1, perl = TRUE)
  rows <- list()
  inner <- list()
  text <- list()
  for (i in which(!is.na(c1))) {
    x <- c1[i]
    starts <- as.integer(groups[[i]])
    if (starts[1] == -1L) {
      rows[[i]] <- i
      inner[[i]] <- NA_character_
      text[[i]] <- x
      next
    }
    ends <- starts + attr(groups[[i]], "match.length") - 1L
    stops <- c(starts[-1L] - 1L, nchar(x))
    rows[[i]] <- rep(i, length(starts) + 1L)
    inner[[i]] <- c(NA_character_, substring(x, starts + 1L, ends - 1L))
    text[[i]] <- c(substr(x, 1L, starts[1] - 1L),
                   substring(x, ends + 1L, stops))
  }
  row <- as.integer(unlist(rows, use.names = FALSE))
  inner <- as.character(unlist(inner, use.names = FALSE))
  # the text after a group: its address, then addresses without names
  parts <- strsplit(as.character(unlist(text, use.names = FALSE)), ";",
                    fixed = TRUE)
  unit <- rep(seq_along(parts), lengths(parts))
  names <- inner[unit]
  names[duplicated(unit)] <- NA_character_
  part <- as.character(unlist(parts, use.names = FALSE))
  # a stray bracket: names that cannot be read, rather than none
  names[is.na(names) & grepl("[][]", part)] <- ""
  address <- .bx_text(gsub("[][]", "", part))
  keep <- !is.na(address)
  list(row = row[unit][keep], names = names[keep], address = address[keep])
}

#' The `full`, `init` and `first` match keys of the entries `idx`
#' @noRd
.bx_keys_at <- function(keys, idx) {
  lapply(keys[c("full", "init", "first")], function(k) k[idx])
}

#' Match names to the authors of one work: each name takes the first
#' author not yet taken whose full name agrees, else surname and initials,
#' else surname and first initial
#'
#' @param who Match keys (`full`, `init`, `first`) of the work's authors,
#'   as from `.bx_parse_authors()`.
#' @param bk Match keys of the names, as from `.bx_bracket_keys()`.
#' @return The indexes into `who` of the authors matched, in the order of
#'   the names that matched.
#' @noRd
.bx_match_keys <- function(who, bk) {
  hit <- integer()
  for (q in seq_along(bk$full)) {
    for (level in c("full", "init", "first")) {
      cand <- setdiff(which(who[[level]] == bk[[level]][q]), hit)
      if (length(cand) > 0L) {
        hit <- c(hit, cand[1])
        break
      }
    }
  }
  hit
}

#' Addresses of author entries, linked through the names in the brackets
#' of C1 (`.bx_match_keys()`). An address without names, as in older
#' records, belongs to every author of the work; one whose names designate
#' none of the authors belongs to the author of a single-author work.
#'
#' @param who Parsed author entries of all works (`.bx_parse_authors()`).
#' @param row The work (index) of each author entry.
#' @param seg C1 segments of all works (`.bx_c1_segments()`).
#' @param n Number of works.
#' @return A list along the author entries with their distinct addresses,
#'   `NA` for an entry without any.
#' @noRd
.bx_link_addresses <- function(who, row, seg, n) {
  nm <- .bx_split_flat(seg$names)
  bk <- .bx_bracket_keys(nm$item)
  by_work <- split(seq_along(row), factor(row, levels = seq_len(n)))
  seg_by_work <- split(seq_along(seg$row),
                       factor(seg$row, levels = seq_len(n)))
  names_by_seg <- split(seq_along(nm$item),
                        factor(nm$row, levels = seq_along(seg$row)))
  linked <- rep(list(character()), length(row))
  for (i in which(lengths(seg_by_work) > 0L & lengths(by_work) > 0L)) {
    idx <- by_work[[i]]
    for (s in seg_by_work[[i]]) {
      # an address without names: every author's
      to <- idx
      if (!is.na(seg$names[s])) {
        hit <- .bx_match_keys(.bx_keys_at(who, idx),
                              .bx_keys_at(bk, names_by_seg[[s]]))
        # names that designate nobody: the sole author's, if there is one
        if (length(hit) > 0L || length(idx) > 1L) to <- idx[hit]
      }
      for (j in to) linked[[j]] <- c(linked[[j]], seg$address[s])
    }
  }
  lapply(linked, function(x) {
    if (length(x) > 0L) unique(x) else NA_character_
  })
}

#' Corresponding-author flags of author entries from RP: the authors that
#' the names of RP designate (`.rp_entries()`, matched as C1 names are,
#' with the RP address telling namesakes apart, `.names_designate()`) are
#' `TRUE` and the other authors of the work `FALSE`; namesakes that RP
#' does not tell apart are `NA`, and a work whose RP designates none of
#' its authors, or that has no RP, gets `NA`
#'
#' @param who,row,n As for `.bx_link_addresses()`.
#' @param rp RP values, one per work.
#' @param linked The addresses of the author entries
#'   (`.bx_link_addresses()`).
#' @return A logical vector along the author entries.
#' @noRd
.bx_rp_flags <- function(who, row, rp, n, linked) {
  entries <- .rp_entries(rp)
  e_name <- lapply(entries, `[[`, "name")
  e_row <- rep(seq_len(n), lengths(e_name))
  bk <- .bx_bracket_keys(unlist(e_name, use.names = FALSE))
  bk_addr <- .bx_key(unlist(lapply(entries, `[[`, "address"),
                            use.names = FALSE))
  addr <- split(.bx_key(unlist(linked, use.names = FALSE)),
                factor(rep(seq_along(linked), lengths(linked)),
                       levels = seq_along(linked)))
  by_work <- split(seq_along(row), factor(row, levels = seq_len(n)))
  entries_by_work <- split(seq_along(e_row),
                           factor(e_row, levels = seq_len(n)))
  flags <- rep(NA, length(row))
  for (i in which(lengths(entries_by_work) > 0L & lengths(by_work) > 0L)) {
    idx <- by_work[[i]]
    e <- entries_by_work[[i]]
    hit <- .names_designate(.bx_keys_at(who, idx), .bx_keys_at(bk, e),
                            unname(addr[idx]), bk_addr[e])
    flags[idx] <- .corresponding_flags(length(idx), hit)
  }
  flags
}

#' Authors and authorships from AU, AF, C1 and RP: one row per author
#' position and address, linked through the names in the brackets of C1,
#' and the corresponding authors that RP names
#' @noRd
.bx_read_authors <- function(au, af, c1, rp, work_ids) {
  n <- length(work_ids)
  au <- .bx_split_flat(au)
  if (length(au$item) == 0L) {
    return(list(authors = .empty_authors(),
                authorships = .empty_authorships()))
  }
  pos <- as.integer(stats::ave(au$row, au$row, FUN = seq_along))
  # AF entries belong to the AU entries when a work has as many of each
  af <- .bx_split_flat(af)
  same <- tabulate(af$row, nbins = n) == tabulate(au$row, nbins = n)
  af_item <- rep(NA_character_, length(au$item))
  af_item[same[au$row]] <- af$item[same[af$row]]
  who <- .bx_parse_authors(au$item, af_item)
  linked <- .bx_link_addresses(who, au$row, .bx_c1_segments(c1), n)
  corresponding <- .bx_rp_flags(who, au$row, rp, n, linked)

  # one author per identity, named after its first entry with a full name
  key <- .bx_author_keys(who)
  uk <- unique(key)
  full_first <- which(!who$short)[match(uk, key[!who$short])]
  lead <- ifelse(is.na(full_first), match(uk, key), full_first)
  alts <- split(who$alts, factor(key, levels = uk))
  author_ids <- .generate_author_id(length(uk))
  authors <- tibble::tibble(
    author_id = author_ids,
    orcid = NA_character_,
    display_name = who$display[lead],
    display_name_alternatives = unname(lapply(alts, function(x) {
      unique(unlist(x, use.names = FALSE))
    })),
    inferred_gender = NA_character_,
    gender_confidence = NA_real_,
    gender_method = NA_character_
  )
  k <- lengths(linked)
  authorships <- tibble::tibble(
    work_id = rep(work_ids[au$row], k),
    author_id = rep(author_ids[match(key, uk)], k),
    position = rep(pos, k),
    is_corresponding = rep(corresponding, k),
    institution_id = NA_character_,
    raw_affiliation = unlist(linked, use.names = FALSE),
    country_code = NA_character_
  )
  list(authors = authors, authorships = authorships)
}

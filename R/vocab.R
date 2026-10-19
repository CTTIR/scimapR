# B1: exported controlled vocabularies for the package's factor columns.
# These level sets are the single source of truth used both to factorise the
# emitted columns and for users to filter reliably.

#' @noRd
.aff_signal_levels <- function() {
  c("name_token", "email_domain", "postcode", "none")
}

#' @noRd
.aff_method_levels <- function() {
  c("pattern", "email_domain", "postcode", "none")
}

#' @noRd
.match_type_levels <- function() {
  c("doi", "title", "none")
}

#' Controlled vocabulary for affiliation match signals
#'
#' @description
#' The ordered set of values the `match_signal` column of
#' [sm_affiliation_match()] / [sm_affiliation_summary()] can take. Using this
#' helper (rather than hard-coding strings) means downstream filtering --- e.g.
#' separating institution-name matches from email-domain matches --- cannot
#' drift if the levels change.
#'
#' @param describe Logical; if `TRUE`, return a tibble of `level` + a short
#'   `description`. If `FALSE` (default), return the ordered character vector of
#'   levels (suitable for `factor(levels = )`).
#'
#' @return A character vector (ordered, highest matching priority first) or a
#'   tibble of `level`/`description`.
#'
#' @family affiliation
#' @seealso [sm_affiliation_match()], [sm_affiliation_methods()]
#' @export
#' @examples
#' sm_affiliation_signals()
#' sm_affiliation_signals(describe = TRUE)
sm_affiliation_signals <- function(describe = FALSE) {
  lv <- .aff_signal_levels()
  if (!isTRUE(describe)) return(lv)
  tibble::tibble(
    level = factor(lv, levels = lv),
    description = c(
      "Institution name token matched a dictionary pattern.",
      "Author email domain matched a dictionary email domain.",
      "Affiliation postcode matched a dictionary postcode (opt-in).",
      "No signal matched this authorship."
    )
  )
}

#' Controlled vocabulary for affiliation match methods
#'
#' @description
#' The set of values the `match_method` column of [sm_affiliation_match()] can
#' take.
#'
#' @param describe Logical; if `TRUE`, return a tibble of `level` +
#'   `description`, else the ordered character vector (default).
#' @return A character vector or a tibble.
#' @family affiliation
#' @seealso [sm_affiliation_signals()]
#' @export
#' @examples
#' sm_affiliation_methods()
sm_affiliation_methods <- function(describe = FALSE) {
  lv <- .aff_method_levels()
  if (!isTRUE(describe)) return(lv)
  tibble::tibble(
    level = factor(lv, levels = lv),
    description = c(
      "Dictionary regex pattern match.",
      "Email-domain fallback match.",
      "Postcode match (opt-in).",
      "No match."
    )
  )
}

#' Controlled vocabulary for coverage match types
#'
#' @description
#' The set of values the `match_type` column of [sm_coverage_audit()]'s
#' `matches` tibble (and [sm_reconcile()]'s) can take.
#'
#' @param describe Logical; if `TRUE`, return a tibble of `level` +
#'   `description`, else the ordered character vector (default).
#' @return A character vector or a tibble.
#' @family coverage
#' @seealso [sm_coverage_audit()], [sm_reconcile()]
#' @export
#' @examples
#' sm_match_types()
sm_match_types <- function(describe = FALSE) {
  lv <- .match_type_levels()
  if (!isTRUE(describe)) return(lv)
  tibble::tibble(
    level = factor(lv, levels = lv),
    description = c(
      "Matched by normalised DOI.",
      "Matched by fuzzy title similarity.",
      "No match."
    )
  )
}

# ---- Concept vocabularies (corpus$concepts$vocabulary) ----------------------

#' Canonical concept vocabularies with their families and descriptions
#' @noRd
.concept_vocab_table <- function() {
  tibble::tibble(
    level = c(
      "author-keywords", "manual-tags",
      "keywords-plus", "index-keywords", "automatic-tags", "mesh",
      "wos-category", "wos-subject-category",
      "openalex", "arxiv", "biorxiv", "medrxiv",
      "custom"
    ),
    family = c(
      rep("author_keyword", 2L),
      rep("indexer_keyword", 4L),
      rep("category", 2L),
      rep("concept", 4L),
      "custom"
    ),
    description = c(
      paste("Keywords chosen by the authors (Web of Science DE; author",
            "keywords from Scopus, Dimensions, Lens, BibTeX, RIS and",
            "EndNote files)."),
      "Tags added by hand in Zotero.",
      paste("Web of Science Keywords Plus (ID), derived from the titles of",
            "cited references."),
      "Scopus index keywords, assigned by indexers.",
      "Tags Zotero added automatically on import.",
      "Medical Subject Headings from PubMed, Dimensions or Lens.",
      "Web of Science categories (WC) of the journal.",
      "Web of Science research areas (SC), broader groups of the categories.",
      "OpenAlex concepts.",
      "arXiv subject categories.",
      "bioRxiv subject categories.",
      "medRxiv subject categories.",
      "A vocabulary defined by the user."
    )
  )
}

#' @noRd
.concept_vocab_levels <- function() {
  .concept_vocab_table()$level
}

#' @noRd
.concept_family_levels <- function() {
  c("author_keyword", "indexer_keyword", "category", "concept", "custom")
}

#' Vocabulary names as valid UTF-8 text
#'
#' Text in a declared encoding is converted to UTF-8, and bytes that are not
#' valid UTF-8 (such as latin1 text read as UTF-8) are written as `<xx>`, so
#' that string functions, sorting and messages work on every value. `NA`
#' stays `NA`.
#' @noRd
.concept_vocab_text <- function(x) {
  x <- enc2utf8(as.character(x))
  bad <- !is.na(x) & (!validUTF8(x) | Encoding(x) == "bytes")
  x[bad] <- iconv(x[bad], "UTF-8", "UTF-8", sub = "byte")
  x
}

#' Comparison key for vocabulary names: lower case, without white space or
#' the separators `-`, `_`, `.` and `/`. A value that is not valid UTF-8
#' gets a key that matches no vocabulary.
#' @noRd
.concept_vocab_key <- function(x) {
  gsub("[-_./[:space:]]+", "", tolower(trimws(.concept_vocab_text(x))))
}

#' Legacy and common spellings of the canonical vocabularies, by key
#' @noRd
.concept_vocab_aliases <- function() {
  c(
    keywordsauthor = "author-keywords", keyword = "author-keywords",
    keywords = "author-keywords", authorkeyword = "author-keywords",
    de = "author-keywords",
    manualtag = "manual-tags",
    keywordplus = "keywords-plus", id = "keywords-plus",
    indexkeyword = "index-keywords",
    automatictag = "automatic-tags",
    medline = "mesh", meshterm = "mesh", meshterms = "mesh",
    meshheading = "mesh", meshheadings = "mesh",
    medicalsubjectheadings = "mesh",
    wc = "wos-category", woscategories = "wos-category",
    webofsciencecategory = "wos-category",
    webofsciencecategories = "wos-category",
    sc = "wos-subject-category", wossubjectcategories = "wos-subject-category",
    researcharea = "wos-subject-category",
    researchareas = "wos-subject-category",
    openalexconcepts = "openalex"
  )
}

#' Normalise concept vocabulary names
#'
#' Maps canonical names and their legacy or common spellings (such as
#' `"keywords-author"`, `"keyword"`, `"Author Keywords"`, `"DE"` or
#' `"MEDLINE"`) to the names of [sm_concept_vocabularies()], ignoring case,
#' white space and the separators `-`, `_`, `.` and `/`. Silent.
#'
#' @param x Character or factor vector of vocabulary names.
#' @return A character vector the length of `x`: canonical names where `x`
#'   names a known vocabulary, `x` unchanged otherwise, `NA` where `x` is `NA`.
#' @noRd
.normalize_concept_vocab <- function(x) {
  x <- as.character(x)
  if (length(x) == 0L) return(character())
  u <- unique(x)
  lv <- .concept_vocab_levels()
  lookup <- c(stats::setNames(lv, .concept_vocab_key(lv)),
              .concept_vocab_aliases())
  canon <- unname(lookup[.concept_vocab_key(u)])
  canon[is.na(canon)] <- u[is.na(canon)]
  canon[match(x, u)]
}

#' Family of concept vocabulary names
#'
#' @param x Character or factor vector of vocabulary names, normalised
#'   silently with `.normalize_concept_vocab()`.
#' @return A character vector the length of `x`: the family of each value
#'   (`sm_concept_vocabularies(describe = TRUE)$family`), `NA` for `NA` and
#'   for values that are not in [sm_concept_vocabularies()].
#' @noRd
.concept_vocab_family <- function(x) {
  tab <- .concept_vocab_table()
  tab$family[match(.normalize_concept_vocab(x), tab$level)]
}

#' Resolve family and vocabulary names to canonical vocabularies
#'
#' Each value is a family name (which stands for all its vocabularies) or a
#' vocabulary name in any spelling `.normalize_concept_vocab()` knows; family
#' names win where a key matches both.
#'
#' @param x Character vector of family and/or vocabulary names.
#' @param arg Argument name for the error message.
#' @param call Caller environment for error reporting.
#' @return The canonical vocabularies, unique and in the order of
#'   [sm_concept_vocabularies()]. Aborts on values that name neither.
#' @noRd
.resolve_concept_vocab <- function(x, arg = "vocabulary",
                                   call = rlang::caller_env()) {
  if (is.factor(x)) x <- as.character(x)
  if (!is.character(x) || length(x) == 0L || anyNA(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a character vector of vocabulary or family
       names without {.code NA}.",
      call = call
    )
  }
  tab <- .concept_vocab_table()
  families <- .concept_family_levels()
  fam <- families[match(.concept_vocab_key(x), .concept_vocab_key(families))]
  canon <- .normalize_concept_vocab(x)
  bad <- .concept_vocab_text(unique(x[is.na(fam) & !canon %in% tab$level]))
  if (length(bad) > 0L) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must name vocabularies or families of
         {.fn sm_concept_vocabularies}.",
        "x" = "Unknown value{?s}: {.val {bad}}.",
        "i" = "Vocabularies: {.val {tab$level}}.",
        "i" = "Families: {.val {families}}."
      ),
      call = call
    )
  }
  keep <- tab$level %in% canon[is.na(fam)] | tab$family %in% fam
  tab$level[keep]
}

#' Concept rows of the given families or vocabularies
#'
#' The one filter every consumer of `corpus$concepts` uses to select
#' concepts by vocabulary. The `vocabulary` column is normalised silently,
#' so corpora that bypass [sm_corpus()] (saved, bound or assigned tables)
#' are read the same way.
#'
#' @param concepts A concepts table (`corpus$concepts`).
#' @param family Character vector of family and/or vocabulary names, as
#'   resolved by `.resolve_concept_vocab()`.
#' @param call Caller environment for error reporting.
#' @return The matching rows of `concepts` in their original order, with
#'   all columns and the canonical name in `vocabulary`. A 0-row table with
#'   the same columns when nothing matches or `concepts` has no
#'   `vocabulary` column.
#' @noRd
.concepts_in_family <- function(concepts, family, call = rlang::caller_env()) {
  levels <- .resolve_concept_vocab(family, arg = "family", call = call)
  if (!"vocabulary" %in% names(concepts)) {
    return(concepts[0L, , drop = FALSE])
  }
  vocab <- .normalize_concept_vocab(concepts$vocabulary)
  keep <- vocab %in% levels
  out <- concepts[keep, , drop = FALSE]
  out$vocabulary <- vocab[keep]
  out
}

#' Normalise the vocabularies of a concepts table entering a corpus
#'
#' Used by [sm_corpus()] and [sm_corpus_from_tables()]; readers write
#' canonical names and stay silent. Informs once: the message has class
#' `scimapR_concept_vocab_renamed` when a value was renamed and class
#' `scimapR_concept_vocab_unknown` when values not in
#' [sm_concept_vocabularies()] were kept as they are.
#' @noRd
.normalize_corpus_concepts <- function(concepts) {
  if (!is.data.frame(concepts) || !"vocabulary" %in% names(concepts)) {
    return(concepts)
  }
  old <- as.character(concepts$vocabulary)
  new <- .normalize_concept_vocab(old)
  concepts$vocabulary <- new

  changed <- !is.na(old) & old != new
  # The message shows values as valid text, so values that are not valid
  # UTF-8 can be listed too; the table keeps them as they are.
  pairs <- unique(data.frame(from = .concept_vocab_text(old[changed]),
                             to = new[changed], stringsAsFactors = FALSE))
  text <- .concept_vocab_text(new)
  unknown <- sort(unique(text[!is.na(new) & nzchar(trimws(text)) &
                                !new %in% .concept_vocab_levels()]),
                  method = "radix")
  if (nrow(pairs) == 0L && length(unknown) == 0L) {
    return(concepts)
  }

  n_from <- nrow(pairs)
  msg <- character()
  if (n_from > 0L) {
    # One bullet per renamed value; the template indexes `pairs`, so no
    # data text is pasted into it.
    msg <- c(
      "i" = "Renamed {n_from} concept vocabular{?y/ies} to {?its/their}
             name{?s} in {.fn sm_concept_vocabularies}:",
      stats::setNames(
        sprintf("{.val {pairs$from[%d]}} to {.val {pairs$to[%d]}}",
                seq_len(n_from), seq_len(n_from)),
        rep("*", n_from)
      )
    )
  }
  if (length(unknown) > 0L) {
    msg <- c(
      msg,
      "i" = "Kept concept vocabular{?y/ies} {.val {unknown}}, not in
             {.fn sm_concept_vocabularies}: functions that select concepts
             by vocabulary, such as {.fn sm_to_bibliometrix} for DE and
             {.code sm_network_coword(field = \"keywords\")}, do not read
             {?it/them}.",
      "i" = "Name a vocabulary of your own {.val custom}."
    )
  }
  cli::cli_inform(
    msg,
    class = c(
      if (n_from > 0L) "scimapR_concept_vocab_renamed",
      if (length(unknown) > 0L) "scimapR_concept_vocab_unknown"
    )
  )
  concepts
}

#' Controlled vocabulary for concept vocabularies
#'
#' @description
#' The canonical values of the `vocabulary` column of `corpus$concepts`.
#' Readers write these names (for example `"author-keywords"` for author
#' keywords and `"wos-category"` for the Web of Science categories), and the
#' functions that select concepts by vocabulary, such as
#' [sm_to_bibliometrix()] (DE) and [sm_network_coword()]
#' (`field = "keywords"`), read them.
#'
#' Each vocabulary belongs to a family:
#' * `author_keyword`: `author-keywords`, `manual-tags`;
#' * `indexer_keyword`: `keywords-plus`, `index-keywords`,
#'   `automatic-tags`, `mesh`;
#' * `category`: `wos-category` (WC, the Web of Science categories),
#'   `wos-subject-category` (SC, the research areas);
#' * `concept`: `openalex`, `arxiv`, `biorxiv`, `medrxiv`;
#' * `custom`: `custom`, for vocabularies of your own.
#'
#' [sm_corpus()] and [sm_corpus_from_tables()] rename legacy and common
#' spellings to these names, with a message: case, white space and the
#' separators `-`, `_`, `.` and `/` do not matter, `"keywords-author"`,
#' `"keyword"` and `"keywords"` become `"author-keywords"`, `"medline"`
#' becomes `"mesh"`, and the Web of Science field tags `"DE"`, `"ID"`,
#' `"WC"` and `"SC"` name their vocabularies. Other values are kept and
#' named in the message. The functions that select concepts by vocabulary
#' read these spellings too, so saved corpora and tables assigned to
#' `corpus$concepts` work as well. The column stays character.
#'
#' @param describe Logical; if `TRUE`, return a tibble with the factor
#'   columns `level` and `family` and a `description`. If `FALSE` (default),
#'   return the character vector of vocabularies.
#'
#' @return A character vector (grouped by family) or a tibble of
#'   `level`/`family`/`description`.
#'
#' @family corpus
#' @seealso [sm_to_bibliometrix()], [sm_network_coword()], [sm_read_wos()]
#' @export
#' @examples
#' sm_concept_vocabularies()
#' sm_concept_vocabularies(describe = TRUE)
#'
#' corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE)
#' table(corpus$concepts$vocabulary)
sm_concept_vocabularies <- function(describe = FALSE) {
  tab <- .concept_vocab_table()
  if (!isTRUE(describe)) return(tab$level)
  tibble::tibble(
    level = factor(tab$level, levels = tab$level),
    family = factor(tab$family, levels = .concept_family_levels()),
    description = tab$description
  )
}

# Internal helper for the language of works (works$language), which the
# readers write in different forms.

#' Languages that `.normalize_language()` recognises
#'
#' One row per language: the ISO 639-1 code, the ISO 639-2 bibliographic
#' (`b`) and terminology (`t`) codes, which differ for a few languages
#' (German: `ger` and `deu`), and the English name in lower case.
#' @noRd
.language_table <- data.frame(
  code = c(
    "en", "de", "fr", "es", "it", "pt", "nl", "ru", "zh", "ja",
    "ko", "pl", "sv", "da", "no", "fi", "is", "cs", "sk", "hu",
    "ro", "bg", "hr", "sr", "sl", "uk", "be", "lt", "lv", "et",
    "el", "tr", "ar", "he", "fa", "ur", "hi", "bn", "th", "vi",
    "id", "ms", "ca", "eu", "gl", "ga", "cy", "af", "sq", "mk",
    "ka", "hy", "az", "kk", "la", "eo"
  ),
  b = c(
    "eng", "ger", "fre", "spa", "ita", "por", "dut", "rus", "chi", "jpn",
    "kor", "pol", "swe", "dan", "nor", "fin", "ice", "cze", "slo", "hun",
    "rum", "bul", "hrv", "srp", "slv", "ukr", "bel", "lit", "lav", "est",
    "gre", "tur", "ara", "heb", "per", "urd", "hin", "ben", "tha", "vie",
    "ind", "may", "cat", "baq", "glg", "gle", "wel", "afr", "alb", "mac",
    "geo", "arm", "aze", "kaz", "lat", "epo"
  ),
  t = c(
    "eng", "deu", "fra", "spa", "ita", "por", "nld", "rus", "zho", "jpn",
    "kor", "pol", "swe", "dan", "nor", "fin", "isl", "ces", "slk", "hun",
    "ron", "bul", "hrv", "srp", "slv", "ukr", "bel", "lit", "lav", "est",
    "ell", "tur", "ara", "heb", "fas", "urd", "hin", "ben", "tha", "vie",
    "ind", "msa", "cat", "eus", "glg", "gle", "cym", "afr", "sqi", "mkd",
    "kat", "hye", "aze", "kaz", "lat", "epo"
  ),
  name = c(
    "english", "german", "french", "spanish", "italian", "portuguese",
    "dutch", "russian", "chinese", "japanese", "korean", "polish",
    "swedish", "danish", "norwegian", "finnish", "icelandic", "czech",
    "slovak", "hungarian", "romanian", "bulgarian", "croatian", "serbian",
    "slovenian", "ukrainian", "belarusian", "lithuanian", "latvian",
    "estonian", "greek", "turkish", "arabic", "hebrew", "persian", "urdu",
    "hindi", "bengali", "thai", "vietnamese", "indonesian", "malay",
    "catalan", "basque", "galician", "irish", "welsh", "afrikaans",
    "albanian", "macedonian", "georgian", "armenian", "azerbaijani",
    "kazakh", "latin", "esperanto"
  ),
  stringsAsFactors = FALSE
)

#' Other names and codes of the languages in `.language_table`
#' @noRd
.language_aliases <- c(
  castilian = "es", flemish = "nl", farsi = "fa", slovene = "sl",
  "modern greek" = "el", moldavian = "ro", moldovan = "ro",
  "norwegian bokmal" = "no", bokmal = "no", "norwegian nynorsk" = "no",
  nynorsk = "no", nb = "no", nn = "no", nob = "no", nno = "no",
  "serbo-croatian" = "sr", mandarin = "zh",
  deutsch = "de", francais = "fr", "fran\u00e7ais" = "fr",
  espanol = "es", "espa\u00f1ol" = "es", italiano = "it",
  portugues = "pt", "portugu\u00eas" = "pt", nederlands = "nl",
  polski = "pl", svenska = "sv", dansk = "da", norsk = "no", suomi = "fi"
)

#' Values that say the language is not known
#' @noRd
.language_unknown <- c("und", "zxx", "unknown", "undetermined",
                       "unspecified", "na", "n/a", "none")

#' Normalise language values to ISO 639-1 codes
#'
#' The readers write the language of a work in different forms: names
#' such as `"English"` and `"German"` (Web of Science, Scopus; upper case
#' from the bibliometrix import), ISO 639-1 codes such as `"en"` and
#' `"de"` (OpenAlex, Crossref), ISO 639-2 codes such as `"eng"` and `"ger"`
#' or `"deu"` (PubMed) and language tags such as `"en-US"`. This helper
#' maps all of them to one form. Case and surrounding white space do not
#' matter, a value that lists several languages (`"English; German"`)
#' counts by its first one, and a region in brackets
#' (`"Portuguese (Brazil)"`) is ignored.
#'
#' @param x Language values: a character vector or a factor (`NULL` gives
#'   `character()`).
#' @return A character vector along `x`: the ISO 639-1 code of each
#'   recognised value (`"en"`, `"de"`, ...), `NA` for missing or blank
#'   values and for values that say the language is unknown (`"und"`,
#'   `"zxx"`, `"unknown"`), and the trimmed lower-case value for any other
#'   text, which therefore still counts as a known language.
#' @noRd
.normalize_language <- function(x) {
  if (is.null(x)) return(character())
  x <- as.character(x)
  space <- "[\\h\\v]"
  key <- tolower(trimws(x, whitespace = space))
  key <- trimws(sub("[;,/|].*$", "", key), whitespace = space)
  key <- trimws(sub("\\(.*\\)$", "", key), whitespace = space)
  # language tags: "en-US", "de_DE", "zh-Hans"
  tag <- !is.na(key) & grepl("^[a-z]{2,3}[-_][a-z0-9]+$", key)
  key[tag] <- sub("[-_].*$", "", key[tag])

  tab <- .language_table
  lookup <- c(
    stats::setNames(tab$code, tab$code),
    stats::setNames(tab$code, tab$b),
    stats::setNames(tab$code, tab$t),
    stats::setNames(tab$code, tab$name),
    .language_aliases
  )
  out <- unname(lookup[key])
  other <- is.na(out) & !is.na(key) & nzchar(key) &
    !key %in% .language_unknown
  out[other] <- key[other]
  out
}

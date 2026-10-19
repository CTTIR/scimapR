#' Bundled example corpus
#'
#' @description
#' A pre-built synthetic corpus with 200 works, 80 authors, 5 clusters,
#' and embeddings. Created with `sm_example_corpus(seed = 42)`.
#'
#' @format An `sm_corpus` S3 object.
#' @source Synthetically generated.
#' @examples
#' data(sm_example_db)
#' print(sm_example_db)
"sm_example_db"

#' Default affiliation-matching dictionary
#'
#' @description
#' A small, documented, user-overridable dictionary of institution name
#' variants used by [sm_affiliation_match()]. It covers common military /
#' medical institution variants (including German synonyms) plus email-domain
#' fallbacks, and is designed to be extended by appending rows.
#'
#' @format A tibble with three columns:
#' \describe{
#'   \item{institution}{Canonical institution name (character).}
#'   \item{pattern}{A case-insensitive Perl-compatible regular expression
#'     matched against affiliation strings (character).}
#'   \item{email_domain}{Optional email domain used by the email-domain
#'     fallback, or `NA` (character).}
#' }
#' @details
#' Patterns are case-insensitive PCRE with Unicode-aware `\w`, `\b`, `\d`
#' and `\s`: [sm_affiliation_match()] matches them in Unicode mode by
#' default, so a row added for a German, French or Scandinavian name can use
#' these classes next to non-ASCII letters (see the Details of
#' [sm_affiliation_match()], including its `unicode` argument). In that
#' mode the shipped row `\bnato\b` no longer matches "NATO" directly
#' followed by an umlaut, as in a German compound word. The first pattern
#' that matches wins, in row order, so add specific rows before generic
#' ones.
#'
#' The rows for "Bundeswehr Hospital" match its German name, its
#' abbreviation, or "hospital" after "Bundeswehr" or after "German Armed
#' Forces", "German Army" or "German Military", with at most one word in
#' between. A bare "military hospital", "army hospital" or "armed forces
#' hospital", which names hospitals of many countries, stays unmatched; up
#' to scimapR 0.4.0 these phrases matched "Bundeswehr Hospital" wherever
#' they appeared. The dictionary is a starting point: for an audit of your
#' own institutions, pass a dictionary of them to [sm_affiliation_match()].
#' @seealso [sm_affiliation_match()], [sm_affiliation_unmatched()]
#' @examples
#' sm_affiliation_dict
"sm_affiliation_dict"

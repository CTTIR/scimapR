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
#'   \item{pattern}{A case-insensitive regular expression matched against
#'     affiliation strings (character).}
#'   \item{email_domain}{Optional email domain used by the email-domain
#'     fallback, or `NA` (character).}
#' }
#' @seealso [sm_affiliation_match()]
#' @examples
#' sm_affiliation_dict
"sm_affiliation_dict"

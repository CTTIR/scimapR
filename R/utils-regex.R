# Internal helpers for regular expressions that users supply (affiliation
# dictionaries, screening terms).

#' Ask PCRE for Unicode-aware character classes
#'
#' R hands non-ASCII text to PCRE in UTF mode but never asks for Unicode
#' properties, so `\w`, `\d`, `\s`, `\b` and the POSIX classes only know
#' ASCII: `sanit\w+wesens` cannot consume the a-umlaut of the German word,
#' and `\b` finds no word edge next to a non-ASCII letter. This helper
#' prefixes a pattern with the start-of-pattern item `(*UCP)` unless its
#' leading items already include it; other leading items such as `(*UTF)`
#' stay and follow the prefix. `NA` and empty patterns are returned
#' unchanged, because `"(*UCP)"` would match every string. Use it only for
#' patterns that users write; internal fixed-ASCII patterns stay as they are.
#'
#' @param pattern Character vector of PCRE patterns.
#' @param unicode `FALSE` returns `pattern` unchanged (ASCII-only classes).
#' @return A character vector the length of `pattern`.
#' @noRd
.ucp_regex <- function(pattern, unicode = TRUE) {
  if (!unicode) {
    return(pattern)
  }
  has_ucp <- grepl("^(\\(\\*[A-Z_0-9=]+\\))*\\(\\*UCP\\)", pattern,
                   perl = TRUE)
  add <- !is.na(pattern) & nzchar(pattern) & !has_ucp
  pattern[add] <- paste0("(*UCP)", pattern[add])
  pattern
}

# Corresponding authors: the flags in authorships$is_corresponding, shared
# by every reader and fetcher.

#' Corresponding-author flags of the authors of one work
#'
#' `TRUE` for the authors that the source names as corresponding, `FALSE`
#' for the other authors of a work that names at least one, and `NA`
#' (unknown) for every author of a work that names none. An author that a
#' name could designate together with a namesake stays `NA`. Readers of
#' sources without corresponding-author data pass `hit = NULL`, so all
#' their flags are `NA`.
#'
#' @param n Number of authors of the work.
#' @param hit `NULL`, or a logical vector of length `n`: `TRUE` for the
#'   corresponding authors, `NA` for authors the source may name but does
#'   not tell apart from a namesake (`.names_designate()`), `FALSE`
#'   otherwise.
#' @return A logical vector of length `n`.
#' @noRd
.corresponding_flags <- function(n, hit = NULL) {
  if (is.null(hit) || !any(hit %in% TRUE)) return(rep(NA, n))
  out <- hit %in% TRUE
  out[is.na(hit)] <- NA
  out
}

#' Corresponding-author flags of one OpenAlex work
#'
#' OpenAlex flags corresponding authors with `authorships[].is_corresponding`
#' and lists them in `corresponding_author_ids`. It writes `false` for every
#' author when it does not know the corresponding author, so a work without
#' a `true` flag and without a listed author gets `NA` for all authors.
#'
#' @param flags The `is_corresponding` values of the work's authors (`NULL`
#'   entries as `FALSE` or `NA`).
#' @param author_ids The OpenAlex ids of the same authors.
#' @param listed The work's `corresponding_author_ids`, or `NULL`.
#' @return A logical vector along `flags`.
#' @noRd
.openalex_corresponding <- function(flags, author_ids, listed = NULL) {
  hit <- flags %in% TRUE
  if (!any(hit)) {
    hit <- !is.na(author_ids) &
      author_ids %in% as.character(unlist(listed, use.names = FALSE))
  }
  .corresponding_flags(length(flags), hit)
}

#' Corresponding authors named in Web of Science RP fields
#'
#' An RP segment names one author, or several who share an address, before
#' the marker "(corresponding author)" ("(reprint author)" in older files)
#' and gives the address after it: `SURNAME, I (corresponding author),
#' ADDRESS`, with the names of one segment joined by `; `. A file writes
#' each segment on a line of its own; the native reader joins these lines
#' with `; `, and `bibliometrix::convert2df()` with a space, so that there
#' the next names follow the period that ends an address. The marker is
#' matched in any case, because convert2df() upper-cases RP. Text without
#' a marker names nobody.
#'
#' @param rp RP values, one per work (`NA` for none).
#' @return A list along `rp`: for each work a list with `name`, each name
#'   that RP gives, and `address`, the address of its segment (`NA` for
#'   none); both are empty where RP names nobody.
#' @noRd
.rp_entries <- function(rp) {
  marker <- "(?i)\\((?:corresponding|reprint) author\\)"
  lapply(as.character(rp), function(x) {
    if (is.na(x) || !grepl(marker, x, perl = TRUE)) {
      return(list(name = character(), address = character()))
    }
    n_marks <- length(gregexpr(marker, x, perl = TRUE)[[1]])
    pieces <- strsplit(x, marker, perl = TRUE)[[1]]
    pieces <- c(pieces, rep("", n_marks + 1L - length(pieces)))
    # piece k + 1 holds the address of segment k and, before the last
    # segment, the names of segment k + 1
    names <- character(n_marks)
    address <- character(n_marks)
    names[1L] <- pieces[1L]
    for (k in seq_len(n_marks)) {
      part <- if (k < n_marks) {
        .rp_split_piece(pieces[k + 1L])
      } else {
        list(address = pieces[k + 1L], names = "")
      }
      address[k] <- part$address
      if (k < n_marks) names[k + 1L] <- part$names
    }
    address <- .bx_text(sub("^[[:space:],]+", "", address))
    split <- strsplit(names, ";", fixed = TRUE)
    name <- .bx_text(unlist(split, use.names = FALSE))
    address <- rep(address, lengths(split))
    keep <- !is.na(name) &
      !duplicated(paste(.bx_key(name), .bx_key(address), sep = "\r"))
    list(name = name[keep], address = address[keep])
  })
}

#' Split the text between two RP markers into the address of the earlier
#' segment and the names of the later one
#'
#' The names follow the first `;` (segments joined by `; `) or, when the
#' text before it does not end with a period, the last period and space
#' after which a name with a comma follows (segments joined by a space).
#' @return A list: `address` and `names` (`;`-separated).
#' @noRd
.rp_split_piece <- function(piece) {
  parts <- strsplit(piece, ";", fixed = TRUE)[[1]]
  if (length(parts) == 0L) return(list(address = "", names = ""))
  head <- trimws(parts[1L])
  rest <- parts[-1L]
  breaks <- gregexpr("\\.[[:space:]]+", head)[[1]]
  if (!grepl("\\.$", head) && breaks[1L] > 0L) {
    tails <- substring(head, breaks + attr(breaks, "match.length"))
    lead <- which(grepl(",", tails, fixed = TRUE))
    if (length(lead) > 0L) {
      k <- lead[length(lead)]
      rest <- c(tails[k], rest)
      head <- substr(head, 1L, breaks[k])
    }
  }
  list(address = head, names = paste(rest, collapse = ";"))
}

#' Match keys of person names written in any common form
#'
#' "Surname, Given names", "Given names Surname" or "Surname Initials", as
#' `.bx_split_name()` reads them: the surname with the given names (`full`),
#' with their initials (`init`) and with the first initial (`first`).
#' @noRd
.person_name_keys <- function(x) {
  x <- .bx_item(x, brackets = FALSE)
  x[is.na(x)] <- ""
  parts <- vapply(x, .bx_split_name, character(2), USE.NAMES = FALSE)
  if (length(x) == 0L) parts <- matrix(character(), 2L, 0L)
  surname <- .bx_key(parts[1L, ])
  given <- parts[2L, ]
  initials <- .bx_initials(given, x)
  list(full = paste(surname, .bx_key(given)),
       init = paste(surname, initials),
       first = paste(surname, substr(initials, 1L, 1L)))
}

#' Which authors of a work do these names designate?
#'
#' Names are compared as the names in the brackets of C1 are, so "Jane
#' Doe" finds the author "Doe, J." (`.names_designate()`).
#'
#' @param authors The names of the work's authors, in position order.
#' @param names Names given by the source, such as its corresponding
#'   authors.
#' @return A logical vector along `authors`, as from `.names_designate()`.
#' @noRd
.authors_named <- function(authors, names) {
  names <- .bx_text(names)
  names <- unique(names[!is.na(names)])
  if (length(authors) == 0L || length(names) == 0L) {
    return(rep(FALSE, length(authors)))
  }
  .names_designate(.person_name_keys(authors), .person_name_keys(names))
}

#' Which authors of one work do names designate, telling namesakes apart
#' by address?
#'
#' A name designates the authors whose full name agrees with it, else
#' those whose surname and initials agree, else those whose surname and
#' first initial agree. When that gives several authors (namesakes such as
#' "Wang, Yan" and "Wang, Yu" for "Wang, Y"), the address that comes with
#' the name picks the one author who has it; failing that, the name leaves
#' them unknown rather than guessing.
#'
#' @param who Match keys (`full`, `init`, `first`) of the work's authors.
#' @param bk Match keys of the names, as from `.bx_bracket_keys()`.
#' @param who_addr `NULL`, or a list along the authors with the keys
#'   (`.bx_key()`) of their addresses.
#' @param bk_addr `NULL`, or the key of the address given with each name
#'   (`""` for none).
#' @return A logical vector along the authors: `TRUE` for an author that a
#'   name designates, `NA` for one that a name designates together with a
#'   namesake, else `FALSE`.
#' @noRd
.names_designate <- function(who, bk, who_addr = NULL, bk_addr = NULL) {
  n <- length(who$full)
  sure <- rep(FALSE, n)
  maybe <- rep(FALSE, n)
  for (q in seq_along(bk$full)) {
    for (level in c("full", "init", "first")) {
      cand <- which(who[[level]] == bk[[level]][q])
      if (length(cand) == 0L) next
      if (length(cand) > 1L && !is.null(bk_addr) && nzchar(bk_addr[q])) {
        at <- vapply(who_addr[cand], function(x) bk_addr[q] %in% x,
                     logical(1))
        if (sum(at) == 1L) cand <- cand[at]
      }
      if (length(cand) == 1L) sure[cand] <- TRUE else maybe[cand] <- TRUE
      break
    }
  }
  out <- sure
  out[maybe & !sure] <- NA
  out
}

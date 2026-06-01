# Shared record-matching internals for coverage auditing (Part A1) and
# reconciliation (Part A3). All matching flows through .sm_match_records() so
# that DOI normalisation, title fallback, and match provenance behave
# identically across functions.

#' Normalise a DOI for matching
#'
#' Lowercases, strips resolver prefixes and a `doi:` scheme (via
#' [.normalize_doi()]), then removes trailing punctuation. Returns
#' `NA_character_` for empty input. Vectorised.
#' @noRd
.norm_doi_match <- function(x) {
  d <- .normalize_doi(x)
  d <- sub("[[:punct:]]+$", "", d)
  ifelse(is.na(d) | !nzchar(d), NA_character_, d)
}

#' Normalise a title for fuzzy/exact matching
#'
#' Lowercases, replaces any run of non-alphanumeric characters with a single
#' space, and trims. Returns `NA_character_` for empty/`NA` input. Vectorised.
#' @noRd
.norm_title <- function(x) {
  if (length(x) == 0L) return(character())
  t <- tolower(as.character(x))
  t <- gsub("[^[:alnum:]]+", " ", t, perl = TRUE)
  t <- gsub("^ +| +$", "", t, perl = TRUE)
  ifelse(is.na(t) | !nzchar(t), NA_character_, t)
}

#' Coerce an object to a standard match frame
#'
#' @description
#' Produces a tibble with columns `id`, `doi`, `title`, `year` from either an
#' `sm_corpus` (uses the `works` table) or a data frame / tibble (a manual
#' tracker, ORCID export, repository dump, ...). Column names are matched
#' case-insensitively against common aliases. Always returns those four columns
#' with the correct types (a 0-row tibble for empty input).
#'
#' @param x An `sm_corpus` or data frame.
#' @param id_col Optional explicit id column name (for data frames).
#' @noRd
.as_match_frame <- function(x, id_col = NULL) {
  if (is_sm_corpus(x)) {
    w <- x$works
    return(tibble::tibble(
      id = as.character(w$work_id),
      doi = if ("doi" %in% names(w)) as.character(w$doi) else NA_character_,
      title = if ("title" %in% names(w)) as.character(w$title) else NA_character_,
      year = if ("year" %in% names(w)) suppressWarnings(as.integer(w$year)) else NA_integer_
    ))
  }

  df <- tibble::as_tibble(x)
  nms <- names(df)
  low <- tolower(nms)

  pick <- function(aliases) {
    hit <- which(low %in% aliases)
    if (length(hit) > 0L) nms[hit[1]] else NA_character_
  }

  doi_col <- if (!is.null(id_col) && FALSE) NA else pick(c("doi", "di"))
  title_col <- pick(c("title", "ti", "display_name"))
  year_col <- pick(c("year", "py", "publication_year"))
  the_id_col <- id_col %||% pick(c("id", "work_id", "reference_id", "ref_id"))

  n <- nrow(df)
  tibble::tibble(
    id = if (!is.na(the_id_col)) {
      as.character(df[[the_id_col]])
    } else {
      paste0("R", formatC(seq_len(n), width = 6, flag = "0"))
    },
    doi = if (!is.na(doi_col)) as.character(df[[doi_col]]) else rep(NA_character_, n),
    title = if (!is.na(title_col)) as.character(df[[title_col]]) else rep(NA_character_, n),
    year = if (!is.na(year_col)) suppressWarnings(as.integer(df[[year_col]])) else rep(NA_integer_, n)
  )
}

#' Match records between two frames by DOI, with title fallback
#'
#' @description
#' Core matching engine. Given two match frames (`a`, `b`, each from
#' [.as_match_frame()]), returns a one-row-per-matched-pair tibble with columns
#' `a_id`, `b_id`, `match_type` (`"doi"` or `"title"`), and `match_score`
#' (1 for DOI matches; the Jaro-Winkler similarity in `[0, 1]` for title
#' matches). Each `a` row matches at most one `b` row (the best available),
#' and each `b` row is claimed at most once.
#'
#' @param a,b Match frames (tibbles with `id`, `doi`, `title`).
#' @param match One of `"doi"`, `"title"`, `"doi_then_title"`.
#' @param threshold Minimum title similarity (`[0, 1]`) to accept a title match.
#' @noRd
.sm_match_records <- function(a, b,
                              match = c("doi_then_title", "doi", "title"),
                              threshold = 0.9) {
  match <- rlang::arg_match(match)

  empty_pairs <- tibble::tibble(
    a_id = character(), b_id = character(),
    match_type = character(), match_score = double()
  )
  if (nrow(a) == 0L || nrow(b) == 0L) return(empty_pairs)

  pairs <- list()
  claimed_b <- character()
  matched_a <- character()

  # ---- DOI exact matching ----
  if (match %in% c("doi", "doi_then_title")) {
    a_doi <- .norm_doi_match(a$doi)
    b_doi <- .norm_doi_match(b$doi)
    # index of the first b row for each distinct, non-missing DOI
    first_b <- !duplicated(b_doi) & !is.na(b_doi)
    b_lookup_doi <- b_doi[first_b]
    b_lookup_idx <- which(first_b)
    m <- match(a_doi, b_lookup_doi)
    for (i in seq_len(nrow(a))) {
      if (is.na(a_doi[i]) || is.na(m[i])) next
      j <- b_lookup_idx[m[i]]
      if (b$id[j] %in% claimed_b) next
      pairs[[length(pairs) + 1L]] <- list(
        a_id = a$id[i], b_id = b$id[j], match_type = "doi", match_score = 1
      )
      claimed_b <- c(claimed_b, b$id[j])
      matched_a <- c(matched_a, a$id[i])
    }
  }

  # ---- Title fallback ----
  if (match %in% c("title", "doi_then_title")) {
    a_unmatched <- which(!(a$id %in% matched_a))
    b_avail <- which(!(b$id %in% claimed_b))
    if (length(a_unmatched) > 0L && length(b_avail) > 0L) {
      a_t <- .norm_title(a$title[a_unmatched])
      b_t <- .norm_title(b$title[b_avail])

      use_sd <- rlang::is_installed("stringdist")
      for (k in seq_along(a_unmatched)) {
        ta <- a_t[k]
        if (is.na(ta)) next
        avail_local <- which(!(b$id[b_avail] %in% claimed_b) & !is.na(b_t))
        if (length(avail_local) == 0L) next
        cand <- b_t[avail_local]
        if (use_sd) {
          sims <- stringdist::stringsim(ta, cand, method = "jw", p = 0.1)
        } else {
          # base-R fallback: normalised exact match only
          sims <- as.numeric(cand == ta)
        }
        best <- which.max(sims)
        if (length(best) == 0L || sims[best] < threshold) next
        bj <- b_avail[avail_local[best]]
        pairs[[length(pairs) + 1L]] <- list(
          a_id = a$id[a_unmatched[k]], b_id = b$id[bj],
          match_type = "title", match_score = round(sims[best], 4)
        )
        claimed_b <- c(claimed_b, b$id[bj])
      }
    }
  }

  if (length(pairs) == 0L) return(empty_pairs)
  tibble::tibble(
    a_id = vapply(pairs, function(p) p$a_id, character(1)),
    b_id = vapply(pairs, function(p) p$b_id, character(1)),
    match_type = vapply(pairs, function(p) p$match_type, character(1)),
    match_score = vapply(pairs, function(p) p$match_score, double(1))
  )
}

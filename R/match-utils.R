# Shared record-matching internals for coverage auditing (Part A1) and
# reconciliation (Part A3). All matching flows through .sm_match_records()
# and .sm_match_each() so that DOI normalisation, title fallback, and match
# provenance behave identically across functions. Both work on row
# positions, so missing or repeated identifiers cannot mix up records.

#' Normalise a DOI for matching
#'
#' Lowercases, strips resolver prefixes and a `doi:` scheme (via
#' `.normalize_doi()`), then removes trailing punctuation. Returns
#' `NA_character_` for empty input. Vectorised.
#' @noRd
.norm_doi_match <- function(x) {
  d <- .normalize_doi(x)
  d <- sub("[[:punct:]]+$", "", d)
  ifelse(is.na(d) | !nzchar(d), NA_character_, d)
}

#' Normalise a title for fuzzy/exact matching
#'
#' Lowercases, replaces any run of characters that are neither letters,
#' digits nor combining marks (of any script) with a single space, and trims.
#' The Unicode properties keep umlauts, accented letters and non-Latin
#' scripts, which PCRE's POSIX classes would drop. Returns `NA_character_`
#' for empty/`NA` input. Vectorised.
#' @noRd
.norm_title <- function(x) {
  if (length(x) == 0L) return(character())
  t <- tolower(as.character(x))
  t <- gsub("[^\\p{L}\\p{N}\\p{M}]+", " ", t, perl = TRUE)
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
#' with the correct types (a 0-row tibble for empty input), one row per input
#' row in input order.
#'
#' For a data frame, `id` comes from the first identifier column whose values
#' are unique and never missing (see `.match_frame_ids()`); otherwise rows
#' get generated ids `R000001`, `R000002`, ...
#'
#' @param x An `sm_corpus` or data frame.
#' @param id_col Optional explicit id column name (for data frames).
#' @param what Name of `x` in messages.
#' @param call Caller environment for messages.
#' @noRd
.as_match_frame <- function(x, id_col = NULL, what = "reference",
                            call = rlang::caller_env()) {
  if (is_sm_corpus(x)) {
    w <- x$works
    return(tibble::tibble(
      id = as.character(w$work_id),
      doi = if ("doi" %in% names(w)) as.character(w$doi) else NA_character_,
      title = if ("title" %in% names(w)) as.character(w$title) else NA_character_,
      year = if ("year" %in% names(w)) .match_year(w$year) else NA_integer_
    ))
  }

  wos <- inherits(x, "bibliometrixDB")
  df <- tibble::as_tibble(x)
  nms <- names(df)
  low <- tolower(nms)

  pick <- function(aliases) {
    hit <- which(low %in% aliases)
    if (length(hit) > 0L) nms[hit[1]] else NA_character_
  }

  doi_col <- pick(c("doi", "di"))
  title_col <- pick(c("title", "ti", "display_name"))
  year_col <- pick(c("year", "py", "publication_year"))

  n <- nrow(df)
  tibble::tibble(
    id = .match_frame_ids(df, id_col, wos = wos, what = what, call = call),
    doi = if (!is.na(doi_col)) as.character(df[[doi_col]]) else rep(NA_character_, n),
    title = if (!is.na(title_col)) as.character(df[[title_col]]) else rep(NA_character_, n),
    year = if (!is.na(year_col)) {
      .match_year(df[[year_col]])
    } else {
      rep(NA_integer_, n)
    }
  )
}

#' Publication years of a match frame
#'
#' Whole years from numbers or text, and the calendar year of a `Date` or
#' date-time. A value outside 1000-2999, such as a day count or epoch
#' seconds, counts as missing, so the year rule of the title fallback skips
#' it instead of ruling out every candidate.
#' @noRd
.match_year <- function(x) {
  if (inherits(x, c("Date", "POSIXt"))) {
    x <- format(x, "%Y")
  } else if (is.factor(x)) {
    x <- as.character(x)
  }
  year <- suppressWarnings(as.integer(x))
  year[!is.na(year) & (year < 1000L | year > 2999L)] <- NA_integer_
  year
}

#' Record identifiers of a data frame to match
#'
#' Candidates, in order: `id_col` when given; else the columns named (in any
#' case) `ut` (Web of Science accession numbers), `id`, `work_id`,
#' `reference_id` and `ref_id`. A column named exactly `ID` is skipped in a
#' frame with Web of Science field tags (or of class `bibliometrixDB`), where
#' it holds the Keywords Plus. The first candidate whose values are unique and
#' never missing or blank gives the ids; a candidate without any value is
#' passed over. When no candidate qualifies, rows get generated ids
#' `R000001`, ..., with a warning if a candidate was rejected.
#' @noRd
.match_frame_ids <- function(df, id_col, wos, what, call) {
  nms <- names(df)
  if (is.null(id_col)) {
    low <- tolower(nms)
    aliases <- c("ut", "id", "work_id", "reference_id", "ref_id")
    cand <- unlist(lapply(aliases, function(a) nms[low == a]),
                   use.names = FALSE)
    if (wos || any(.wos_field_tags() %in% nms)) {
      cand <- setdiff(cand, "ID")
    }
  } else {
    cand <- intersect(id_col, nms)
  }

  rejected <- character()
  for (col in cand) {
    v <- as.character(df[[col]])
    blank <- is.na(v) | !nzchar(trimws(v))
    if (all(blank)) next
    if (!any(blank) && anyDuplicated(v) == 0L) return(v)
    rejected <- c(rejected, col)
  }

  if (length(rejected) > 0L) {
    cli::cli_warn(c(
      "!" = "{.field {rejected}} of {.arg {what}} can't identify its rows:
             an identifier must be unique and never missing.",
      "i" = "Rows are identified by their position instead ({.val R000001}
             for the first row)."
    ), class = "scimapR_match_ids_invalid", call = call)
  }
  paste0("R", formatC(seq_len(nrow(df)), width = 6, flag = "0"))
}

#' Web of Science field tags that mark a tagged data frame
#' @noRd
.wos_field_tags <- function() {
  c("UT", "DI", "TI", "PY", "SO", "AU", "AF", "DE", "CR", "C1", "DT", "SR")
}

#' Which rows of `b` may pair with one record by title
#'
#' Rows with a title, published at most one year apart from `year` when both
#' years are known, and without a DOI that differs from `doi` when both DOIs
#' are known (normalised DOIs).
#' @noRd
.title_eligible <- function(year, doi, b_year, b_doi, b_title) {
  ok <- !is.na(b_title)
  if (!is.na(year)) ok <- ok & (is.na(b_year) | abs(b_year - year) <= 1L)
  if (!is.na(doi)) ok <- ok & (is.na(b_doi) | b_doi == doi)
  ok
}

#' Title similarities of one normalised title against candidates
#'
#' Jaro-Winkler similarity with stringdist; without it, normalised exact
#' matching (1 or 0).
#' @noRd
.title_sims <- function(title, cand, use_sd) {
  if (use_sd) {
    stringdist::stringsim(title, cand, method = "jw", p = 0.1)
  } else {
    as.numeric(cand == title)
  }
}

#' Match records between two frames by DOI, with title fallback
#'
#' @description
#' Core one-to-one matching engine. Given two match frames (`a`, `b`, each
#' from `.as_match_frame()`), returns a one-row-per-matched-pair tibble with
#' columns `a_id`, `b_id`, `match_type` (`"doi"` or `"title"`),
#' `match_score` (1 for DOI matches; the Jaro-Winkler similarity in `[0, 1]`
#' for title matches), and the row positions `a_row` and `b_row`. Each `a`
#' row matches at most one `b` row (the best available), and each `b` row is
#' claimed at most once: rows sharing a DOI pair in order. The title fallback
#' only pairs records published at most one year apart and never two
#' records with different DOIs.
#'
#' @param a,b Match frames (tibbles with `id`, `doi`, `title`, `year`).
#' @param match One of `"doi"`, `"title"`, `"doi_then_title"`.
#' @param threshold Minimum title similarity (`[0, 1]`) to accept a title match.
#' @noRd
.sm_match_records <- function(a, b,
                              match = c("doi_then_title", "doi", "title"),
                              threshold = 0.9) {
  match <- rlang::arg_match(match)

  empty_pairs <- tibble::tibble(
    a_id = character(), b_id = character(),
    match_type = character(), match_score = double(),
    a_row = integer(), b_row = integer()
  )
  if (nrow(a) == 0L || nrow(b) == 0L) return(empty_pairs)

  a_doi <- .norm_doi_match(a$doi)
  b_doi <- .norm_doi_match(b$doi)
  partner <- rep(NA_integer_, nrow(a))
  type <- rep(NA_character_, nrow(a))
  score <- rep(NA_real_, nrow(a))
  claimed <- rep(FALSE, nrow(b))

  # ---- DOI exact matching: the rows of one DOI pair in order ----
  if (match %in% c("doi", "doi_then_title")) {
    dois <- unique(b_doi[!is.na(b_doi)])
    b_rows <- split(seq_len(nrow(b)), factor(b_doi, levels = dois))
    taken <- integer(length(dois))
    g <- match(a_doi, dois)
    for (i in which(!is.na(g))) {
      k <- taken[g[i]] + 1L
      if (k > length(b_rows[[g[i]]])) next
      taken[g[i]] <- k
      j <- b_rows[[g[i]]][k]
      partner[i] <- j
      type[i] <- "doi"
      score[i] <- 1
      claimed[j] <- TRUE
    }
  }

  # ---- Title fallback ----
  if (match %in% c("title", "doi_then_title")) {
    a_t <- .norm_title(a$title)
    b_t <- .norm_title(b$title)
    use_sd <- rlang::is_installed("stringdist")
    for (i in which(is.na(partner) & !is.na(a_t))) {
      cand <- which(!claimed & .title_eligible(a$year[i], a_doi[i], b$year,
                                               b_doi, b_t))
      if (length(cand) == 0L) next
      sims <- .title_sims(a_t[i], b_t[cand], use_sd)
      best <- which.max(sims)
      if (length(best) == 0L || sims[best] < threshold) next
      j <- cand[best]
      partner[i] <- j
      type[i] <- "title"
      score[i] <- round(sims[best], 4)
      claimed[j] <- TRUE
    }
  }

  rows <- which(!is.na(partner))
  if (length(rows) == 0L) return(empty_pairs)
  # DOI pairs first, then title pairs, each in the order of `a`
  rows <- rows[order(type[rows] == "title", rows)]
  tibble::tibble(
    a_id = a$id[rows],
    b_id = b$id[partner[rows]],
    match_type = type[rows],
    match_score = score[rows],
    a_row = rows,
    b_row = partner[rows]
  )
}

#' Look up each row of one frame in another, independently
#'
#' @description
#' Unlike `.sm_match_records()`, a row of `y` can be found by any number of
#' rows of `x`: each `x` row is matched on its own, by DOI and then (for the
#' title strategies) by the most similar eligible title, under the same
#' rules. Coverage recall uses it, so that an item reported in several
#' reference rows (by two units, say) counts as found for each of them.
#'
#' @param x,y Match frames.
#' @inheritParams .sm_match_records
#' @return A tibble with one row per `x` row: `matched` (logical), `y_row`
#'   (the matching `y` row, `NA` when none), `match_type` (`"doi"`,
#'   `"title"` or `"none"`) and `match_score`.
#' @noRd
.sm_match_each <- function(x, y,
                           match = c("doi_then_title", "doi", "title"),
                           threshold = 0.9) {
  match <- rlang::arg_match(match)
  n <- nrow(x)
  y_row <- rep(NA_integer_, n)
  type <- rep("none", n)
  score <- rep(NA_real_, n)

  if (n > 0L && nrow(y) > 0L) {
    x_doi <- .norm_doi_match(x$doi)
    y_doi <- .norm_doi_match(y$doi)

    if (match %in% c("doi", "doi_then_title")) {
      m <- match(x_doi, y_doi, incomparables = NA)
      hit <- !is.na(m)
      y_row[hit] <- m[hit]
      type[hit] <- "doi"
      score[hit] <- 1
    }

    if (match %in% c("title", "doi_then_title")) {
      x_t <- .norm_title(x$title)
      y_t <- .norm_title(y$title)
      use_sd <- rlang::is_installed("stringdist")
      for (i in which(is.na(y_row) & !is.na(x_t))) {
        cand <- which(.title_eligible(x$year[i], x_doi[i], y$year, y_doi, y_t))
        if (length(cand) == 0L) next
        sims <- .title_sims(x_t[i], y_t[cand], use_sd)
        best <- which.max(sims)
        if (length(best) == 0L || sims[best] < threshold) next
        y_row[i] <- cand[best]
        type[i] <- "title"
        score[i] <- round(sims[best], 4)
      }
    }
  }

  tibble::tibble(
    matched = !is.na(y_row),
    y_row = y_row,
    match_type = type,
    match_score = score
  )
}

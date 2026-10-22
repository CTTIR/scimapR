# Internal ID generation helpers

.generate_work_id <- function(n = 1L) {
  paste0("W", formatC(seq_len(n), width = 9, flag = "0"))
}

.generate_author_id <- function(n = 1L) {
  paste0("A", formatC(seq_len(n), width = 9, flag = "0"))
}

.generate_institution_id <- function(n = 1L) {
  paste0("I", formatC(seq_len(n), width = 9, flag = "0"))
}

.generate_source_id <- function(n = 1L) {
  paste0("S", formatC(seq_len(n), width = 9, flag = "0"))
}

.next_ids <- function(prefix, n, taken) {
  nums <- as.numeric(sub(paste0("^", prefix), "",
                         taken[grepl(paste0("^", prefix, "[0-9]+$"), taken)]))
  start <- max(c(0, nums))
  ids <- sprintf("%s%09.0f", prefix, start + seq_len(n))
  if (any(!is.finite(start + seq_len(n))) || anyDuplicated(ids) ||
        any(ids %in% taken)) {
    cli::cli_abort("Cannot allocate distinct IDs after {.val {start}}.",
                   class = "scimapR_id_range_exhausted")
  }
  ids
}

.rekey_map <- function(ids2, ids1, prefix, keep = character(),
                       taken = character()) {
  shared <- setdiff(intersect(ids2[!is.na(ids2)], ids1), keep)
  stats::setNames(.next_ids(prefix, length(shared), c(ids1, ids2, taken)),
                  shared)
}

.apply_id_map <- function(x, map) {
  pos <- match(x, names(map))
  hit <- !is.na(x) & !is.na(pos)
  x[hit] <- unname(map[pos[hit]])
  x
}

.complete_key_rows <- function(key) {
  Reduce(`&`, lapply(key, function(x) {
    ok <- !is.na(x)
    if (is.character(x)) ok <- ok & nzchar(trimws(x))
    ok
  }), init = rep(TRUE, nrow(key)))
}

.make_work_id <- function(prefix = "W", existing_ids = character()) {
  max_num <- 0L
  if (length(existing_ids) > 0) {
    nums <- suppressWarnings(
      as.integer(sub("^[A-Z]", "", existing_ids))
    )
    nums <- nums[!is.na(nums)]
    if (length(nums) > 0) max_num <- max(nums)
  }
  paste0(prefix, formatC(max_num + 1L, width = 9, flag = "0"))
}

.normalize_doi <- function(doi) {
  if (is.null(doi)) return(NA_character_)
  doi <- trimws(doi)
  doi <- sub("^https?://doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- sub("^https?://dx\\.doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- sub("^doi:\\s*", "", doi, ignore.case = TRUE)
  ifelse(nzchar(doi), tolower(doi), NA_character_)
}

#' ORCID iDs without the `https://orcid.org/` prefix, in upper case (the
#' check character `X`); `NA` for missing or empty values and for `NULL`
#' @noRd
.normalize_orcid <- function(orcid) {
  if (is.null(orcid)) return(NA_character_)
  x <- trimws(as.character(unlist(orcid, use.names = FALSE)))
  x <- sub("^https?://(www\\.)?orcid\\.org/", "", x, ignore.case = TRUE)
  x <- toupper(x)
  x[!is.na(x) & !nzchar(x)] <- NA_character_
  x
}

#' First DOI of each cited-reference string; NA where there is none
#' @noRd
.cr_doi <- function(refs) {
  vapply(.cr_dois(refs), function(x) {
    if (length(x) > 0L) x[1] else NA_character_
  }, character(1))
}

#' All DOIs in plain or bracketed Web of Science DOI fields
#' @noRd
.cr_dois <- function(refs) {
  refs[is.na(refs)] <- ""
  pattern <- "(?i)\\bDOI\\s+(?:\\[[^]]*\\]|10\\.[^,;\\s\\]]+)"
  parts <- regmatches(refs, gregexpr(pattern, refs, perl = TRUE))
  lapply(parts, function(x) {
    hits <- regmatches(x, gregexpr("10\\.[^,;\\s\\]]+", x, perl = TRUE))
    values <- as.character(unlist(hits, use.names = FALSE))
    if (length(values) == 0L) return(character())
    unique(.normalize_doi(sub("\\.+$", "", values)))
  })
}

#' OpenAlex work ids shortened to the `W` number; `NA` when not one
#' @noRd
.openalex_short_id <- function(x) {
  x <- trimws(as.character(x))
  shape <- "^(?:https?://(?:www\\.)?openalex\\.org/(?:works/)?)?(W[0-9]+)$"
  ok <- !is.na(x) & grepl(shape, x, perl = TRUE, ignore.case = TRUE)
  out <- rep(NA_character_, length(x))
  out[ok] <- toupper(sub(shape, "\\1", x[ok], perl = TRUE, ignore.case = TRUE))
  out
}

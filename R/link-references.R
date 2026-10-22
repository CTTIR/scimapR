#' Link cited references to works in a corpus
#'
#' @description
#' Resolves cited DOIs and OpenAlex identifiers against the works in the
#' corpus. Use this for corpora built from tables or saved before references
#' were linked automatically. No network request is made.
#'
#' @param corpus An [sm_corpus] object.
#' @param by Identifiers to match, in priority order: `"doi"` and
#'   `"openalex_id"` by default.
#' @param verbose Report the numbers of linked and unresolved references.
#' @param call Caller environment for error reporting.
#'
#' @details
#' Links to existing corpus works are preserved. Missing or dangling links
#' are resolved by a normalised DOI in `cited_doi` or a Web of Science DOI
#' field in `cited_raw`, including bracketed DOI lists. OpenAlex matching
#' accepts a whole short work id or its URL in `cited_raw`. A match must
#' identify exactly one work and must not point to the citing work itself.
#' The first identifier type in `by` giving a unique, non-self match wins.
#' A dangling link without a match is retained. The source identifiers and
#' provenance are unchanged. Locked corpora must first be unlocked.
#'
#' Readers and fetchers that build references, [sm_bind_corpora()] and
#' [sm_dedupe()] link automatically. [sm_corpus()], [sm_corpus_from_tables()],
#' `new_sm_corpus()`, [sm_materialise()], subsetting and [sm_example_corpus()]
#' take the supplied links as given.
#'
#' @return The corpus with `references$cited_work_id` filled where possible.
#' @family corpus
#' @export
#' @examples
#' corpus <- readRDS(sm_example_files("example_realuse_corpus.rds"))
#' linked <- sm_link_references(corpus)
#' sum(linked$references$cited_work_id %in% linked$works$work_id)
sm_link_references <- function(corpus, by = c("doi", "openalex_id"),
                               verbose = TRUE, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_corpus_unlocked(corpus, call = call)
  by <- rlang::arg_match(by, multiple = TRUE, error_call = call)
  .check_flag(verbose, call = call)
  refs <- .link_references(corpus$references, corpus$works, by = by)
  counts <- attr(refs, "link_counts")
  if (verbose && length(counts) > 0L) {
    cli::cli_inform(c(
      "i" = "{counts[['n_linked']]} of {counts[['n_references']]} references
             point to corpus works ({counts[['n_new']]} newly linked).",
      "i" = "{counts[['n_ambiguous']]} ambiguous matches and
             {counts[['n_self']]} self-matches remain unresolved."
    ), class = "scimapR_references_linked")
  }
  corpus$references <- refs
  corpus
}

.link_references <- function(references, works, by = c("doi", "openalex_id")) {
  refs <- tibble::as_tibble(references)
  n <- nrow(refs)
  if (!"cited_work_id" %in% names(refs)) {
    refs$cited_work_id <- rep(NA_character_, n)
  }
  before <- refs$cited_work_id %in% works$work_id
  unresolved <- !before
  ambiguous <- self <- rep(FALSE, n)
  raw <- refs[["cited_raw"]] %||% rep(NA_character_, n)
  for (kind in by) {
    if (!any(unresolved)) break
    if (kind == "doi") {
      extra <- .cr_dois(raw)
      candidates <- tibble::tibble(
        row = c(seq_len(n), rep(seq_len(n), lengths(extra))),
        key = c(.normalize_doi(refs[["cited_doi"]] %||% rep(NA_character_, n)),
                as.character(unlist(extra, use.names = FALSE)))
      )
      keys <- .normalize_doi(
        works[["doi"]] %||% rep(NA_character_, nrow(works))
      )
    } else {
      candidates <- tibble::tibble(row = seq_len(n),
                                   key = .openalex_short_id(raw))
      keys <- .openalex_short_id(
        works[["openalex_id"]] %||% rep(NA_character_, nrow(works))
      )
    }
    candidates <- candidates[unresolved[candidates$row] &
                               !is.na(candidates$key), , drop = FALSE]
    targets <- tibble::tibble(key = keys, target = works$work_id)
    targets <- targets[!is.na(targets$key) & !is.na(targets$target), ]
    matches <- dplyr::inner_join(candidates, targets, by = "key",
                                 na_matches = "never",
                                 relationship = "many-to-many") |>
      dplyr::group_by(.data$row) |>
      dplyr::summarise(n = dplyr::n_distinct(.data$target),
                       target = dplyr::first(.data$target), .groups = "drop")
    ambiguous[matches$row[matches$n > 1L]] <- TRUE
    only <- matches[matches$n == 1L, ]
    is_self <- only$target == refs$work_id[only$row]
    is_self[is.na(is_self)] <- FALSE
    self[only$row[is_self]] <- TRUE
    hits <- only[!is_self, ]
    refs$cited_work_id[hits$row] <- hits$target
    unresolved[hits$row] <- FALSE
  }
  linked <- refs$cited_work_id %in% works$work_id
  attr(refs, "link_counts") <- c(
    n_references = as.integer(n), n_linked = as.integer(sum(linked)),
    n_new = as.integer(sum(linked & !before)),
    n_ambiguous = as.integer(sum(ambiguous & unresolved)),
    n_self = as.integer(sum(self & unresolved))
  )
  refs
}

.reference_keys <- function(references, works) {
  n <- nrow(references)
  id <- references[["cited_work_id"]] %||% rep(NA_character_, n)
  doi <- .normalize_doi(references[["cited_doi"]] %||% rep(NA_character_, n))
  raw <- references[["cited_raw"]] %||% rep(NA_character_, n)
  oa <- .openalex_short_id(raw)
  raw_key <- stringr::str_to_upper(stringr::str_squish(raw), locale = "en")
  raw_key <- sub("\\.+$", "", raw_key)
  raw_key[!is.na(raw_key) & !nzchar(raw_key)] <- NA_character_
  id[!is.na(id) & !nzchar(trimws(id))] <- NA_character_
  key <- name <- rep(NA_character_, n)
  values <- list(id = id, doi = doi, openalex = oa, text = raw_key)
  for (kind in names(values)) {
    use <- is.na(key) & !is.na(values[[kind]])
    key[use] <- paste0(kind, ":", values[[kind]][use])
    name[use] <- if (kind == "text") raw[use] else values[[kind]][use]
  }
  in_corpus <- id %in% works$work_id
  at <- match(references$work_id, works$work_id)
  own_doi <- .normalize_doi(works[["doi"]] %||% rep(NA_character_, nrow(works)))
  own_oa <- .openalex_short_id(
    works[["openalex_id"]] %||% rep(NA_character_, nrow(works))
  )
  self <- key == paste0("id:", references$work_id) |
    key == paste0("doi:", own_doi[at]) |
    key == paste0("openalex:", own_oa[at])
  self[is.na(self)] <- FALSE
  tibble::tibble(key = key, name = name, in_corpus = in_corpus,
                 .work_id = dplyr::if_else(in_corpus, id, NA_character_),
                 .self = self)
}

.warn_references_unlinked <- function(message, detail = NULL,
                                      call = rlang::caller_env()) {
  bullets <- c("!" = .sm_cli_escape(message))
  if (!is.null(detail)) bullets <- c(bullets, "i" = .sm_cli_escape(detail))
  cli::cli_warn(c(
    bullets,
    "i" = "Link references with {.fn sm_link_references}; add references
           with a reader, a fetcher or {.fn sm_enrich_opencitations}."
  ), class = "scimapR_references_unlinked", call = call)
}

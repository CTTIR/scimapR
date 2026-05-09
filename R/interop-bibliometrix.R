#' Convert sm_corpus to bibliometrix format
#'
#' @description
#' Converts an `sm_corpus` to the data frame format used by
#' `bibliometrix::biblioAnalysis()`. This enables using bibliometrix's
#' analysis functions on corpora built with scimapR.
#'
#' @param corpus An `sm_corpus` object.
#' @param ... Additional arguments (currently unused).
#'
#' @return A data frame with class `c("bibliometrixDB", "data.frame")`.
#'
#' @references
#' Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
#' comprehensive science mapping analysis. *Journal of Informetrics*,
#' 11(4), 959-975. \doi{10.1016/j.joi.2017.08.007}
#'
#' @family interop
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 10, n_authors = 5)
#' \donttest{
#' if (requireNamespace("bibliometrix", quietly = TRUE)) {
#'   M <- sm_to_bibliometrix(corpus)
#'   class(M)
#' }
#' }
sm_to_bibliometrix <- function(corpus, ...) {
  .check_sm_corpus(corpus)

  works <- corpus$works
  authorships <- corpus$authorships
  authors <- corpus$authors

  au_by_work <- dplyr::left_join(
    authorships,
    dplyr::select(authors, "author_id", "display_name"),
    by = "author_id"
  ) %>%
    dplyr::group_by(.data$work_id) %>%
    dplyr::summarise(
      AU = paste(.data$display_name, collapse = ";"),
      AU_CO = paste(stats::na.omit(.data$country_code), collapse = ";"),
      .groups = "drop"
    )

  M <- dplyr::left_join(works, au_by_work, by = "work_id")

  refs_by_work <- corpus$references %>%
    dplyr::group_by(.data$work_id) %>%
    dplyr::summarise(
      CR = paste(stats::na.omit(.data$cited_raw), collapse = ";"),
      NR = dplyr::n(),
      .groups = "drop"
    )

  M <- dplyr::left_join(M, refs_by_work, by = "work_id")

  concepts_by_work <- corpus$concepts %>%
    dplyr::filter(.data$vocabulary %in% c("keywords-author", "openalex")) %>%
    dplyr::group_by(.data$work_id) %>%
    dplyr::summarise(
      DE = paste(.data$concept_name, collapse = ";"),
      .groups = "drop"
    )

  M <- dplyr::left_join(M, concepts_by_work, by = "work_id")

  src_info <- dplyr::select(corpus$sources, "source_id",
                             SO = "display_name",
                             SO_ISSN = "issn_l")

  M <- dplyr::left_join(M, src_info, by = "source_id")

  M <- dplyr::rename(M,
    DI = "doi",
    TI = "title",
    AB = "abstract",
    PY = "year",
    DT = "type",
    TC = "cited_by_count",
    LA = "language",
    PM = "pmid"
  )

  M$DB <- "scimapR"
  M$SR <- paste(
    ifelse(is.na(M$AU), "Unknown", sub(";.*", "", M$AU)),
    M$PY,
    M$SO,
    sep = ", "
  )

  M <- as.data.frame(M)
  class(M) <- c("bibliometrixDB", "data.frame")
  M
}

#' Convert bibliometrix data frame to sm_corpus
#'
#' @rdname as_sm_corpus
#' @param source_label Label for provenance tracking.
#' @export
as_sm_corpus.bibliometrixDB <- function(x, source_label = "bibliometrix-import",
                                         ...) {
  .convert_bibliometrix_df(x, source_label = source_label)
}

.convert_bibliometrix_df <- function(x, source_label = "bibliometrix-import") {
  n <- nrow(x)
  if (n == 0) {
    return(new_sm_corpus(
      works = .empty_works(),
      authors = .empty_authors(),
      authorships = .empty_authorships()
    ))
  }

  work_ids <- .generate_work_id(n)

  .col_or_na <- function(df, col) {
    if (col %in% names(df)) df[[col]] else rep(NA_character_, nrow(df))
  }

  works <- tibble::tibble(
    work_id = work_ids,
    doi = .normalize_doi(.col_or_na(x, "DI")),
    title = .col_or_na(x, "TI"),
    abstract = .col_or_na(x, "AB"),
    year = if ("PY" %in% names(x)) as.integer(x$PY) else NA_integer_,
    type = .col_or_na(x, "DT"),
    source_id = NA_character_,
    cited_by_count = if ("TC" %in% names(x)) as.integer(x$TC) else NA_integer_,
    oa_status = NA_character_,
    language = .col_or_na(x, "LA"),
    pmid = .col_or_na(x, "PM"),
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  au_col <- .col_or_na(x, "AU")
  all_authors <- unique(unlist(strsplit(au_col[!is.na(au_col)], ";")))
  all_authors <- trimws(all_authors)
  all_authors <- all_authors[nzchar(all_authors)]

  if (length(all_authors) > 0) {
    author_ids <- .generate_author_id(length(all_authors))
    authors <- tibble::tibble(
      author_id = author_ids,
      orcid = NA_character_,
      display_name = all_authors,
      display_name_alternatives = lapply(seq_along(all_authors), function(i) character()),
      inferred_gender = NA_character_,
      gender_confidence = NA_real_,
      gender_method = NA_character_
    )
    au_lookup <- stats::setNames(author_ids, all_authors)

    authorships_list <- lapply(seq_len(n), function(i) {
      au <- au_col[i]
      if (is.na(au)) return(.empty_authorships())
      au_split <- trimws(strsplit(au, ";")[[1]])
      au_split <- au_split[nzchar(au_split)]
      if (length(au_split) == 0) return(.empty_authorships())
      tibble::tibble(
        work_id = work_ids[i],
        author_id = unname(au_lookup[au_split]),
        position = seq_along(au_split),
        is_corresponding = c(TRUE, rep(FALSE, length(au_split) - 1)),
        institution_id = NA_character_,
        raw_affiliation = NA_character_,
        country_code = NA_character_
      )
    })
    authorships <- dplyr::bind_rows(authorships_list)
  } else {
    authors <- .empty_authors()
    authorships <- .empty_authorships()
  }

  provenance <- tibble::tibble(
    work_id = work_ids,
    source = source_label,
    source_id_external = NA_character_,
    fetch_date = Sys.time(),
    query = NA_character_,
    engine = "bibliometrix",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  new_sm_corpus(
    works = works,
    authors = authors,
    authorships = authorships,
    provenance = provenance
  )
}

#' Summary statistics for works
#'
#' @description
#' Computes aggregate summary statistics for all works in the corpus.
#'
#' @param corpus An [sm_corpus] object.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row containing summary statistics:
#'   `n_works`, `year_min`, `year_max`, `year_span`, `mean_citations`,
#'   `median_citations`, `total_citations`, `n_types` (unique document types),
#'   `n_sources` (unique journals/sources), `n_oa` (open access works),
#'   `pct_oa`, `n_retracted`, `n_languages`.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_summary_works(corpus)
sm_summary_works <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  works <- corpus$works

  if (nrow(works) == 0L) {
    return(tibble::tibble(
      n_works = 0L, year_min = NA_integer_, year_max = NA_integer_,
      year_span = NA_integer_, mean_citations = NA_real_,
      median_citations = NA_real_, total_citations = 0L,
      n_types = 0L, n_sources = 0L, n_oa = 0L, pct_oa = NA_real_,
      n_retracted = 0L, n_languages = 0L
    ))
  }

  cites <- works$cited_by_count
  cites <- cites[!is.na(cites)]
  years <- works$year[!is.na(works$year)]

  n_oa <- if ("oa_status" %in% names(works)) {
    sum(!is.na(works$oa_status) & works$oa_status != "closed")
  } else {
    NA_integer_
  }

  n_retracted <- if ("is_retracted" %in% names(works)) {
    sum(works$is_retracted, na.rm = TRUE)
  } else {
    NA_integer_
  }

  tibble::tibble(
    n_works         = nrow(works),
    year_min        = if (length(years) > 0) min(years) else NA_integer_,
    year_max        = if (length(years) > 0) max(years) else NA_integer_,
    year_span       = if (length(years) > 0) {
      max(years) - min(years) + 1L
    } else NA_integer_,
    mean_citations   = if (length(cites) > 0) {
      round(mean(cites), 2)
    } else NA_real_,
    median_citations = if (length(cites) > 0) {
      stats::median(cites)
    } else NA_real_,
    total_citations  = sum(cites),
    n_types         = dplyr::n_distinct(works$type, na.rm = TRUE),
    n_sources       = dplyr::n_distinct(works$source_id, na.rm = TRUE),
    n_oa            = as.integer(n_oa),
    pct_oa          = if (!is.na(n_oa) && nrow(works) > 0) {
      round(n_oa / nrow(works) * 100, 1)
    } else NA_real_,
    n_retracted     = as.integer(n_retracted),
    n_languages     = dplyr::n_distinct(works$language, na.rm = TRUE)
  )
}


#' Summary statistics for authors
#'
#' @description
#' Computes aggregate summary statistics for authors in the corpus.
#'
#' @param corpus An [sm_corpus] object.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row containing:
#'   `n_authors`, `n_with_orcid`, `pct_orcid`, `mean_works_per_author`,
#'   `median_works_per_author`, `max_works_per_author`,
#'   `mean_authors_per_work`, `single_author_pct`.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_summary_authors(corpus)
sm_summary_authors <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  authors <- corpus$authors
  authorships <- corpus$authorships
  works <- corpus$works

  if (nrow(authors) == 0L) {
    return(tibble::tibble(
      n_authors = 0L, n_with_orcid = 0L, pct_orcid = NA_real_,
      mean_works_per_author = NA_real_,
      median_works_per_author = NA_real_,
      max_works_per_author = NA_integer_,
      mean_authors_per_work = NA_real_,
      single_author_pct = NA_real_
    ))
  }

  n_with_orcid <- sum(!is.na(authors$orcid) & nzchar(authors$orcid))

  # Works per author
  works_per_author <- if (nrow(authorships) > 0L) {
    authorships %>%
      dplyr::count(.data$author_id) %>%
      dplyr::pull(.data$n)
  } else {
    integer(0)
  }

  # Authors per work
  authors_per_work <- if (nrow(authorships) > 0L) {
    authorships %>%
      dplyr::count(.data$work_id) %>%
      dplyr::pull(.data$n)
  } else {
    integer(0)
  }

  single_pct <- if (length(authors_per_work) > 0L) {
    round(sum(authors_per_work == 1L) / length(authors_per_work) * 100, 1)
  } else {
    NA_real_
  }

  tibble::tibble(
    n_authors              = nrow(authors),
    n_with_orcid           = as.integer(n_with_orcid),
    pct_orcid              = round(n_with_orcid / nrow(authors) * 100, 1),
    mean_works_per_author  = if (length(works_per_author) > 0) {
      round(mean(works_per_author), 2)
    } else NA_real_,
    median_works_per_author = if (length(works_per_author) > 0) {
      stats::median(works_per_author)
    } else NA_real_,
    max_works_per_author   = if (length(works_per_author) > 0) {
      max(works_per_author)
    } else NA_integer_,
    mean_authors_per_work  = if (length(authors_per_work) > 0) {
      round(mean(authors_per_work), 2)
    } else NA_real_,
    single_author_pct      = single_pct
  )
}


#' Summary statistics for sources (journals)
#'
#' @description
#' Computes aggregate summary statistics for publication sources in the corpus.
#'
#' @param corpus An [sm_corpus] object.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row containing:
#'   `n_sources`, `n_oa_sources`, `pct_oa_sources`, `n_publishers`,
#'   `top_source` (source with most works), `top_source_n`.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_summary_sources(corpus)
sm_summary_sources <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  sources <- corpus$sources
  works <- corpus$works

  if (nrow(sources) == 0L) {
    return(tibble::tibble(
      n_sources = 0L, n_oa_sources = 0L, pct_oa_sources = NA_real_,
      n_publishers = 0L, top_source = NA_character_, top_source_n = 0L
    ))
  }

  n_oa_sources <- if ("is_oa" %in% names(sources)) {
    sum(sources$is_oa, na.rm = TRUE)
  } else {
    NA_integer_
  }

  n_publishers <- if ("publisher" %in% names(sources)) {
    dplyr::n_distinct(sources$publisher, na.rm = TRUE)
  } else {
    NA_integer_
  }

  # Top source by number of works
  top <- if (nrow(works) > 0L && "source_id" %in% names(works)) {
    source_counts <- works %>%
      dplyr::filter(!is.na(.data$source_id)) %>%
      dplyr::count(.data$source_id, sort = TRUE)

    if (nrow(source_counts) > 0L) {
      top_id <- source_counts$source_id[1]
      top_name <- if ("display_name" %in% names(sources)) {
        nm <- sources$display_name[sources$source_id == top_id]
        if (length(nm) > 0 && !is.na(nm[1])) nm[1] else top_id
      } else {
        top_id
      }
      list(name = top_name, n = source_counts$n[1])
    } else {
      list(name = NA_character_, n = 0L)
    }
  } else {
    list(name = NA_character_, n = 0L)
  }

  tibble::tibble(
    n_sources      = nrow(sources),
    n_oa_sources   = as.integer(n_oa_sources),
    pct_oa_sources = if (!is.na(n_oa_sources) && nrow(sources) > 0) {
      round(n_oa_sources / nrow(sources) * 100, 1)
    } else NA_real_,
    n_publishers   = as.integer(n_publishers),
    top_source     = top$name,
    top_source_n   = as.integer(top$n)
  )
}


#' Summary statistics by publication period
#'
#' @description
#' Computes per-year summary statistics for works in the corpus.
#'
#' @param corpus An [sm_corpus] object.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row per year and columns:
#'   `year`, `n_works`, `mean_citations`, `median_citations`,
#'   `total_citations`, `n_oa`, `pct_oa`, `n_authors` (unique authors
#'   active in that year), `mean_authors_per_work`.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_summary_period(corpus)
sm_summary_period <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  works <- corpus$works
  authorships <- corpus$authorships

  if (nrow(works) == 0L || !"year" %in% names(works) ||
      all(is.na(works$year))) {
    return(tibble::tibble(
      year = integer(), n_works = integer(), mean_citations = double(),
      median_citations = double(), total_citations = integer(),
      n_oa = integer(), pct_oa = double(), n_authors = integer(),
      mean_authors_per_work = double()
    ))
  }

  # Per-year work stats
  yearly_works <- works %>%
    dplyr::filter(!is.na(.data$year)) %>%
    dplyr::group_by(.data$year) %>%
    dplyr::summarise(
      n_works         = dplyr::n(),
      mean_citations   = round(mean(.data$cited_by_count, na.rm = TRUE), 2),
      median_citations = stats::median(.data$cited_by_count, na.rm = TRUE),
      total_citations  = sum(.data$cited_by_count, na.rm = TRUE),
      n_oa = if ("oa_status" %in% names(works)) {
        sum(!is.na(.data$oa_status) & .data$oa_status != "closed")
      } else {
        NA_integer_
      },
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      pct_oa = dplyr::if_else(
        is.na(.data$n_oa),
        NA_real_,
        round(.data$n_oa / .data$n_works * 100, 1)
      )
    )

  # Per-year author counts
  if (nrow(authorships) > 0L) {
    yearly_authors <- authorships %>%
      dplyr::inner_join(
        works %>% dplyr::select("work_id", "year"),
        by = "work_id"
      ) %>%
      dplyr::filter(!is.na(.data$year)) %>%
      dplyr::group_by(.data$year) %>%
      dplyr::summarise(
        n_authors = dplyr::n_distinct(.data$author_id),
        .groups = "drop"
      )

    authors_per_work <- authorships %>%
      dplyr::inner_join(
        works %>% dplyr::select("work_id", "year"),
        by = "work_id"
      ) %>%
      dplyr::filter(!is.na(.data$year)) %>%
      dplyr::count(.data$work_id, .data$year) %>%
      dplyr::group_by(.data$year) %>%
      dplyr::summarise(
        mean_authors_per_work = round(mean(.data$n), 2),
        .groups = "drop"
      )

    yearly_works <- yearly_works %>%
      dplyr::left_join(yearly_authors, by = "year") %>%
      dplyr::left_join(authors_per_work, by = "year")
  } else {
    yearly_works$n_authors <- NA_integer_
    yearly_works$mean_authors_per_work <- NA_real_
  }

  yearly_works %>%
    dplyr::arrange(.data$year)
}

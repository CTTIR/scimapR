#' Calculate h-index
#'
#' @description
#' Computes the h-index for entities at the specified level. An entity has
#' h-index *h* if *h* of its works have at least *h* citations each.
#'
#' @param corpus An [sm_corpus] object.
#' @param level Character; the entity level. One of `"author"` (default),
#'   `"institution"`, `"source"`, or `"country"`.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns for the entity ID/name and `h_index`.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_metric_h_index(corpus, level = "author")
sm_metric_h_index <- function(corpus,
                              level = c("author", "institution", "source",
                                        "country"),
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  level <- rlang::arg_match(level, error_call = call)

  entity_cites <- .get_entity_citations(corpus, level, call)

  if (nrow(entity_cites) == 0L) {
    return(.empty_metric_tibble(level, "h_index"))
  }

  result <- entity_cites %>%
    dplyr::group_by(.data$entity) %>%
    dplyr::summarise(
      h_index = .compute_h_index(.data$cited_by_count),
      .groups = "drop"
    ) %>%
    dplyr::rename(!!.entity_col_name(level) := "entity") %>%
    dplyr::arrange(dplyr::desc(.data$h_index))

  result
}


#' Calculate g-index
#'
#' @description
#' Computes the g-index for entities at the specified level. The g-index is
#' the largest *g* such that the top *g* works have at least *g*^2 citations
#' in total (Egghe, 2006).
#'
#' @param corpus An [sm_corpus] object.
#' @param level Character; the entity level. Defaults to `"author"`.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns for the entity ID/name and `g_index`.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_metric_g_index(corpus, level = "author")
sm_metric_g_index <- function(corpus,
                              level = c("author", "institution", "source",
                                        "country"),
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  level <- rlang::arg_match(level, error_call = call)

  entity_cites <- .get_entity_citations(corpus, level, call)

  if (nrow(entity_cites) == 0L) {
    return(.empty_metric_tibble(level, "g_index"))
  }

  result <- entity_cites %>%
    dplyr::group_by(.data$entity) %>%
    dplyr::summarise(
      g_index = .compute_g_index(.data$cited_by_count),
      .groups = "drop"
    ) %>%
    dplyr::rename(!!.entity_col_name(level) := "entity") %>%
    dplyr::arrange(dplyr::desc(.data$g_index))

  result
}


#' Calculate m-index (m-quotient)
#'
#' @description
#' Computes the m-index (m-quotient) for entities at the specified level.
#' The m-index equals the h-index divided by the number of years since the
#' entity's first publication (Hirsch, 2005).
#'
#' @param corpus An [sm_corpus] object.
#' @param level Character; the entity level. Defaults to `"author"`.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns for the entity ID/name, `h_index`,
#'   `first_year`, `career_years`, and `m_index`.
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_metric_m_index(corpus, level = "author")
sm_metric_m_index <- function(corpus,
                              level = c("author", "institution", "source",
                                        "country"),
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  level <- rlang::arg_match(level, error_call = call)

  entity_cites <- .get_entity_citations(corpus, level, call)

  if (nrow(entity_cites) == 0L) {
    col_name <- .entity_col_name(level)
    return(tibble::tibble(
      !!col_name := character(),
      h_index      = integer(),
      first_year   = integer(),
      career_years = integer(),
      m_index      = double()
    ))
  }

  current_year <- as.integer(format(Sys.Date(), "%Y"))

  result <- entity_cites %>%
    dplyr::group_by(.data$entity) %>%
    dplyr::summarise(
      h_index    = .compute_h_index(.data$cited_by_count),
      first_year = min(.data$year, na.rm = TRUE),
      .groups    = "drop"
    ) %>%
    dplyr::mutate(
      career_years = pmax(current_year - .data$first_year, 1L),
      m_index      = .data$h_index / .data$career_years
    ) %>%
    dplyr::rename(!!.entity_col_name(level) := "entity") %>%
    dplyr::arrange(dplyr::desc(.data$m_index))

  result
}


# --- Internal helpers ---

#' Compute h-index from a vector of citation counts
#' @noRd
.compute_h_index <- function(citations) {
  citations <- sort(citations[!is.na(citations)], decreasing = TRUE)
  if (length(citations) == 0L) return(0L)
  ranks <- seq_along(citations)
  h <- sum(citations >= ranks)
  as.integer(h)
}


#' Compute g-index from a vector of citation counts
#' @noRd
.compute_g_index <- function(citations) {
  citations <- sort(citations[!is.na(citations)], decreasing = TRUE)
  if (length(citations) == 0L) return(0L)
  cumsum_cites <- cumsum(citations)
  ranks <- seq_along(citations)
  g <- max(c(0L, ranks[cumsum_cites >= ranks^2]))
  as.integer(g)
}


#' Get entity-citation pairs
#' @noRd
.get_entity_citations <- function(corpus, level, call) {
  works <- corpus$works
  authorships <- corpus$authorships

  if (nrow(works) == 0L) {
    return(tibble::tibble(entity = character(), cited_by_count = integer(),
                          year = integer()))
  }

  switch(level,
    author = {
      if (nrow(authorships) == 0L) {
        return(tibble::tibble(entity = character(), cited_by_count = integer(),
                              year = integer()))
      }
      authorships %>%
        dplyr::select("work_id", entity = "author_id") %>%
        dplyr::distinct() %>%
        dplyr::inner_join(
          works %>% dplyr::select("work_id", "cited_by_count", "year"),
          by = "work_id"
        )
    },
    institution = {
      if (nrow(authorships) == 0L ||
          !"institution_id" %in% names(authorships)) {
        return(tibble::tibble(entity = character(), cited_by_count = integer(),
                              year = integer()))
      }
      authorships %>%
        dplyr::select("work_id", entity = "institution_id") %>%
        dplyr::filter(!is.na(.data$entity)) %>%
        dplyr::distinct() %>%
        dplyr::inner_join(
          works %>% dplyr::select("work_id", "cited_by_count", "year"),
          by = "work_id"
        )
    },
    source = {
      if (!"source_id" %in% names(works)) {
        return(tibble::tibble(entity = character(), cited_by_count = integer(),
                              year = integer()))
      }
      works %>%
        dplyr::filter(!is.na(.data$source_id)) %>%
        dplyr::select(entity = "source_id", "cited_by_count", "year",
                      work_id = "work_id")
    },
    country = {
      if (nrow(authorships) == 0L ||
          !"country_code" %in% names(authorships)) {
        return(tibble::tibble(entity = character(), cited_by_count = integer(),
                              year = integer()))
      }
      authorships %>%
        dplyr::select("work_id", entity = "country_code") %>%
        dplyr::filter(!is.na(.data$entity)) %>%
        dplyr::distinct() %>%
        dplyr::inner_join(
          works %>% dplyr::select("work_id", "cited_by_count", "year"),
          by = "work_id"
        )
    }
  )
}


#' Create empty metric tibble
#' @noRd
.empty_metric_tibble <- function(level, metric_name) {
  col_name <- .entity_col_name(level)
  tibble::tibble(!!col_name := character(), !!metric_name := integer())
}


#' Map level to column name
#' @noRd
.entity_col_name <- function(level) {
  switch(level,
    author      = "author_id",
    institution = "institution_id",
    source      = "source_id",
    country     = "country_code"
  )
}

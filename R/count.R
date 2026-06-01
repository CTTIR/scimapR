# Part D2: full vs fractional counting.

#' Full and fractional output / impact counting
#'
#' @description
#' Attributes publication output (and citation impact) to entities using either
#' full or fractional counting. Reviewers routinely ask for fractional counts
#' so that a single multi-author / multi-institution paper is not counted in
#' full for every contributor.
#'
#' @param corpus An `sm_corpus`.
#' @param method `"full"` (default) gives each entity credit 1 per work it
#'   appears on. `"fractional"` splits each work's single unit of credit equally
#'   among the distinct entities on that work.
#' @param level Entity level: `"institution"` (default), `"author"`, or
#'   `"source"`.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble, one row per entity, sorted by `credit` descending:
#'   \describe{
#'     \item{entity_id}{Entity identifier.}
#'     \item{entity_name}{Human-readable name (falls back to `entity_id`).}
#'     \item{n_works}{Number of distinct works the entity appears on (this is
#'       the full count and is identical for both methods).}
#'     \item{credit}{Output credit: `n_works` under `"full"`; the sum of
#'       per-work fractional shares under `"fractional"`.}
#'     \item{weighted_citations}{Citation impact attributed to the entity:
#'       summed `cited_by_count` under `"full"`; summed fractional-share
#'       weighted `cited_by_count` under `"fractional"`.}
#'   }
#'   Type-stable: an empty/inapplicable corpus returns a 0-row tibble with these
#'   columns.
#'
#' @details
#' The fractional rule is the standard equal-share rule: a work with \eqn{k}
#' distinct entities contributes \eqn{1/k} of credit (and \eqn{1/k} of its
#' citations) to each. For `level = "source"` each work has a single source, so
#' fractional and full counts coincide.
#'
#' @family counting
#' @seealso [sm_metric_summary()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 30, seed = 1)
#' sm_count(corpus, method = "fractional", level = "author")
sm_count <- function(corpus,
                     method = c("full", "fractional"),
                     level = c("institution", "author", "source"),
                     call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  method <- rlang::arg_match(method, error_call = call)
  level <- rlang::arg_match(level, error_call = call)

  empty <- tibble::tibble(
    entity_id = character(), entity_name = character(),
    n_works = integer(), credit = double(), weighted_citations = double()
  )

  works <- corpus$works
  cites <- stats::setNames(
    suppressWarnings(as.numeric(works$cited_by_count)),
    works$work_id
  )
  cites[is.na(cites)] <- 0

  # Build a long (work_id, entity_id, entity_name) mapping per level.
  map <- switch(level,
    author = {
      a <- corpus$authorships
      if (nrow(a) == 0L) return(empty)
      nm <- corpus$authors
      name_lookup <- if (nrow(nm) > 0L) {
        stats::setNames(nm$display_name, nm$author_id)
      } else {
        character()
      }
      tibble::tibble(
        work_id = a$work_id,
        entity_id = a$author_id,
        entity_name = unname(name_lookup[a$author_id])
      )
    },
    institution = {
      a <- corpus$authorships
      if (nrow(a) == 0L) return(empty)
      id_col <- if ("institution_id" %in% names(a) &&
                    any(!is.na(a$institution_id))) {
        "institution_id"
      } else if ("institution_match" %in% names(a)) {
        "institution_match"
      } else {
        "institution_id"
      }
      name_col <- if ("institution_name" %in% names(a)) "institution_name" else id_col
      tibble::tibble(
        work_id = a$work_id,
        entity_id = as.character(a[[id_col]]),
        entity_name = as.character(a[[name_col]])
      )
    },
    source = {
      if (nrow(works) == 0L) return(empty)
      src <- corpus$sources
      name_lookup <- if (nrow(src) > 0L &&
                         all(c("source_id", "display_name") %in% names(src))) {
        stats::setNames(src$display_name, src$source_id)
      } else {
        character()
      }
      tibble::tibble(
        work_id = works$work_id,
        entity_id = as.character(works$source_id),
        entity_name = unname(name_lookup[as.character(works$source_id)])
      )
    }
  )

  map <- dplyr::filter(map, !is.na(.data$entity_id))
  # distinct entity per work (so multiple authorships at one institution on one
  # work count once)
  map <- dplyr::distinct(map, .data$work_id, .data$entity_id,
                         .keep_all = TRUE)
  if (nrow(map) == 0L) return(empty)

  # per-work number of distinct entities (denominator for fractional credit)
  per_work_k <- map %>%
    dplyr::count(.data$work_id, name = "k")
  map <- dplyr::left_join(map, per_work_k, by = "work_id")

  map$share <- if (method == "fractional") 1 / map$k else 1
  map$work_cites <- unname(cites[map$work_id])
  map$work_cites[is.na(map$work_cites)] <- 0

  result <- map %>%
    dplyr::group_by(.data$entity_id) %>%
    dplyr::summarise(
      entity_name = dplyr::first(.data$entity_name),
      n_works = dplyr::n_distinct(.data$work_id),
      credit = sum(.data$share),
      weighted_citations = sum(.data$share * .data$work_cites),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      entity_name = ifelse(is.na(.data$entity_name) | !nzchar(.data$entity_name),
                           .data$entity_id, .data$entity_name),
      credit = round(.data$credit, 4),
      weighted_citations = round(.data$weighted_citations, 4)
    ) %>%
    dplyr::arrange(dplyr::desc(.data$credit), dplyr::desc(.data$n_works)) %>%
    dplyr::select("entity_id", "entity_name", "n_works", "credit",
                  "weighted_citations")

  result
}

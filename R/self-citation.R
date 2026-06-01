# E1 / F1: self-citation from the corpus reference network (quota-light).

#' Compute self-citation from corpus reference lists
#'
#' @description
#' Identifies self-citations from the `references` already in the corpus --- no
#' per-citation API calls. A citation from a citing work to a cited work is a
#' self-citation at the chosen `level` when the citing and cited works share an
#' author (or institution). This is the quota-light "reference overlap" method.
#'
#' @param corpus An `sm_corpus` with a populated `references` sub-tibble whose
#'   `cited_work_id` links to corpus works.
#' @param level `"author"` (default) or `"institution"`.
#' @param method Self-citation definition; currently only `"reference_overlap"`.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_self_citation` S3 object (a list) with components:
#'   \describe{
#'     \item{by_entity}{Tibble: `entity_id`, `n_citations_received` (internal
#'       citations to the entity's works), `n_self_citations`,
#'       `self_citation_share`.}
#'     \item{by_work}{Tibble: `cited_work_id`, `n_citations_received`,
#'       `n_self_citations`, `self_citation_share` (per cited work).}
#'     \item{provenance}{Tibble: `citing_work_id`, `cited_work_id`, and
#'       `shared_author_id` (author level) or `shared_institution_id`
#'       (institution level) --- the evidence behind each self-citation.}
#'   }
#'   Type-stable: when `references` is absent/empty the components are 0-row
#'   tibbles with the documented columns, returned after a `cli::cli_warn`
#'   (the function never spins).
#'
#' @family metrics
#' @seealso [sm_metric_h_index()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 40, seed = 1)
#' sc <- sm_self_citation(corpus, level = "author")
#' head(sc$by_entity)
sm_self_citation <- function(corpus,
                             level = c("author", "institution"),
                             method = c("reference_overlap"),
                             call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  level <- rlang::arg_match(level, error_call = call)
  method <- rlang::arg_match(method, error_call = call)

  ent_col <- if (level == "author") "shared_author_id" else "shared_institution_id"
  empty <- list(
    by_entity = tibble::tibble(
      entity_id = character(), n_citations_received = integer(),
      n_self_citations = integer(), self_citation_share = double()),
    by_work = tibble::tibble(
      cited_work_id = character(), n_citations_received = integer(),
      n_self_citations = integer(), self_citation_share = double()),
    provenance = tibble::tibble(
      citing_work_id = character(), cited_work_id = character(),
      !!ent_col := character())
  )
  empty <- structure(c(empty, list(level = level, method = method)),
                     class = "sm_self_citation")

  refs <- corpus$references
  if (nrow(refs) == 0L || !"cited_work_id" %in% names(refs) ||
      all(is.na(refs$cited_work_id))) {
    cli::cli_warn(c(
      "!" = "No internal reference network available; self-citation needs linked references.",
      "i" = "Returning empty self-citation result. Enrich references first (e.g. {.fn sm_enrich_opencitations})."
    ))
    return(empty)
  }

  # entity membership per work
  a <- corpus$authorships
  mem_col <- if (level == "author") "author_id" else "institution_id"
  if (nrow(a) == 0L || !mem_col %in% names(a)) {
    cli::cli_warn(c(
      "!" = "No {.field {mem_col}} on authorships; cannot compute {level}-level self-citation.",
      "i" = "Returning empty self-citation result."
    ))
    return(empty)
  }

  edges <- refs %>%
    dplyr::filter(!is.na(.data$cited_work_id)) %>%
    dplyr::select(citing_work_id = "work_id", "cited_work_id") %>%
    dplyr::distinct()

  membership <- a %>%
    dplyr::select(work_id = "work_id", entity = dplyr::all_of(mem_col)) %>%
    dplyr::filter(!is.na(.data$entity)) %>%
    dplyr::distinct()

  # provenance: shared entity between citing and cited works
  prov <- edges %>%
    dplyr::inner_join(membership, by = c("citing_work_id" = "work_id"),
                      relationship = "many-to-many") %>%
    dplyr::inner_join(membership, by = c("cited_work_id" = "work_id"),
                      suffix = c("_citing", "_cited"),
                      relationship = "many-to-many") %>%
    dplyr::filter(.data$entity_citing == .data$entity_cited) %>%
    dplyr::transmute(
      citing_work_id = .data$citing_work_id,
      cited_work_id = .data$cited_work_id,
      !!ent_col := .data$entity_citing
    ) %>%
    dplyr::distinct()

  # total internal citations received per cited work (edges where cited is in
  # the corpus, i.e. has membership) -- denominator
  cited_in_corpus <- unique(membership$work_id)
  recv <- edges %>%
    dplyr::filter(.data$cited_work_id %in% cited_in_corpus) %>%
    dplyr::distinct(.data$citing_work_id, .data$cited_work_id)

  by_work_recv <- recv %>%
    dplyr::count(.data$cited_work_id, name = "n_citations_received")
  by_work_self <- prov %>%
    dplyr::distinct(.data$citing_work_id, .data$cited_work_id) %>%
    dplyr::count(.data$cited_work_id, name = "n_self_citations")

  by_work <- by_work_recv %>%
    dplyr::left_join(by_work_self, by = "cited_work_id") %>%
    dplyr::mutate(
      n_self_citations = dplyr::coalesce(.data$n_self_citations, 0L),
      self_citation_share = round(.data$n_self_citations /
                                    .data$n_citations_received, 4)
    )

  # per entity: citations received by the entity's works, and self-citations
  ent_works <- membership %>% dplyr::rename(entity_id = "entity")
  entity_recv <- recv %>%
    dplyr::inner_join(ent_works, by = c("cited_work_id" = "work_id"),
                      relationship = "many-to-many") %>%
    dplyr::distinct(.data$entity_id, .data$citing_work_id,
                    .data$cited_work_id) %>%
    dplyr::count(.data$entity_id, name = "n_citations_received")

  entity_self <- prov %>%
    dplyr::rename(entity_id = dplyr::all_of(ent_col)) %>%
    dplyr::distinct(.data$entity_id, .data$citing_work_id,
                    .data$cited_work_id) %>%
    dplyr::count(.data$entity_id, name = "n_self_citations")

  by_entity <- entity_recv %>%
    dplyr::left_join(entity_self, by = "entity_id") %>%
    dplyr::mutate(
      n_self_citations = dplyr::coalesce(.data$n_self_citations, 0L),
      self_citation_share = round(.data$n_self_citations /
                                    .data$n_citations_received, 4)
    ) %>%
    dplyr::arrange(dplyr::desc(.data$n_self_citations))

  structure(
    list(by_entity = by_entity, by_work = by_work, provenance = prov,
         level = level, method = method),
    class = "sm_self_citation"
  )
}

#' @rdname sm_self_citation
#' @param x An `sm_self_citation` object.
#' @param ... Ignored.
#' @return `print` returns `x` invisibly.
#' @export
print.sm_self_citation <- function(x, ...) {
  cli::cli_h1("<sm_self_citation>")
  cli::cli_text("{.strong Level:} {x$level}   {.strong Method:} {x$method}")
  n_ent <- nrow(x$by_entity)
  n_self <- sum(x$by_entity$n_self_citations)
  n_recv <- sum(x$by_entity$n_citations_received)
  share <- if (n_recv > 0L) round(n_self / n_recv, 4) else NA_real_
  cli::cli_text("{.strong Entities:} {n_ent}   {.strong Self-citations:} {n_self} / {n_recv} ({.val {share}})")
  cli::cli_text("{.strong Provenance rows:} {nrow(x$provenance)}")
  invisible(x)
}

#' @rdname sm_self_citation
#' @param object An `sm_self_citation` object.
#' @return `summary` returns the `by_entity` tibble.
#' @export
summary.sm_self_citation <- function(object, ...) {
  object$by_entity
}

#' Self-citation counts per (entity, cited work) for index correction
#'
#' Returns a tibble `entity_id`, `cited_work_id`, `n_self` used by the
#' self-corrected h/g/m indices.
#' @noRd
.self_cite_counts <- function(corpus, level, call = rlang::caller_env()) {
  sc <- sm_self_citation(corpus, level = level, call = call)
  ent_col <- if (level == "author") "shared_author_id" else "shared_institution_id"
  prov <- sc$provenance
  if (nrow(prov) == 0L) {
    return(tibble::tibble(entity_id = character(),
                          cited_work_id = character(), n_self = integer()))
  }
  prov %>%
    dplyr::rename(entity_id = dplyr::all_of(ent_col)) %>%
    dplyr::distinct(.data$entity_id, .data$citing_work_id,
                    .data$cited_work_id) %>%
    dplyr::count(.data$entity_id, .data$cited_work_id, name = "n_self")
}

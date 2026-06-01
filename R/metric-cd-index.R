#' Calculate the CD (disruption) index
#'
#' @description
#' Computes the CD index (Funk & Owen-Smith, 2017) for each work in the
#' corpus. The CD index measures how disruptive a work is by comparing the
#' citation patterns of papers that cite the focal work versus those that
#' cite its references.
#'
#' @param corpus An [sm_corpus] object with a populated `references` table.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns `work_id` and `cd_index`. The CD index
#'   ranges from -1 (consolidating) to +1 (disruptive). Works without
#'   sufficient citation data receive `NA`.
#'
#' @details
#' The CD index is defined as:
#'
#' \deqn{CD = \frac{n_i - n_j}{n_i + n_j + n_k}}{CD = (n_i - n_j) / (n_i + n_j + n_k)}
#'
#' Where for a focal work *f*:
#' \describe{
#'   \item{n_i}{Number of works that cite *f* but do NOT cite any of *f*'s
#'     references (disruptive citations).}
#'   \item{n_j}{Number of works that cite BOTH *f* and at least one of *f*'s
#'     references (consolidating citations).}
#'   \item{n_k}{Number of works that cite at least one of *f*'s references
#'     but do NOT cite *f* (ignored-but-referencing citations).}
#' }
#'
#' A CD index near +1 indicates the focal work is highly disruptive: its
#' citers tend to ignore its references. A CD index near -1 indicates the
#' focal work consolidates existing ideas.
#'
#' @references
#' Funk, R. J., & Owen-Smith, J. (2017). A Dynamic Network Measure of
#' Technological Change. *Management Science*, 63(3), 791--817.
#' \doi{10.1287/mnsc.2015.2366}
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' cd <- sm_metric_disruption(corpus)
#' head(cd)
sm_metric_disruption <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  works <- corpus$works
  refs <- corpus$references

  # --- empty / absent reference-network guard (fast-exit, never spin) ---
  if (nrow(works) == 0L) {
    return(tibble::tibble(work_id = character(), cd_index = double()))
  }
  if (nrow(refs) == 0L) {
    cli::cli_warn(c(
      "!" = "No reference network available; the CD (disruption) index requires linked references.",
      "i" = "Returning {.code NA} for all works. Enrich references first (e.g. {.fn sm_enrich_opencitations})."
    ))
    return(tibble::tibble(work_id = works$work_id,
                          cd_index = rep(NA_real_, nrow(works))))
  }

  refs <- dplyr::filter(refs, !is.na(.data$cited_work_id))
  if (nrow(refs) == 0L) {
    cli::cli_warn(c(
      "!" = "References are present but none are linked to corpus works ({.field cited_work_id} all missing).",
      "i" = "The CD (disruption) index needs internal citation links; returning {.code NA} for all works."
    ))
    return(tibble::tibble(work_id = works$work_id,
                          cd_index = rep(NA_real_, nrow(works))))
  }

  # Build the citation graph:
  # refs gives us: work_id -> cited_work_id (work_id cites cited_work_id)
  # "Citing focal" means: refs where cited_work_id == focal_id
  # i.e. the set of work_ids that cite the focal work

  focal_ids <- works$work_id

  # O(1) adjacency lookups via split(), avoiding the previous per-work linear
  # scans that made this O(n^2) and could spin for minutes on large corpora.
  # citers_by[[w]] = works that cite w;  refs_by[[w]] = works cited by w.
  citers_by <- split(refs$work_id, refs$cited_work_id)
  refs_by <- split(refs$cited_work_id, refs$work_id)
  citers_by <- lapply(citers_by, unique)
  refs_by <- lapply(refs_by, unique)

  cd_values <- numeric(length(focal_ids))
  cli::cli_progress_bar("Computing CD (disruption) index",
                        total = length(focal_ids),
                        .envir = environment())
  for (idx in seq_along(focal_ids)) {
    f <- focal_ids[idx]
    f_refs <- refs_by[[f]]
    if (is.null(f_refs) || length(f_refs) == 0L) {
      cd_values[idx] <- NA_real_
      cli::cli_progress_update(.envir = environment())
      next
    }
    f_citers <- citers_by[[f]]
    if (is.null(f_citers)) f_citers <- character()
    # works that cite any of f's references
    f_ref_citers <- unique(unlist(citers_by[f_refs], use.names = FALSE))

    n_j <- length(intersect(f_citers, f_ref_citers))
    n_i <- length(f_citers) - n_j
    n_k <- length(setdiff(f_ref_citers, f_citers))
    denom <- n_i + n_j + n_k
    cd_values[idx] <- if (denom == 0L) NA_real_ else (n_i - n_j) / denom
    cli::cli_progress_update(.envir = environment())
  }
  cli::cli_progress_done(.envir = environment())

  tibble::tibble(
    work_id  = focal_ids,
    cd_index = round(cd_values, 6)
  )
}

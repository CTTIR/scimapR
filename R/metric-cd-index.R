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

  # --- empty input guard ---
  if (nrow(works) == 0L || nrow(refs) == 0L) {
    return(tibble::tibble(work_id = character(), cd_index = double()))
  }

  refs <- dplyr::filter(refs, !is.na(.data$cited_work_id))
  if (nrow(refs) == 0L) {
    return(tibble::tibble(work_id = works$work_id,
                          cd_index = rep(NA_real_, nrow(works))))
  }

  # Build the citation graph:
  # refs gives us: work_id -> cited_work_id (work_id cites cited_work_id)
  # "Citing focal" means: refs where cited_work_id == focal_id
  # i.e. the set of work_ids that cite the focal work

  focal_ids <- works$work_id

  # Pre-compute: for each work, the set of works that cite it
  # (reverse lookup from refs)
  citers_of <- refs %>%
    dplyr::select(focal = "cited_work_id", citer = "work_id") %>%
    dplyr::distinct()

  # Pre-compute: for each work, its reference set
  refs_of <- refs %>%
    dplyr::select(focal = "work_id", ref = "cited_work_id") %>%
    dplyr::distinct()

  # Compute CD index for each focal work
  cd_values <- vapply(focal_ids, function(f) {
    # References of focal work f
    f_refs <- refs_of$ref[refs_of$focal == f]
    if (length(f_refs) == 0L) return(NA_real_)

    # Works that cite f
    f_citers <- citers_of$citer[citers_of$focal == f]
    if (length(f_citers) == 0L) {
      # n_i = 0, n_j = 0
      # n_k = works citing f's refs but not f
      f_ref_citers <- unique(citers_of$citer[citers_of$focal %in% f_refs])
      n_k <- length(setdiff(f_ref_citers, f_citers))
      if (n_k == 0L) return(NA_real_)
      return(0 / n_k)  # CD = (0 - 0) / (0 + 0 + n_k) = 0
    }

    # Works that cite any of f's references
    f_ref_citers <- unique(citers_of$citer[citers_of$focal %in% f_refs])

    # n_j: cite both f and at least one of f's refs
    n_j <- length(intersect(f_citers, f_ref_citers))

    # n_i: cite f but NOT any of f's refs
    n_i <- length(f_citers) - n_j

    # n_k: cite f's refs but NOT f
    n_k <- length(setdiff(f_ref_citers, f_citers))

    denom <- n_i + n_j + n_k
    if (denom == 0L) return(NA_real_)

    (n_i - n_j) / denom
  }, double(1))

  tibble::tibble(
    work_id  = focal_ids,
    cd_index = round(cd_values, 6)
  )
}

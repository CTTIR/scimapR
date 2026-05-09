#' Calculate Uzzi novelty score
#'
#' @description
#' Computes the Uzzi et al. (2013) novelty score for each work based on
#' atypical combinations of cited journals. A work is novel if its reference
#' list contains unusual journal pairings -- combinations that are rarely
#' seen together in the broader literature.
#'
#' @param corpus An [sm_corpus] object with populated `references` and
#'   `works` tables. Works and their references should have `source_id`
#'   assignments.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns `work_id` and `novelty`. Higher values
#'   indicate more novel (atypical) journal combinations. Works with
#'   insufficient data receive `NA`.
#'
#' @details
#' The algorithm:
#' 1. For each work, identify the journals (sources) of its cited references.
#' 2. Enumerate all pairwise journal combinations in each reference list.
#' 3. Compute the observed frequency of each journal pair across all works.
#' 4. Compute the expected frequency under independence (product of marginal
#'    frequencies).
#' 5. The novelty score for a work is the median of
#'    \eqn{-\log_{10}(observed / expected)} across all its journal pairs.
#'    High values indicate atypical combinations.
#'
#' Works with fewer than 2 references with known journals receive `NA`.
#'
#' @references
#' Uzzi, B., Mukherjee, S., Stringer, M., & Jones, B. (2013). Atypical
#' Combinations and Scientific Impact. *Science*, 342(6157), 468--472.
#' \doi{10.1126/science.1240474}
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' nov <- sm_metric_novelty(corpus)
#' head(nov)
sm_metric_novelty <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  works <- corpus$works
  refs <- corpus$references

  if (nrow(works) == 0L || nrow(refs) == 0L) {
    return(tibble::tibble(work_id = character(), novelty = double()))
  }

  refs <- dplyr::filter(refs, !is.na(.data$cited_work_id))

  # Map each cited work to its source (journal)
  if (!"source_id" %in% names(works)) {
    return(tibble::tibble(work_id = works$work_id,
                          novelty = rep(NA_real_, nrow(works))))
  }

  ref_sources <- refs %>%
    dplyr::select("work_id", "cited_work_id") %>%
    dplyr::inner_join(
      works %>% dplyr::select(cited_work_id = "work_id",
                               ref_source = "source_id"),
      by = "cited_work_id"
    ) %>%
    dplyr::filter(!is.na(.data$ref_source))

  if (nrow(ref_sources) == 0L) {
    return(tibble::tibble(work_id = works$work_id,
                          novelty = rep(NA_real_, nrow(works))))
  }

  # Enumerate journal pairs per work
  pairs <- ref_sources %>%
    dplyr::inner_join(
      ref_sources %>% dplyr::rename(ref_source_2 = "ref_source",
                                     cited_work_id_2 = "cited_work_id"),
      by = "work_id",
      relationship = "many-to-many"
    ) %>%
    dplyr::filter(.data$ref_source < .data$ref_source_2) %>%
    dplyr::select("work_id", "ref_source", "ref_source_2") %>%
    dplyr::distinct()

  if (nrow(pairs) == 0L) {
    return(tibble::tibble(work_id = works$work_id,
                          novelty = rep(NA_real_, nrow(works))))
  }

  # Count observed frequency of each journal pair across all works
  pair_counts <- pairs %>%
    dplyr::count(.data$ref_source, .data$ref_source_2, name = "observed")

  # Compute marginal frequencies (how often each journal appears as a
  # reference source across all works)
  n_total_refs <- nrow(ref_sources)
  journal_freq <- ref_sources %>%
    dplyr::count(.data$ref_source, name = "marginal")

  # Total number of journal pairs across all works
  total_pairs <- nrow(pairs)

  # Expected frequency under independence
  pair_expected <- pair_counts %>%
    dplyr::left_join(journal_freq, by = "ref_source") %>%
    dplyr::left_join(
      journal_freq %>% dplyr::rename(ref_source_2 = "ref_source",
                                      marginal_2 = "marginal"),
      by = "ref_source_2"
    ) %>%
    dplyr::mutate(
      p1 = .data$marginal / n_total_refs,
      p2 = .data$marginal_2 / n_total_refs,
      expected = .data$p1 * .data$p2 * total_pairs,
      expected = pmax(.data$expected, 1e-10),
      z_score  = -log10(.data$observed / .data$expected)
    ) %>%
    dplyr::select("ref_source", "ref_source_2", "z_score")

  # Join z-scores back to work-level pairs and compute median per work
  work_novelty <- pairs %>%
    dplyr::left_join(pair_expected, by = c("ref_source", "ref_source_2")) %>%
    dplyr::group_by(.data$work_id) %>%
    dplyr::summarise(
      novelty = stats::median(.data$z_score, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(novelty = round(.data$novelty, 6))

  # Ensure all works are represented
  result <- tibble::tibble(work_id = works$work_id) %>%
    dplyr::left_join(work_novelty, by = "work_id")

  result
}

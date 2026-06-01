#' scimapR accessor return-type stability contract
#'
#' @description
#' scimapR treats the return type of its **documented accessors** as a contract.
#' The column set (names and types) of an accessor's documented return value
#' will not change without a [lifecycle](https://lifecycle.r-lib.org/)
#' deprecation and a corresponding `NEWS.md` entry. New columns may be *added*
#' (a non-breaking change); existing documented columns will not be removed or
#' retyped silently.
#'
#' This policy exists because a silent list -> tibble change in
#' `sm_coverage_breakdowns()` between 0.2.0 and 0.3.0 broke downstream code.
#' From 0.4.0, accessors that expose a tidy table take a `tidy = TRUE` argument
#' whose column set is the stable contract.
#'
#' @section Audited accessors and their stable return shapes:
#' \describe{
#'   \item{[sm_coverage_breakdowns()] (`tidy = TRUE`)}{A long tibble:
#'     `dimension`, `level`, `n_reference`, `n_matched`, `recall`, `n_corpus`,
#'     `precision`, `f1`.}
#'   \item{[summary.sm_coverage()]}{A one-row tibble: `recall`, `precision`,
#'     `f1`, `n_corpus`, `n_reference`, `n_matched`, `n_corpus_only`,
#'     `n_reference_only`.}
#'   \item{[sm_affiliation_summary()]}{A tibble: `institution`, `match_signal`
#'     (factor, see [sm_affiliation_signals()]), `n_authorships`, `n_works`,
#'     `example_evidence`.}
#'   \item{[sm_reconcile()] (`summary()`)}{A one-row tibble: `n_a`, `n_b`,
#'     `n_both`, `n_only_a`, `n_only_b`, `jaccard`.}
#'   \item{[sm_metric_summary()]}{A one-row tibble: `metric`, `n`, `mean`,
#'     `median`, and (when `robust = TRUE`) `median_ci_low`, `median_ci_high`,
#'     `pp_top10`, `n_boot`.}
#'   \item{[sm_self_citation()] (`by_entity` / `by_work` / `provenance`)}{Tidy
#'     tibbles with the columns documented at [sm_self_citation()].}
#' }
#'
#' @section Controlled vocabularies:
#' Free-text controlled columns are emitted as factors with exported level
#' sets, so downstream filtering is reliable: see [sm_affiliation_signals()]
#' (`match_signal`), [sm_affiliation_methods()] (`match_method`), and
#' [sm_match_types()] (coverage `match_type`).
#'
#' @name scimapR-stability
#' @family reference
#' @keywords internal
NULL

#' sm_trajectory S3 class
#'
#' @description
#' An `sm_trajectory` object encodes the career trajectory of a single author
#' across a corpus, including career stages, topic pivots, collaborator
#' turnover, emerging collaborators, h-index curve, novelty curve, and
#' citation acceleration.
#'
#' The object is created by [sm_author_trajectory()] and should not normally
#' be constructed directly.
#'
#' @name sm_trajectory
#' @family trajectory
NULL

#' Low-level constructor for sm_trajectory
#' @noRd
new_sm_trajectory <- function(author_id,
                              author_name,
                              orcid = NA_character_,
                              n_periods,
                              career_stages,
                              topic_pivots,
                              collaborator_turnover,
                              emerging_collaborators,
                              h_index_curve,
                              novelty_curve,
                              citation_acceleration) {
  structure(
    list(
      author_id = author_id,
      author_name = author_name,
      orcid = orcid,
      n_periods = n_periods,
      career_stages = career_stages,
      topic_pivots = topic_pivots,
      collaborator_turnover = collaborator_turnover,
      emerging_collaborators = emerging_collaborators,
      h_index_curve = h_index_curve,
      novelty_curve = novelty_curve,
      citation_acceleration = citation_acceleration
    ),
    class = "sm_trajectory"
  )
}

#' Test if an object is an sm_trajectory
#' @param x An object to test.
#' @return Logical.
#' @family trajectory
#' @export
is_sm_trajectory <- function(x) {
  inherits(x, "sm_trajectory")
}

#' Empty trajectory tibbles
#' @noRd
.empty_career_stages <- function() {
  tibble::tibble(
    period = integer(),
    year_range = character(),
    n_works = integer(),
    dominant_topics = list(),
    h_index = integer()
  )
}

.empty_topic_pivots <- function() {
  tibble::tibble(
    period = integer(),
    year = integer(),
    pivot_score = double(),
    from_topic = character(),
    to_topic = character()
  )
}

.empty_collaborator_turnover <- function() {
  tibble::tibble(
    period = integer(),
    jaccard_to_prev = double(),
    n_new = integer(),
    n_kept = integer(),
    n_lost = integer()
  )
}

.empty_h_index_curve <- function() {
  tibble::tibble(
    period = integer(),
    year = integer(),
    year_range = character(),
    h_index = integer()
  )
}

.empty_novelty_curve <- function() {
  tibble::tibble(
    period = integer(),
    year_range = character(),
    mean_novelty = double()
  )
}

.empty_citation_acceleration <- function() {
  tibble::tibble(
    period = integer(),
    year_range = character(),
    mean_citations = double(),
    delta_vs_field = double()
  )
}

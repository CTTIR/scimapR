#' Build a researcher profile
#'
#' @description
#' One-shot workflow: fetch all works for a researcher by ORCID, enrich,
#' embed, and build a trajectory analysis.
#'
#' @param orcid ORCID identifier.
#' @param sources API sources to query.
#' @param enrich Enrichment steps to run.
#' @param embed Logical; compute embeddings?
#' @param trajectory Logical; build trajectory analysis?
#' @param mailto Email for API polite pool.
#'
#' @return An `sm_corpus` with trajectory attached as attribute.
#'
#' @family trajectory
#' @export
#' @examples
#' \dontrun{
#' # profile <- sm_researcher_profile("0000-0001-8006-9742")
#' }
sm_researcher_profile <- function(orcid,
                                  sources = c("openalex"),
                                  enrich = c("oa_status"),
                                  embed = FALSE,
                                  trajectory = TRUE,
                                  mailto = Sys.getenv("SCIMAPR_MAILTO")) {
  .check_string(orcid)

  corpus <- sm_fetch_openalex(
    filter = paste0("author.orcid:", orcid),
    mailto = mailto,
    verbose = TRUE
  )

  if (trajectory && nrow(corpus$works) >= 5) {
    traj <- sm_author_trajectory(corpus, orcid = orcid)
    attr(corpus, "trajectory") <- traj
  }

  corpus
}

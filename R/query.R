#' Search works by text query
#'
#' @description
#' Full-text search across titles and abstracts in a corpus.
#'
#' @param corpus An `sm_corpus` object.
#' @param query A search string (regex supported).
#' @param fields Which fields to search. Default `c("title", "abstract")`.
#' @param ignore_case Logical; case-insensitive search?
#'
#' @return An `sm_corpus` with matching works.
#'
#' @family filters
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' results <- sm_query(corpus, "transcriptomics")
sm_query <- function(corpus, query,
                     fields = c("title", "abstract"),
                     ignore_case = TRUE) {
  .check_sm_corpus(corpus)
  .check_string(query)

  works <- corpus$works
  matches <- rep(FALSE, nrow(works))

  for (field in fields) {
    if (field %in% names(works)) {
      vals <- works[[field]]
      vals[is.na(vals)] <- ""
      matches <- matches | grepl(query, vals, ignore.case = ignore_case)
    }
  }

  keep_ids <- works$work_id[matches]
  corpus[which(corpus$works$work_id %in% keep_ids)]
}

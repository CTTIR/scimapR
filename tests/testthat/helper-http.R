local_http_env <- function(.env = parent.frame()) {
  withr::local_envvar(OPENALEX_API_KEY = "", SCIMAPR_MAILTO = "",
                      GENDERIZE_API_KEY = "", SEMANTIC_SCHOLAR_API_KEY = "",
                      NCBI_API_KEY = "", .local_envir = .env)
}

http_response <- function(body = list(), status = 200L, headers = list()) {
  httr2::response(
    status_code = status, url = "https://example.org/works",
    headers = c(list(`Content-Type` = "application/json"), headers),
    body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null"))
  )
}

funding_answer <- function(funders, works) {
  list(funders = funders,
       checked = works$work_id[!is.na(works$doi) & nzchar(works$doi)],
       failed = character(), condition = NULL)
}

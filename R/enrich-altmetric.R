#' Enrich corpus with Altmetric attention data
#'
#' @description
#' Look up DOIs in the corpus via the
#' [Altmetric](https://www.altmetric.com/) API and add attention scores,
#' Mendeley reader counts, and social media metrics to the `works` table.
#'
#' This enricher is idempotent: re-running it updates existing Altmetric
#' data rather than duplicating it.
#'
#' @param corpus An `sm_corpus` object.
#' @param api_key Altmetric API key. Read from `ALTMETRIC_API_KEY` env var.
#'   The free tier (no key) is used when empty.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with added `altmetric_score`,
#'   `mendeley_readers`, `twitter_count`, and `news_count` columns in the
#'   `works` table, plus new provenance rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_altmetric(corpus)
#' }
sm_enrich_altmetric <- function(corpus,
                                api_key = Sys.getenv("ALTMETRIC_API_KEY"),
                                verbose = TRUE,
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  dois <- corpus$works$doi
  has_doi <- !is.na(dois) & nzchar(dois)

  if (!any(has_doi)) {
    .sm_verbose("No DOIs in corpus; skipping Altmetric enrichment.", verbose)
    return(corpus)
  }

  target_dois <- dois[has_doi]
  target_ids <- corpus$works$work_id[has_doi]

  .sm_verbose(
    "Looking up {length(target_dois)} DOIs on Altmetric...",
    verbose
  )

  alt_score <- rep(NA_real_, length(target_dois))
  mendeley <- rep(NA_integer_, length(target_dois))
  twitter <- rep(NA_integer_, length(target_dois))
  news <- rep(NA_integer_, length(target_dois))

  for (i in seq_along(target_dois)) {
    result <- tryCatch({
      url <- paste0("https://api.altmetric.com/v1/doi/", target_dois[i])

      req <- httr2::request(url) |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 1 / 1)

      if (nzchar(api_key)) {
        req <- httr2::req_url_query(req, key = api_key)
      }

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
      NULL
    })

    if (!is.null(result)) {
      alt_score[i] <- as.double(result[["score"]] %||% NA_real_)
      mendeley[i] <- as.integer(
        result[["readers"]][["mendeley"]] %||% NA_integer_
      )
      twitter[i] <- as.integer(
        result[["cited_by_tweeters_count"]] %||% NA_integer_
      )
      news[i] <- as.integer(
        result[["cited_by_msm_count"]] %||% NA_integer_
      )
    }

    if (verbose && i %% 50 == 0) {
      .sm_verbose("Altmetric: {i} / {length(target_dois)} DOIs processed.", verbose)
    }
  }

  # Update works table
  works <- corpus$works

  for (col in c("altmetric_score", "mendeley_readers",
                "twitter_count", "news_count")) {
    if (!col %in% names(works)) {
      works[[col]] <- switch(col,
        altmetric_score = NA_real_,
        NA_integer_
      )
    }
  }

  works$altmetric_score[has_doi] <- ifelse(
    is.na(alt_score), works$altmetric_score[has_doi], alt_score
  )
  works$mendeley_readers[has_doi] <- ifelse(
    is.na(mendeley), works$mendeley_readers[has_doi], mendeley
  )
  works$twitter_count[has_doi] <- ifelse(
    is.na(twitter), works$twitter_count[has_doi], twitter
  )
  works$news_count[has_doi] <- ifelse(
    is.na(news), works$news_count[has_doi], news
  )

  # Add provenance rows
  new_prov <- .make_provenance_rows(
    work_ids = target_ids,
    source_name = "altmetric",
    external_ids = target_dois,
    query_text = "enrich_altmetric",
    engine_name = "native"
  )

  corpus$works <- works
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)

  n_enriched <- sum(!is.na(alt_score))
  .sm_done("Enriched {n_enriched} works with Altmetric data.")
  corpus
}

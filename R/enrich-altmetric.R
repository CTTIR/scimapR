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
#'   The Altmetric Details Page API has required a key since November 2025;
#'   without one, no work is enriched and a warning says so.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with added `altmetric_score`,
#'   `mendeley_readers`, `twitter_count`, and `news_count` columns in the
#'   `works` table, plus provenance rows for the works Altmetric answered for.
#'   Works whose lookup failed (other than "not found") keep missing values
#'   and are reported in a warning of class `scimapR_altmetric_unchecked`
#'   with their `work_ids`.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' # Not run: the Altmetric API needs an API key (`ALTMETRIC_API_KEY`).
#' corpus <- sm_corpus(works = tibble::tibble(
#'   work_id = "W1",
#'   doi = "10.1371/journal.pbio.1002541"
#' ))
#' corpus <- sm_enrich_altmetric(corpus)
#' }
sm_enrich_altmetric <- function(corpus,
                                api_key = Sys.getenv("ALTMETRIC_API_KEY"),
                                verbose = TRUE,
                                call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_corpus_unlocked(corpus, call = call)

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
  failed <- rep(FALSE, length(target_dois))

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
      # A 404 means Altmetric has no record for the DOI, which is a normal
      # answer. Anything else (missing or rejected key, rate limit, server or
      # network error) leaves the work unchecked.
      if (!inherits(e, "httr2_http_404")) failed[i] <<- TRUE
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

  # Add provenance rows for the works Altmetric actually answered for
  new_prov <- .make_provenance_rows(
    work_ids = target_ids[!failed],
    source_name = "altmetric",
    external_ids = target_dois[!failed],
    query_text = "enrich_altmetric",
    engine_name = "native",
    kind = "enrichment"
  )

  corpus$works <- works
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)

  n_failed <- sum(failed)
  if (n_failed) {
    message <- sprintf("Altmetric lookups failed for %d of %d works.",
                       n_failed, length(target_dois))
    if (!nzchar(api_key)) {
      message <- c(message, "i" = paste(
        "The Altmetric API needs a key; set the ALTMETRIC_API_KEY",
        "environment variable or pass `api_key`."
      ))
    }
    cli::cli_warn(message, class = "scimapR_altmetric_unchecked",
                  work_ids = target_ids[failed], call = call)
  }

  n_enriched <- sum(!is.na(alt_score))
  .sm_done("Enriched {n_enriched} works with Altmetric data.")
  corpus
}

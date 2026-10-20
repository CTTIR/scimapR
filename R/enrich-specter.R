#' Enrich corpus with SPECTER embeddings
#'
#' @description
#' Fetch pre-computed SPECTER v2 embeddings from the
#' [Semantic Scholar](https://www.semanticscholar.org/) API for works in
#' the corpus and attach them as the `embeddings` matrix.
#'
#' SPECTER embeddings are 768-dimensional vectors useful for computing
#' document similarity, clustering, and visualisation. No Python
#' installation is required -- this function retrieves pre-computed
#' vectors from the API.
#'
#' This enricher is idempotent: works that already have embeddings from
#' the same source are skipped, so a second call fills only the gaps.
#'
#' @details
#' The function asks Semantic Scholar for its SPECTER v2 vectors (the API
#' field `embedding.specter_v2`; the API's default is SPECTER v1) and
#' records them in `corpus$metadata$embedding` (see [sm_corpus()]) with
#' the model id `"embedding.specter_v2"` and, as `revision`, the model
#' version that Semantic Scholar reports. Semantic Scholar does not say
#' which revision of the model or which text it used, so these vectors
#' count as a model of their own, also next to embeddings from
#' `sm_embed_works(model = "specter2")`.
#'
#' A corpus that already has embeddings of another model, or of a model
#' that is not recorded (such as embeddings made by earlier versions of
#' scimapR), would get a matrix whose rows come from two models, and
#' similarities between such rows mean nothing. The function therefore
#' stops (class `scimapR_embedding_model_mismatch`) unless you choose:
#' `replace = TRUE` discards the existing embeddings, with a message, and
#' fetches SPECTER v2 vectors for every work with a DOI; `mix_models =
#' TRUE` keeps them and adds SPECTER v2 vectors for the works without an
#' embedding, and the record then names the model `"mixed"`. A mix needs
#' embeddings of the same width.
#'
#' Requests go out in batches of 100 DOIs. A batch that Semantic Scholar
#' answers with HTTP 429 (too many requests) is tried once more after a
#' short wait; a batch that still fails is skipped, and one warning (class
#' `scimapR_specter_failed`) gives the number of failed batches.
#'
#' @param corpus An `sm_corpus` object.
#' @param api_key Semantic Scholar API key. Read from
#'   `SEMANTIC_SCHOLAR_API_KEY` env var by default.
#' @param replace Logical; replace existing embeddings of another model
#'   (or of an unrecorded one) by SPECTER v2 vectors? Defaults to `FALSE`.
#'   See Details.
#' @param mix_models Logical; keep existing embeddings of another model
#'   (or of an unrecorded one) and add SPECTER v2 vectors for the other
#'   works? Defaults to `FALSE`. See Details.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with an `embeddings` matrix, its record
#'   in `metadata$embedding`, plus new provenance rows of the kind
#'   `"enrichment"`, which [sm_rebuild_from_cert()] does not replay.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus(with_embeddings = FALSE)
#' corpus <- sm_enrich_specter(corpus)
#' corpus$metadata$embedding$model_id
#'
#' # a corpus with embeddings of another model
#' corpus <- sm_embed_works(corpus, model = "mpnet")
#' corpus <- sm_enrich_specter(corpus, replace = TRUE)
#' }
sm_enrich_specter <- function(corpus,
                              api_key = Sys.getenv("SEMANTIC_SCHOLAR_API_KEY"),
                              replace = FALSE,
                              mix_models = FALSE,
                              verbose = TRUE,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_flag(replace, call = call)
  .check_flag(mix_models, call = call)
  if (replace && mix_models) {
    cli::cli_abort(
      "Set {.arg replace} or {.arg mix_models} to {.code TRUE}, not both.",
      call = call
    )
  }

  # Which model made the existing embeddings
  existing <- corpus$embeddings
  has_existing <- !is.null(existing) && nrow(existing) > 0L
  current <- .embedding_record(corpus)
  same <- .embedding_same_model(current, list(model_id = .s2_specter_v2_id))
  if (has_existing && !same && !replace && !mix_models) {
    .embedding_abort_mismatch(
      "The corpus already has {first}, not SPECTER v2 vectors from
       Semantic Scholar.",
      rec1 = current,
      rec2 = NULL,
      hint = c(
        "i" = "Use {.code replace = TRUE} to replace them by SPECTER v2
               vectors, or {.code mix_models = TRUE} to keep them and add
               SPECTER v2 vectors for the works without an embedding."
      ),
      call = call
    )
  }
  keep <- has_existing && !replace

  # Determine which works need embeddings
  existing_ids <- if (keep) rownames(existing) else character()
  needs_embedding <- !corpus$works$work_id %in% existing_ids
  dois <- corpus$works$doi
  has_doi <- !is.na(dois) & nzchar(dois)
  target_mask <- needs_embedding & has_doi

  if (!any(target_mask)) {
    .sm_verbose(
      "All works already have embeddings or have no DOIs; skipping.",
      verbose
    )
    return(corpus)
  }

  target_dois <- dois[target_mask]
  target_ids <- corpus$works$work_id[target_mask]

  .sm_verbose(
    "Fetching SPECTER embeddings for {length(target_dois)} works...",
    verbose
  )

  # Batch fetch via Semantic Scholar batch endpoint
  batch_size <- 100L
  all_embeddings <- list()
  reported <- character()
  failed <- list()

  chunks <- split(seq_along(target_dois),
                  ceiling(seq_along(target_dois) / batch_size))

  for (chunk_idx in chunks) {
    doi_batch <- paste0("DOI:", target_dois[chunk_idx])
    id_batch <- target_ids[chunk_idx]

    result <- tryCatch(
      .s2_perform(.s2_specter_request(doi_batch, api_key)),
      error = function(e) {
        failed[[length(failed) + 1L]] <<- e
        list()
      }
    )

    for (j in seq_along(result)) {
      paper <- result[[j]]
      if (is.null(paper)) next
      emb <- paper[["embedding"]][["vector"]]
      if (is.null(emb)) next
      all_embeddings[[id_batch[j]]] <- as.double(unlist(emb))
      reported <- c(reported, paper[["embedding"]][["model"]])
    }

    .sm_verbose(
      "SPECTER: {max(chunk_idx)} / {length(target_dois)} works processed.",
      verbose
    )
  }

  .s2_warn_failed(failed, length(chunks), key_set = nzchar(api_key),
                  call = call)

  if (length(all_embeddings) == 0) {
    .sm_verbose("No SPECTER embeddings retrieved.", verbose)
    return(corpus)
  }

  # Build embedding matrix
  new_mat <- do.call(rbind, all_embeddings)
  rownames(new_mat) <- names(all_embeddings)
  record <- .s2_embedding_record("specter_v2", reported, new_mat)

  # Merge with existing embeddings of the same model, or of several models
  # when the caller asked for a mix; never drop existing rows silently
  if (keep) {
    if (ncol(new_mat) != ncol(existing)) {
      cli::cli_abort(
        c("Cannot add {ncol(new_mat)}-dimensional SPECTER v2 vectors to
           {ncol(existing)}-dimensional embeddings.",
          "i" = "Use {.code replace = TRUE} to replace the existing
                 embeddings instead."),
        class = "scimapR_embedding_model_mismatch", call = call
      )
    }
    merged <- rbind(existing, new_mat)
    record <- if (same) {
      utils::modifyList(current, list(n_works = nrow(merged)))
    } else {
      .embedding_mixed_record(list(current, record), nrow(merged),
                              ncol(merged))
    }
    corpus$embeddings <- merged
  } else {
    if (has_existing) {
      cli::cli_inform(c(
        "!" = "Replaced {nrow(existing)} row{?s} of
               {(.embedding_describe(current))} by SPECTER v2 vectors for
               {nrow(new_mat)} work{?s}."
      ))
    }
    corpus$embeddings <- new_mat
  }
  corpus$metadata$embedding <- record

  # Provenance: an enrichment, which a rebuild does not replay
  new_prov <- .make_provenance_rows(
    work_ids = names(all_embeddings),
    source_name = "semantic_scholar",
    external_ids = dois[match(names(all_embeddings), corpus$works$work_id)],
    query_text = "enrich_specter",
    engine_name = "native"
  )
  new_prov$kind <- "enrichment"
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)

  .sm_done("Added SPECTER embeddings for {length(all_embeddings)} works.")
  corpus
}


#' Model id of Semantic Scholar's SPECTER v2 vectors (the API field)
#' @noRd
.s2_specter_v2_id <- "embedding.specter_v2"

#' Longest wait (seconds) before the one retry after HTTP 429
#' @noRd
.s2_short_wait <- 2

#' Build the batch request for the SPECTER v2 vectors of some DOIs
#' @noRd
.s2_specter_request <- function(ids, api_key = "") {
  req <- httr2::request(
    "https://api.semanticscholar.org/graph/v1/paper/batch"
  ) |>
    httr2::req_url_query(fields = "paperId,embedding.specter_v2") |>
    httr2::req_body_json(list(ids = as.list(ids))) |>
    httr2::req_method("POST") |>
    httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
    httr2::req_throttle(rate = 1 / 1)

  if (nzchar(api_key)) {
    req <- httr2::req_headers(req, `x-api-key` = api_key)
  }
  req
}

#' Perform one Semantic Scholar request, trying once more after HTTP 429
#'
#' Waits the `Retry-After` of the answer, but at most `.s2_short_wait`
#' seconds (1 second when the answer gives none). A second 429, or any
#' other failure, is an error.
#' @return The parsed JSON body.
#' @noRd
.s2_perform <- function(req) {
  resp <- tryCatch(
    httr2::req_perform(req),
    httr2_http_429 = function(cnd) cnd
  )
  if (inherits(resp, "httr2_http_429")) {
    Sys.sleep(.s2_retry_wait(resp$resp))
    resp <- httr2::req_perform(req)
  }
  httr2::resp_body_json(resp)
}

#' Seconds to wait before the retry
#' @noRd
.s2_retry_wait <- function(resp) {
  wait <- tryCatch(
    suppressWarnings(as.numeric(httr2::resp_header(resp, "Retry-After"))),
    error = function(e) NA_real_
  )
  if (length(wait) != 1L || is.na(wait) || wait < 0) wait <- 1
  min(wait, .s2_short_wait)
}

#' One warning for the batches that failed
#' @noRd
.s2_warn_failed <- function(failed, n_batches, key_set = FALSE,
                            call = rlang::caller_env()) {
  n_failed <- length(failed)
  if (n_failed == 0L) return(invisible(NULL))
  rate_limited <- !key_set &&
    any(vapply(failed, inherits, logical(1), what = "httr2_http_429"))
  cli::cli_warn(
    c("{n_failed} of {n_batches} Semantic Scholar request{?s} failed, so
       their works got no SPECTER vector.",
      "x" = "{(.sm_first_line(conditionMessage(failed[[1]])))}",
      if (rate_limited) {
        c("i" = "Semantic Scholar limits requests without an API key
                 more strictly; set {.envvar SEMANTIC_SCHOLAR_API_KEY}.")
      }),
    class = "scimapR_specter_failed", call = call
  )
}

#' The embedding record of vectors from Semantic Scholar
#'
#' @param variant `"specter_v2"` or `"specter_v1"` (the API's default
#'   `embedding` field).
#' @param reported The model versions the API reported for the vectors.
#' @noRd
.s2_embedding_record <- function(variant, reported, emb) {
  reported <- unique(as.character(unlist(reported)))
  reported <- reported[!is.na(reported) & nzchar(reported)]
  .new_embedding_record(
    model = variant,
    model_id = paste0("embedding.", variant),
    backend = "semantic-scholar",
    n_works = nrow(emb),
    n_dimensions = ncol(emb),
    revision = if (length(reported) > 0L) {
      paste(reported, collapse = ", ")
    } else {
      NA_character_
    }
  )
}

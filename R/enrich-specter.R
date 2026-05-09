#' Enrich corpus with SPECTER embeddings
#'
#' @description
#' Fetch pre-computed SPECTER embeddings from the
#' [Semantic Scholar](https://www.semanticscholar.org/) API for works in
#' the corpus and attach them as the `embeddings` matrix.
#'
#' SPECTER embeddings are 768-dimensional vectors useful for computing
#' document similarity, clustering, and visualisation. No Python
#' installation is required -- this function retrieves pre-computed
#' vectors from the API.
#'
#' This enricher is idempotent: works that already have embeddings are
#' skipped.
#'
#' @param corpus An `sm_corpus` object.
#' @param api_key Semantic Scholar API key. Read from
#'   `SEMANTIC_SCHOLAR_API_KEY` env var by default.
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with an `embeddings` matrix, plus new
#'   provenance rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_specter(corpus)
#' }
sm_enrich_specter <- function(corpus,
                              api_key = Sys.getenv("SEMANTIC_SCHOLAR_API_KEY"),
                              verbose = TRUE,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  # Determine which works need embeddings
  existing_ids <- if (!is.null(corpus$embeddings) &&
                      nrow(corpus$embeddings) > 0) {
    rownames(corpus$embeddings)
  } else {
    character()
  }

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

  chunks <- split(seq_along(target_dois),
                  ceiling(seq_along(target_dois) / batch_size))

  for (chunk_idx in chunks) {
    doi_batch <- paste0("DOI:", target_dois[chunk_idx])
    id_batch <- target_ids[chunk_idx]

    result <- tryCatch({
      req <- httr2::request(
        "https://api.semanticscholar.org/graph/v1/paper/batch"
      ) |>
        httr2::req_url_query(fields = "paperId,embedding") |>
        httr2::req_body_json(list(ids = as.list(doi_batch))) |>
        httr2::req_method("POST") |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 1 / 1)

      if (nzchar(api_key)) {
        req <- httr2::req_headers(req, `x-api-key` = api_key)
      }

      resp <- httr2::req_perform(req)
      httr2::resp_body_json(resp)
    }, error = function(e) {
      if (verbose) {
        .sm_warn("SPECTER batch request failed: {conditionMessage(e)}")
      }
      list()
    })

    for (j in seq_along(result)) {
      paper <- result[[j]]
      if (is.null(paper)) next
      emb <- paper[["embedding"]][["vector"]]
      if (is.null(emb)) next
      all_embeddings[[id_batch[j]]] <- as.double(emb)
    }

    if (verbose) {
      .sm_verbose(
        "SPECTER: {max(chunk_idx)} / {length(target_dois)} works processed.",
        verbose
      )
    }
  }

  if (length(all_embeddings) == 0) {
    .sm_verbose("No SPECTER embeddings retrieved.", verbose)
    return(corpus)
  }

  # Build embedding matrix
  new_mat <- do.call(rbind, all_embeddings)
  rownames(new_mat) <- names(all_embeddings)

  # Merge with existing embeddings
  if (!is.null(corpus$embeddings) && nrow(corpus$embeddings) > 0) {
    # Ensure same dimensions
    if (ncol(new_mat) == ncol(corpus$embeddings)) {
      corpus$embeddings <- rbind(corpus$embeddings, new_mat)
    } else {
      .sm_warn(
        "Embedding dimensions differ ({ncol(corpus$embeddings)} vs {ncol(new_mat)}); replacing existing embeddings."
      )
      corpus$embeddings <- new_mat
    }
  } else {
    corpus$embeddings <- new_mat
  }

  # Provenance
  new_prov <- .make_provenance_rows(
    work_ids = names(all_embeddings),
    source_name = "semantic_scholar",
    external_ids = dois[match(names(all_embeddings), corpus$works$work_id)],
    query_text = "enrich_specter",
    engine_name = "native"
  )
  corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)

  .sm_done("Added SPECTER embeddings for {length(all_embeddings)} works.")
  corpus
}

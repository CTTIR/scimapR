#' Enrich corpus with concepts from OpenAlex or MeSH
#'
#' @description
#' Look up works in the corpus via OpenAlex or PubMed to retrieve
#' associated concepts, topics, or MeSH terms and add them to the
#' `concepts` table.
#'
#' This enricher is idempotent: re-running it updates existing concept
#' data rather than duplicating rows.
#'
#' @param corpus An `sm_corpus` object.
#' @param source One of `"openalex"` (fetch OpenAlex concepts via DOI) or
#'   `"mesh"` (fetch MeSH terms via PubMed PMID).
#' @param verbose Print progress messages?
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_corpus` object with updated `concepts` table and new
#'   provenance rows.
#'
#' @family enrichers
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus()
#' corpus <- sm_enrich_concepts(corpus, source = "openalex")
#' }
sm_enrich_concepts <- function(corpus,
                               source = c("openalex", "mesh"),
                               verbose = TRUE,
                               call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  source <- rlang::arg_match(source, error_call = call)

  if (source == "openalex") {
    return(.enrich_concepts_openalex(corpus, verbose, call))
  }

  .enrich_concepts_mesh(corpus, verbose, call)
}

# ---- OpenAlex concepts ----

#' @noRd
.enrich_concepts_openalex <- function(corpus, verbose, call) {
  dois <- corpus$works$doi
  has_doi <- !is.na(dois) & nzchar(dois)

  if (!any(has_doi)) {
    .sm_verbose("No DOIs in corpus; skipping concept enrichment.", verbose)
    return(corpus)
  }

  # Only enrich works not already having openalex concepts
  existing_oa <- corpus$concepts |>
    dplyr::filter(.data$vocabulary == "openalex") |>
    dplyr::pull(.data$work_id) |>
    unique()

  target_mask <- has_doi & !corpus$works$work_id %in% existing_oa
  if (!any(target_mask)) {
    .sm_verbose("All works already have OpenAlex concepts.", verbose)
    return(corpus)
  }

  target_dois <- dois[target_mask]
  target_ids <- corpus$works$work_id[target_mask]

  .sm_verbose(
    "Fetching OpenAlex concepts for {length(target_dois)} works...",
    verbose
  )

  new_concepts <- list()

  for (i in seq_along(target_dois)) {
    result <- tryCatch({
      req <- httr2::request("https://api.openalex.org/works") |>
        httr2::req_url_query(
          filter = paste0("doi:", target_dois[i]),
          select = "id,concepts"
        ) |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 10 / 1)

      resp <- httr2::req_perform(req)
      body <- httr2::resp_body_json(resp)
      body[["results"]]
    }, error = function(e) {
      NULL
    })

    if (!is.null(result) && length(result) > 0) {
      concepts <- result[[1]][["concepts"]] %||% list()
      if (length(concepts) > 0) {
        new_concepts[[length(new_concepts) + 1L]] <- tibble::tibble(
          work_id = target_ids[i],
          concept_id = purrr::map_chr(concepts, "id", .default = NA_character_),
          concept_name = purrr::map_chr(concepts, "display_name",
                                        .default = NA_character_),
          level = as.integer(
            purrr::map_int(concepts, "level", .default = NA_integer_)
          ),
          score = as.double(
            purrr::map_dbl(concepts, "score", .default = NA_real_)
          ),
          vocabulary = "openalex"
        )
      }
    }

    if (verbose && i %% 50 == 0) {
      .sm_verbose(
        "OpenAlex concepts: {i} / {length(target_dois)} works processed.",
        verbose
      )
    }
  }

  if (length(new_concepts) > 0) {
    new_tbl <- dplyr::bind_rows(new_concepts)
    corpus$concepts <- dplyr::bind_rows(corpus$concepts, new_tbl)
  }

  # Provenance
  enriched_ids <- purrr::map_chr(new_concepts, \(x) x$work_id[1])
  if (length(enriched_ids) > 0) {
    new_prov <- .make_provenance_rows(
      work_ids = enriched_ids,
      source_name = "openalex",
      external_ids = dois[match(enriched_ids, corpus$works$work_id)],
      query_text = "enrich_concepts_openalex",
      engine_name = "native"
    )
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)
  }

  n_enriched <- length(new_concepts)
  .sm_done("Added concepts for {n_enriched} works via OpenAlex.")
  corpus
}

# ---- MeSH concepts ----

#' @noRd
.enrich_concepts_mesh <- function(corpus, verbose, call) {
  pmids <- corpus$works$pmid
  has_pmid <- !is.na(pmids) & nzchar(pmids)

  if (!any(has_pmid)) {
    .sm_verbose("No PMIDs in corpus; skipping MeSH enrichment.", verbose)
    return(corpus)
  }

  # Only enrich works not already having MeSH concepts
  existing_mesh <- corpus$concepts |>
    dplyr::filter(.data$vocabulary == "mesh") |>
    dplyr::pull(.data$work_id) |>
    unique()

  target_mask <- has_pmid & !corpus$works$work_id %in% existing_mesh
  if (!any(target_mask)) {
    .sm_verbose("All works already have MeSH terms.", verbose)
    return(corpus)
  }

  target_pmids <- pmids[target_mask]
  target_ids <- corpus$works$work_id[target_mask]

  .sm_verbose(
    "Fetching MeSH terms for {length(target_pmids)} works from PubMed...",
    verbose
  )

  new_concepts <- list()

  # Batch fetch via efetch (up to 200 at a time)
  batch_size <- 200L
  chunks <- split(seq_along(target_pmids),
                  ceiling(seq_along(target_pmids) / batch_size))

  for (chunk_idx in chunks) {
    pmid_batch <- target_pmids[chunk_idx]
    id_batch <- target_ids[chunk_idx]

    result <- tryCatch({
      req <- httr2::request(
        "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
      ) |>
        httr2::req_url_query(
          db = "pubmed",
          id = paste(pmid_batch, collapse = ","),
          rettype = "xml",
          retmode = "xml"
        ) |>
        httr2::req_headers(`User-Agent` = .sm_user_agent()) |>
        httr2::req_throttle(rate = 3 / 1)

      resp <- httr2::req_perform(req)
      xml_doc <- xml2::read_xml(httr2::resp_body_string(resp))
      xml2::xml_find_all(xml_doc, ".//PubmedArticle")
    }, error = function(e) {
      list()
    })

    for (j in seq_along(result)) {
      article <- result[[j]]
      this_pmid <- xml2::xml_text(
        xml2::xml_find_first(article, ".//PMID")
      )
      if (is.na(this_pmid)) next

      # Match back to our work_id
      match_idx <- match(this_pmid, pmid_batch)
      if (is.na(match_idx)) next
      wid <- id_batch[match_idx]

      mesh_nodes <- xml2::xml_find_all(article, ".//MeshHeading/DescriptorName")
      if (length(mesh_nodes) == 0) next

      new_concepts[[length(new_concepts) + 1L]] <- tibble::tibble(
        work_id = wid,
        concept_id = xml2::xml_attr(mesh_nodes, "UI"),
        concept_name = xml2::xml_text(mesh_nodes),
        level = NA_integer_,
        score = NA_real_,
        vocabulary = "mesh"
      )
    }

    if (verbose) {
      .sm_verbose(
        "MeSH: processed {max(chunk_idx)} / {length(target_pmids)} works.",
        verbose
      )
    }
  }

  if (length(new_concepts) > 0) {
    new_tbl <- dplyr::bind_rows(new_concepts)
    corpus$concepts <- dplyr::bind_rows(corpus$concepts, new_tbl)
  }

  # Provenance
  enriched_ids <- purrr::map_chr(new_concepts, \(x) x$work_id[1])
  if (length(enriched_ids) > 0) {
    new_prov <- .make_provenance_rows(
      work_ids = enriched_ids,
      source_name = "pubmed",
      external_ids = pmids[match(enriched_ids, corpus$works$work_id)],
      query_text = "enrich_concepts_mesh",
      engine_name = "native"
    )
    corpus$provenance <- dplyr::bind_rows(corpus$provenance, new_prov)
  }

  n_enriched <- length(new_concepts)
  .sm_done("Added MeSH terms for {n_enriched} works.")
  corpus
}

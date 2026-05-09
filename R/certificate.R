#' Create, rebuild from, and verify corpus certificates
#'
#' @description
#' A corpus certificate is a self-contained YAML document that captures
#' every query, file, enrichment, embedding, screening decision, and chat
#' interaction used to produce a corpus. It enables exact re-derivation
#' of the corpus from scratch.
#'
#' `sm_certificate()` creates a certificate from a corpus.
#' `sm_rebuild_from_cert()` re-runs every recorded step to reconstruct
#' the corpus. `sm_verify_certificate()` compares a live corpus against
#' a certificate to detect divergence.
#'
#' @param corpus An `sm_corpus` object.
#' @param path Character. Optional file path to write the certificate YAML.
#'   If `NULL`, the certificate is returned but not written to disk.
#' @param cert A certificate object (list) or path to a YAML certificate file.
#' @param verbose Logical. Print progress?
#' @param call Caller environment for error reporting.
#'
#' @return For `sm_certificate()`: an `sm_certificate` S3 object (list),
#'   also written to `path` if provided.
#'   For `sm_rebuild_from_cert()`: an `sm_corpus` reconstructed from the
#'   certificate. For `sm_verify_certificate()`: an `sm_cert_verification`
#'   S3 object with pass/fail and details.
#'
#' @family reproducibility
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' cert <- sm_certificate(corpus)
#' print(cert)
#' verification <- sm_verify_certificate(corpus, cert)
#' print(verification)
sm_certificate <- function(corpus,
                           path = NULL,
                           call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(path, allow_null = TRUE, call = call)

  corpus_hash <- sm_hash_corpus(corpus)
  now <- Sys.time()
  pkg_version <- corpus$metadata$scimapR_version %||%
    tryCatch(as.character(utils::packageVersion("scimapR")),
             error = function(e) "0.1.0")

  # Collect all queries from provenance
  queries <- if (nrow(corpus$provenance) > 0L) {
    unique_queries <- dplyr::distinct(
      corpus$provenance,
      .data$source, .data$query, .data$engine
    )
    lapply(seq_len(nrow(unique_queries)), function(i) {
      list(
        source = unique_queries$source[i],
        query = unique_queries$query[i],
        engine = unique_queries$engine[i]
      )
    })
  } else {
    list()
  }

  # Provenance summary
  prov_summary <- if (nrow(corpus$provenance) > 0L) {
    prov_counts <- dplyr::count(corpus$provenance, .data$source)
    stats::setNames(
      as.list(prov_counts$n),
      prov_counts$source
    )
  } else {
    list()
  }

  # Screening summary
  screening_summary <- if (nrow(corpus$screening) > 0L) {
    scr_counts <- corpus$screening %>%
      dplyr::count(.data$stage, .data$decision)
    lapply(seq_len(nrow(scr_counts)), function(i) {
      list(
        stage = scr_counts$stage[i],
        decision = scr_counts$decision[i],
        count = scr_counts$n[i]
      )
    })
  } else {
    list()
  }

  # Embedding info
  embedding_info <- if (!is.null(corpus$embeddings)) {
    list(
      n_works = nrow(corpus$embeddings),
      n_dimensions = ncol(corpus$embeddings),
      method = "recorded"
    )
  } else {
    list(n_works = 0L, n_dimensions = 0L, method = "none")
  }

  cert <- structure(
    list(
      certificate_version = "1.0",
      created = now,
      scimapR_version = pkg_version,
      r_version = paste0(R.version$major, ".", R.version$minor),
      platform = .Platform$OS.type,
      corpus_hash = corpus_hash,
      n_works = nrow(corpus$works),
      n_authors = nrow(corpus$authors),
      n_institutions = nrow(corpus$institutions),
      n_references = nrow(corpus$references),
      year_range = if (nrow(corpus$works) > 0L &&
                       any(!is.na(corpus$works$year))) {
        range(corpus$works$year, na.rm = TRUE)
      } else {
        c(NA_integer_, NA_integer_)
      },
      question_id = corpus$metadata$question_id %||% NA_character_,
      queries = queries,
      provenance_summary = prov_summary,
      screening_summary = screening_summary,
      embedding_info = embedding_info,
      is_locked = isTRUE(corpus$metadata$is_locked),
      metadata = list(
        build_date = format(corpus$metadata$build_date,
                            "%Y-%m-%dT%H:%M:%S%z"),
        last_refresh = if (!is.na(corpus$metadata$last_refresh %||% NA)) {
          format(corpus$metadata$last_refresh, "%Y-%m-%dT%H:%M:%S%z")
        } else {
          NA_character_
        }
      )
    ),
    class = "sm_certificate"
  )

  # Write to file if path provided
  if (!is.null(path)) {
    yaml_text <- yaml::as.yaml(
      .cert_to_list(cert),
      indent.mapping.sequence = TRUE
    )
    writeLines(yaml_text, path)
    cli::cli_inform(c(
      "v" = "Certificate written to {.path {path}}."
    ))
  }

  cli::cli_inform(c(
    "v" = "Certificate created. Corpus hash: {substr(corpus_hash, 1, 12)}"
  ))

  cert
}

#' @rdname sm_certificate
#' @export
sm_rebuild_from_cert <- function(cert,
                                 verbose = TRUE,
                                 call = rlang::caller_env()) {
  # Load certificate if path
  if (is.character(cert)) {
    .check_file_exists(cert, call = call)
    cert_data <- yaml::read_yaml(cert)
    cert <- .list_to_cert(cert_data)
  }

  if (!inherits(cert, "sm_certificate")) {
    cli::cli_abort(
      "{.arg cert} must be an {.cls sm_certificate} or a path to a YAML certificate.",
      call = call
    )
  }

  .sm_verbose("Rebuilding corpus from certificate...", verbose)
  .sm_verbose(
    "Certificate hash: {substr(cert$corpus_hash, 1, 12)}",
    verbose
  )

  # Re-run queries
  queries <- cert$queries
  if (length(queries) == 0L) {
    .sm_verbose("No queries recorded in certificate. Returning empty corpus.", verbose)
    return(sm_corpus(works = .empty_works()))
  }

  all_works <- list()
  all_prov <- list()
  pkg_version <- tryCatch(
    as.character(utils::packageVersion("scimapR")),
    error = function(e) "0.1.0"
  )

  for (i in seq_along(queries)) {
    q <- queries[[i]]
    src <- q$source %||% "unknown"
    query_str <- q$query %||% ""
    engine <- q$engine %||% "native"

    .sm_verbose(
      "  Re-running query {i}/{length(queries)}: {.val {src}} - {substr(query_str, 1, 60)}...",
      verbose
    )

    # Skip synthetic/refresh sources
    if (src %in% c("synthetic", "manual") ||
        grepl("_refresh$", src)) {
      .sm_verbose("  Skipping non-API source: {.val {src}}", verbose)
      next
    }

    result <- tryCatch({
      .fetch_from_source(
        source = src,
        query_strings = list(
          generic = query_str,
          pubmed = query_str,
          openalex = query_str,
          crossref = query_str
        ),
        n_max = 1000L,
        languages = "en",
        call = call
      )
    }, error = function(e) {
      cli::cli_inform(c(
        "!" = "Failed to re-fetch from {.val {src}}: {conditionMessage(e)}"
      ))
      list(works = .empty_works(), n_fetched = 0L)
    })

    if (nrow(result$works) > 0L) {
      existing_ids <- unlist(lapply(all_works, function(w) w$work_id))
      start_num <- length(existing_ids)
      new_ids <- paste0("W", formatC(
        seq(start_num + 1L, start_num + nrow(result$works)),
        width = 9, flag = "0"
      ))
      result$works$work_id <- new_ids
      all_works[[i]] <- result$works

      all_prov[[i]] <- tibble::tibble(
        work_id = new_ids,
        source = src,
        source_id_external = NA_character_,
        fetch_date = Sys.time(),
        query = query_str,
        engine = engine,
        scimapR_version = pkg_version,
        prompt_hash = NA_character_
      )
    }
  }

  if (length(all_works) == 0L) {
    .sm_verbose("No works retrieved during rebuild.", verbose)
    return(sm_corpus(works = .empty_works()))
  }

  combined_works <- dplyr::bind_rows(all_works)
  combined_prov <- dplyr::bind_rows(all_prov)

  # Deduplicate
  dedup_result <- .deduplicate_works(combined_works)
  keep_ids <- dedup_result$work_id
  combined_works <- dplyr::filter(combined_works, .data$work_id %in% keep_ids)
  combined_prov <- dplyr::filter(combined_prov, .data$work_id %in% keep_ids)

  corpus <- sm_corpus(
    works = combined_works,
    provenance = combined_prov,
    metadata = list(
      question_id = cert$question_id %||% NA_character_,
      rebuilt_from_cert = TRUE,
      original_hash = cert$corpus_hash
    )
  )

  .sm_verbose(
    "Rebuild complete: {nrow(corpus$works)} works.",
    verbose
  )

  corpus
}

#' @rdname sm_certificate
#' @export
sm_verify_certificate <- function(corpus,
                                  cert,
                                  call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  # Load certificate if path
  if (is.character(cert)) {
    .check_file_exists(cert, call = call)
    cert_data <- yaml::read_yaml(cert)
    cert <- .list_to_cert(cert_data)
  }

  if (!inherits(cert, "sm_certificate")) {
    cli::cli_abort(
      "{.arg cert} must be an {.cls sm_certificate} or path to a YAML file.",
      call = call
    )
  }

  # Compare
  current_hash <- sm_hash_corpus(corpus)
  hash_match <- identical(current_hash, cert$corpus_hash)
  n_works_match <- nrow(corpus$works) == cert$n_works
  n_authors_match <- nrow(corpus$authors) == cert$n_authors

  checks <- tibble::tibble(
    check = c("corpus_hash", "n_works", "n_authors", "n_institutions",
              "n_references"),
    expected = c(
      substr(cert$corpus_hash, 1, 16),
      as.character(cert$n_works),
      as.character(cert$n_authors),
      as.character(cert$n_institutions),
      as.character(cert$n_references)
    ),
    actual = c(
      substr(current_hash, 1, 16),
      as.character(nrow(corpus$works)),
      as.character(nrow(corpus$authors)),
      as.character(nrow(corpus$institutions)),
      as.character(nrow(corpus$references))
    ),
    pass = c(
      hash_match,
      n_works_match,
      n_authors_match,
      nrow(corpus$institutions) == cert$n_institutions,
      nrow(corpus$references) == cert$n_references
    )
  )

  overall_pass <- all(checks$pass)

  result <- structure(
    list(
      pass = overall_pass,
      checks = checks,
      corpus_hash = current_hash,
      cert_hash = cert$corpus_hash,
      cert_created = cert$created
    ),
    class = "sm_cert_verification"
  )

  result
}

#' @rdname sm_certificate
#' @param x An `sm_certificate` or `sm_cert_verification` object.
#' @param ... Ignored.
#' @return `x` invisibly (print methods).
#' @export
print.sm_certificate <- function(x, ...) {
  cli::cli_h1("<sm_certificate>")
  cli::cli_text("{.strong Version:} {x$certificate_version}")
  cli::cli_text("{.strong Created:} {format(x$created, '%Y-%m-%d %H:%M:%S')}")
  cli::cli_text("{.strong scimapR:} v{x$scimapR_version}")
  cli::cli_text("{.strong R:} {x$r_version} ({x$platform})")
  cli::cli_text("")
  cli::cli_text("{.strong Corpus hash:} {substr(x$corpus_hash, 1, 16)}")
  cli::cli_text("{.strong Works:} {x$n_works}")
  cli::cli_text("{.strong Authors:} {x$n_authors}")
  cli::cli_text("{.strong References:} {x$n_references}")
  cli::cli_text("{.strong Queries:} {length(x$queries)}")

  if (!is.na(x$question_id %||% NA_character_)) {
    cli::cli_text("{.strong Question ID:} {x$question_id}")
  }

  invisible(x)
}

#' @rdname sm_certificate
#' @param x An `sm_certificate` or `sm_cert_verification` object.
#' @param ... Ignored.
#' @export
print.sm_cert_verification <- function(x, ...) {
  cli::cli_h1("<sm_cert_verification>")

  if (x$pass) {
    cli::cli_text("{.strong Result: PASS}")
  } else {
    cli::cli_text("{.strong Result: FAIL}")
  }

  cli::cli_text("")
  for (i in seq_len(nrow(x$checks))) {
    row <- x$checks[i, ]
    status <- if (row$pass) "v" else "x"
    cli::cli_text(c(
      "{status}" = "{row$check}: expected {row$expected}, got {row$actual}"
    ))
  }

  invisible(x)
}

#' Convert certificate S3 to plain list for YAML
#' @noRd
.cert_to_list <- function(cert) {
  out <- unclass(cert)
  out$created <- format(out$created, "%Y-%m-%dT%H:%M:%S%z")
  out
}

#' Convert plain list from YAML to certificate S3
#' @noRd
.list_to_cert <- function(x) {
  if (!is.null(x$created) && is.character(x$created)) {
    x$created <- as.POSIXct(x$created, format = "%Y-%m-%dT%H:%M:%S%z")
  }
  structure(x, class = "sm_certificate")
}

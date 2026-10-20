#' Create, rebuild from, and verify corpus certificates
#'
#' @description
#' A corpus certificate is a self-contained YAML document that records how
#' a corpus was made and lets others check it: the corpus hash
#' ([sm_hash_corpus()]) and the size of its tables, the steps recorded in
#' its provenance (searches, file reads, enrichments and refreshes), a
#' summary of its screening decisions, its embeddings and their model, and
#' the local input files registered with [sm_register_input()], each with
#' its SHA-256 hash.
#'
#' `sm_certificate()` creates a certificate from a corpus.
#' `sm_verify_certificate()` compares a live corpus, and its local input
#' files, against a certificate to detect divergence.
#' `sm_rebuild_from_cert()` runs the recorded searches again (see
#' "Rebuilding a corpus"); file reads and local inputs cannot be replayed,
#' and verification checks them instead.
#'
#' Each recorded step (`queries`) has a `source`, `query`, `engine` and
#' `kind`: `"api_query"` for searches of a bibliographic API, `"file"` for
#' records read from a local file (the file relative to the working
#' directory when it lies below it, else its name), `"enrichment"` for
#' steps such as [sm_enrich_openalex_impact()] that added fields to works
#' already in the corpus, `"refresh"` for [sm_refresh()] and `"manual"`
#' for synthetic records. The searches of [sm_fetch_openalex()],
#' [sm_fetch_pubmed()], [sm_fetch_crossref()] and
#' [sm_corpus_for_question()] also record their `filter` and `n_max`. The
#' kind comes from the provenance column `kind`, else (for corpora and
#' certificates written before kinds were recorded) from the source label,
#' the query and the engine (see [sm_provenance()]).
#'
#' @section Local inputs:
#' The `local_inputs` block lists the files of `metadata$local_inputs`
#' ([sm_register_input()]) with their `path`, `path_abs`, `root`,
#' `basename`, `sha256`, `bytes`, `role`, `builder` and `registered_at`.
#' It is a tibble in the certificate object, with no rows when no file is
#' registered, and a list with one entry per file in the YAML file.
#'
#' `sm_verify_certificate()` adds one check per file, named
#' `input:<basename>` (`input:<path>` when files share a name). It looks
#' for a file with a relative `path` in `base_dir`, then in the folder of
#' the certificate file (when `cert` is a path), then in the working
#' directory, and last at `path_abs`; a file with an absolute `path` is
#' looked for there and at `path_abs`. The first file found is hashed
#' again, its check passes when the hash is the recorded one, and the
#' check's `location` says where it was found. A file found nowhere is not
#' checked, and the function warns (class `scimapR_cert_inputs_missing`),
#' naming the files and the folders searched, because a verification run
#' from the wrong folder would otherwise pass without a word.
#'
#' @section Verification results:
#' `checks` has one row per check, with the columns `check`, `expected`,
#' `actual` (for a local input the first 16 characters of the hashes, or
#' `"missing"`), `pass`, `status` and `location`. `status` (character) is
#' `"pass"`, `"fail"` or `"not checked"`; `pass` is `TRUE`, `FALSE`, or
#' `NA` for a check that was not made. The overall `pass` is `TRUE` unless
#' a check failed, so it can be `TRUE` while `n_not_checked` counts checks
#' that were not made. The corpus hash is computed with the
#' `hash_version` the certificate records, or with version 1 for
#' certificates written before scimapR 0.5.0 (see [sm_hash_corpus()]).
#'
#' @section Rebuilding a corpus:
#' `sm_rebuild_from_cert()` replays the `"api_query"` steps of OpenAlex,
#' PubMed and Crossref with the fetcher of their source
#' ([sm_fetch_openalex()], [sm_fetch_pubmed()] or [sm_fetch_crossref()]),
#' the engine they were made with and the recorded `filter` and `n_max`.
#' The searches of [sm_corpus_for_question()] record the client package
#' that ran them (openalexR, rentrez or rcrossref) as their engine. A step
#' without `n_max`, as in certificates of earlier versions, fetches up to
#' the number of works of the certified corpus, with a message. The other
#' steps (file reads, enrichments, refreshes, synthetic records and
#' searches of other sources) and the local inputs cannot be replayed, and
#' a message of class `scimapR_cert_not_replayed` names them. When a
#' certificate has no search to replay but records file reads or local
#' inputs, the function stops instead, with an error of class
#' `scimapR_cert_not_replayable` that lists them, with the role, hash and
#' builder of each local input. Without a search to replay, file reads or
#' local inputs (only synthetic records, enrichments, refreshes or searches
#' of other sources, or no step at all), it returns an empty corpus.
#'
#' The rebuilt corpus holds the works of the replayed searches, without
#' duplicate DOIs and with new work ids, and their provenance; its other
#' tables are empty. It shows what the recorded searches find today, so
#' it does not pass [sm_verify_certificate()]: its hash and table sizes
#' differ from those of the certified corpus.
#'
#' @details
#' Certificates write their timestamps (`created`, the corpus's
#' `build_date` and `last_refresh`, and the `registered_at` of each local
#' input) in UTC as ISO 8601 text, for example `2026-10-17T11:45:00Z`, and
#' read back both this form and the older one with a numeric offset.
#' Printing a certificate shows `created` in UTC as well, so a certificate
#' read back from YAML prints the same time as the one it was written from.
#' The corpus timestamps may be stored as POSIXct, a Date, numeric seconds
#' since 1970-01-01 UTC (as in corpora restored from tables) or ISO 8601
#' text. A missing or implausible value is written as `NA`.
#'
#' `embedding_info` describes `corpus$embeddings`: its size (`n_works`,
#' `n_dimensions`) and, from the record in `corpus$metadata$embedding`
#' (see [sm_corpus()]), the model behind it: `model`, `model_id`,
#' `base_model_id`, `revision`, `base_revision`, `text`, `prefix`,
#' `models`, `versions` and `created`. `method` names how the embeddings
#' were made: `"sentence-transformers"` or `"adapters"` ([sm_embed_works()]),
#' `"semantic-scholar"` ([sm_enrich_specter()],
#' [sm_fetch_semantic_scholar()]) or `"mixed"` for rows of several models;
#' it is `"unknown"` for embeddings without a record that fits them (such
#' as embeddings made by earlier versions of scimapR, or a matrix replaced
#' by hand) and `"none"` when the corpus has no embeddings. In these two
#' cases `model` and `model_id` say the same.
#'
#' @param corpus An `sm_corpus` object.
#' @param path Character. Optional file path to write the certificate YAML.
#'   If `NULL`, the certificate is returned but not written to disk.
#' @param cert A certificate object (list) or path to a YAML certificate file.
#' @param base_dir `NULL` or the folder that the relative paths of the
#'   local inputs are relative to; looked in first. See "Local inputs".
#' @param verbose Logical. Print progress?
#' @param call Caller environment for error reporting.
#'
#' @return For `sm_certificate()`: an `sm_certificate` S3 object (list),
#'   also written to `path` if provided.
#'   For `sm_rebuild_from_cert()`: an `sm_corpus` with the works of the
#'   replayed searches. For `sm_verify_certificate()`: an
#'   `sm_cert_verification` S3 object, a list with `pass`, `checks`,
#'   `n_not_checked`, `corpus_hash` (computed with the certificate's hash
#'   version), `cert_hash`, `cert_created` and `hash_version`.
#'
#' @family reproducibility
#' @export
#' @examplesIf requireNamespace("yaml", quietly = TRUE)
#' corpus <- sm_example_corpus()
#' tracker <- tempfile(fileext = ".csv")
#' writeLines(c("doi,unit", "10.9999/example.1,Unit A"), tracker)
#' corpus <- sm_register_input(corpus, tracker, role = "publication tracker")
#' cert <- sm_certificate(corpus)
#' print(cert)
#' verification <- sm_verify_certificate(corpus, cert)
#' print(verification)
#'
#' # a changed input file fails its check
#' cat("10.9999/example.2,Unit B\n", file = tracker, append = TRUE)
#' sm_verify_certificate(corpus, cert)$pass
sm_certificate <- function(corpus,
                           path = NULL,
                           call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(path, allow_null = TRUE, call = call)
  rlang::check_installed("yaml", reason = "to create corpus certificates.")

  corpus_hash <- sm_hash_corpus(corpus)
  now <- Sys.time()
  pkg_version <- corpus$metadata$scimapR_version %||%
    tryCatch(as.character(utils::packageVersion("scimapR")),
             error = function(e) "0.1.0")

  # Collect all steps from provenance, with the kind of each step
  queries <- .cert_queries(corpus$provenance)

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

  # Embedding info: the matrix and the record of its model
  embedding_info <- .cert_embedding_info(corpus)

  cert <- structure(
    list(
      certificate_version = "1.0",
      created = now,
      scimapR_version = pkg_version,
      r_version = paste0(R.version$major, ".", R.version$minor),
      platform = .Platform$OS.type,
      corpus_hash = corpus_hash,
      hash_version = .hash_version,
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
      local_inputs = .as_local_inputs_tbl(corpus$metadata$local_inputs),
      is_locked = isTRUE(corpus$metadata$is_locked),
      metadata = list(
        build_date = .format_utc_time(corpus$metadata$build_date,
                                      what = "metadata$build_date"),
        last_refresh = .format_utc_time(corpus$metadata$last_refresh,
                                        what = "metadata$last_refresh")
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
  cert <- .read_cert(cert, call = call)

  .sm_verbose("Rebuilding corpus from certificate...", verbose)
  .sm_verbose(
    "Certificate hash: {substr(cert$corpus_hash, 1, 12)}",
    verbose
  )

  steps <- .cert_steps(cert$queries)
  inputs <- .as_local_inputs_tbl(cert$local_inputs)
  if (nrow(steps) == 0L && nrow(inputs) == 0L) {
    .sm_verbose(
      "No steps recorded in certificate. Returning empty corpus.", verbose
    )
    return(sm_corpus(works = .empty_works()))
  }

  # Replay searches only: never a file read, an enrichment, a refresh, a
  # manual step or a local input
  replay <- steps[steps$replayable, ]
  rest <- steps[!steps$replayable, ]
  if (nrow(replay) == 0L) {
    # A corpus read from files or local inputs cannot be rebuilt: stop.
    # Without them (synthetic records, enrichments, refreshes or searches
    # of other sources only) the rebuilt corpus is empty, as before.
    if (nrow(inputs) > 0L || any(rest$kind == "file")) {
      .abort_not_replayable(rest, inputs, call = call)
    }
    .inform_not_replayed(rest, inputs, replayed = FALSE)
    return(sm_corpus(works = .empty_works()))
  }
  if (nrow(rest) > 0L || nrow(inputs) > 0L) {
    .inform_not_replayed(rest, inputs)
  }
  replay$n_max <- .replay_n_max(replay, cert$n_works)

  all_works <- list()
  all_prov <- list()
  n_done <- 0L
  for (i in seq_len(nrow(replay))) {
    step <- replay[i, ]
    .sm_verbose(
      "  Re-running step {step$step}: {.val {step$source}} -
       {substr(.or_text(step$query, step$filter), 1, 60)}",
      verbose
    )

    result <- tryCatch(
      .replay_step(step, verbose = verbose, call = call),
      error = function(e) {
        cli::cli_inform(c(
          "!" = "Failed to re-fetch step {step$step} from
                 {.val {step$source}}: {conditionMessage(e)}"
        ))
        NULL
      }
    )
    if (is.null(result) || nrow(result$works) == 0L) next

    # new work ids, unique across the replayed steps
    ids <- sprintf("W%09d", n_done + seq_len(nrow(result$works)))
    id_map <- stats::setNames(ids, result$works$work_id)
    result$works$work_id <- ids
    prov <- result$provenance
    prov$work_id <- unname(id_map[prov$work_id])
    all_works[[length(all_works) + 1L]] <- result$works
    all_prov[[length(all_prov) + 1L]] <- prov
    n_done <- n_done + length(ids)
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
                                  base_dir = NULL,
                                  call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(base_dir, allow_null = TRUE, call = call)
  if (!is.null(base_dir) && !dir.exists(base_dir)) {
    cli::cli_abort(
      "{.arg base_dir} must be an existing folder, not {.path {base_dir}}.",
      call = call
    )
  }

  # The folder of a certificate file, before the file becomes an object
  cert_dir <- if (is.character(cert)) .normalize_path(dirname(cert))
  cert <- .read_cert(cert, call = call)

  # Compare, with the hash algorithm the certificate used
  version <- .check_hash_version(
    cert$hash_version %||% 1L,
    what = "The certificate's {.field hash_version}", call = call
  )
  current_hash <- sm_hash_corpus(corpus, version = version)
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
  checks$status <- ifelse(checks$pass, "pass", "fail")
  checks$location <- NA_character_

  inputs <- .verify_local_inputs(
    cert$local_inputs,
    dirs = c(base_dir, cert_dir, getwd())
  )
  checks <- dplyr::bind_rows(checks, inputs)

  result <- structure(
    list(
      pass = !any(checks$status == "fail"),
      checks = checks,
      n_not_checked = sum(checks$status == "not checked"),
      corpus_hash = current_hash,
      cert_hash = cert$corpus_hash,
      cert_created = cert$created,
      hash_version = version
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
  # UTC, as written to YAML, so that a certificate read back prints the same
  created <- .format_utc_time(x$created, "%Y-%m-%d %H:%M:%S UTC",
                              what = "certificate created")
  if (is.na(created)) created <- "unknown"
  cli::cli_h1("<sm_certificate>")
  cli::cli_text("{.strong Version:} {x$certificate_version}")
  cli::cli_text("{.strong Created:} {created}")
  cli::cli_text("{.strong scimapR:} v{x$scimapR_version}")
  cli::cli_text("{.strong R:} {x$r_version} ({x$platform})")
  cli::cli_text("")
  cli::cli_text("{.strong Corpus hash:} {substr(x$corpus_hash, 1, 16)}")
  cli::cli_text("{.strong Works:} {x$n_works}")
  cli::cli_text("{.strong Authors:} {x$n_authors}")
  cli::cli_text("{.strong References:} {x$n_references}")
  cli::cli_text("{.strong Queries:} {length(x$queries)}")
  cli::cli_text(
    "{.strong Local inputs:} {nrow(.as_local_inputs_tbl(x$local_inputs))}"
  )
  emb <- x$embedding_info
  if (isTRUE(emb$n_works > 0)) {
    cli::cli_text(
      "{.strong Embeddings:} {emb$n_works} x {emb$n_dimensions}
       ({.val {emb$model_id %||% 'unknown'}})"
    )
  }

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
  checks <- x$checks
  status <- checks[["status"]] %||%
    ifelse(is.na(checks$pass), "not checked",
           ifelse(checks$pass, "pass", "fail"))
  n_not_checked <- sum(status == "not checked")

  cli::cli_h1("<sm_cert_verification>")

  result <- if (isTRUE(x$pass)) "PASS" else "FAIL"
  if (n_not_checked > 0L) {
    result <- paste0(result, " (", n_not_checked, " not checked)")
  }
  cli::cli_text("{.strong Result: {result}}")

  cli::cli_text("")
  lines <- ifelse(
    status == "not checked",
    paste0(checks$check, ": expected ", checks$expected, ", not found"),
    paste0(checks$check, ": expected ", checks$expected, ", got ",
           checks$actual)
  )
  symbols <- c(pass = "v", fail = "x", "not checked" = "!")[status]
  cli::cli_bullets(stats::setNames(.sm_cli_escape(lines), symbols))

  invisible(x)
}

#' The embeddings of a corpus and the model behind them, for a certificate
#'
#' `n_works` and `n_dimensions` give the size of `corpus$embeddings`; the
#' other entries come from `corpus$metadata$embedding` when it describes
#' the matrix (`.embedding_record()`). `method` is the backend, `"unknown"`
#' for embeddings without such a record and `"none"` without embeddings.
#' @noRd
.cert_embedding_info <- function(corpus) {
  emb <- corpus$embeddings
  none <- is.null(emb) || nrow(emb) == 0L
  rec <- if (none) NULL else .embedding_record(corpus)
  label <- if (none) "none" else "unknown"
  field <- function(x) {
    if (is.character(x) && length(x) == 1L) x else NA_character_
  }
  list(
    n_works = if (none) 0L else nrow(emb),
    n_dimensions = if (none) 0L else ncol(emb),
    method = rec$backend %||% label,
    model = rec$model %||% label,
    model_id = rec$model_id %||% label,
    base_model_id = field(rec$base_model_id),
    revision = field(rec$revision),
    base_revision = field(rec$base_revision),
    text = field(rec$text),
    prefix = field(rec$prefix),
    models = if (is.null(rec)) {
      if (none) character() else "unknown"
    } else {
      as.character(rec$models %||% rec$model_id)
    },
    versions = as.list(rec$versions %||% list()),
    created = if (is.null(rec)) {
      NA_character_
    } else {
      .format_utc_time(rec$created, what = "metadata$embedding$created")
    }
  )
}

#' The steps of a certificate: one per distinct provenance step
#'
#' Each step has `source`, `query`, `engine` and `kind`, and `filter` and
#' `n_max` when the provenance records them. A file step records its file
#' relative to the working directory or by name, never by an absolute path.
#' @noRd
.cert_queries <- function(prov) {
  if (nrow(prov) == 0L) return(list())
  prov$kind <- .provenance_kind(prov$source, prov[["kind"]], prov[["query"]],
                                prov[["engine"]])
  prov$filter <- as.character(prov[["filter"]] %||% NA_character_)
  prov$n_max <- as.integer(prov[["n_max"]] %||% NA_integer_)
  file <- prov$kind == "file"
  prov$query[file] <- .file_step_path(prov$query[file])

  steps <- dplyr::distinct(
    prov,
    .data$source, .data$query, .data$engine, .data$kind, .data$filter,
    .data$n_max
  )
  lapply(seq_len(nrow(steps)), function(i) {
    step <- list(
      source = steps$source[i],
      query = steps$query[i],
      engine = steps$engine[i],
      kind = steps$kind[i]
    )
    if (!is.na(steps$filter[i])) step$filter <- steps$filter[i]
    if (!is.na(steps$n_max[i])) step$n_max <- steps$n_max[i]
    step
  })
}

#' The steps of a certificate as a table, and whether each can be replayed
#'
#' A step is replayed when its kind is `"api_query"`, its source one of
#' `.replay_sources` and it records a query (or, outside PubMed, a filter).
#' Certificates written before kinds were recorded get the kind of their
#' source, query and engine (`.provenance_kind()`).
#' @noRd
.cert_steps <- function(queries) {
  queries <- if (is.list(queries)) queries else list()
  field <- function(name, as_type = as.character) {
    out <- lapply(queries, function(q) {
      value <- if (is.list(q)) q[[name]] else NULL
      if (is.null(value) || length(value) == 0L) NA else value[[1]]
    })
    suppressWarnings(as_type(unlist(out) %||% character()))
  }
  source <- field("source")
  query <- field("query")
  engine <- field("engine")
  filter <- field("filter")
  kind <- .provenance_kind(source, field("kind"), query, engine)

  given <- function(x) !is.na(x) & nzchar(x)
  has_request <- given(query) | (given(filter) & source != "pubmed")
  replay_source <- source %in% .replay_sources
  replayable <- kind == "api_query" & replay_source & has_request

  reason <- rep(NA_character_, length(source))
  reason[kind == "file"] <- "records read from a local file"
  reason[kind == "enrichment"] <-
    "an enrichment of works already in the corpus"
  reason[kind == "refresh"] <- "a refresh of works already in the corpus"
  reason[kind == "manual"] <- "synthetic or hand-made records"
  reason[kind == "api_query" & !replay_source] <-
    "a search of a source that cannot be replayed"
  reason[kind == "api_query" & replay_source & !has_request] <-
    "a search without a recorded query"
  reason[is.na(reason) & !replayable] <- paste0("a step of kind \"",
                                                kind[is.na(reason) &
                                                       !replayable], "\"")

  tibble::tibble(
    step = seq_along(source),
    source = source,
    query = query,
    engine = engine,
    kind = kind,
    filter = filter,
    n_max = field("n_max", as.integer),
    replayable = replayable,
    reason = reason
  )
}

#' The n_max of each replayed step: the recorded one, else the number of
#' works of the certified corpus (with a message), else the fetcher default
#' @noRd
.replay_n_max <- function(steps, n_works) {
  n_max <- steps$n_max
  missing <- is.na(n_max)
  if (!any(missing)) return(n_max)
  n_works <- suppressWarnings(as.integer(n_works %||% NA_integer_))
  if (length(n_works) != 1L || is.na(n_works) || n_works < 1L) {
    return(n_max)
  }
  cli::cli_inform(c(
    "i" = "{sum(missing)} search{?es} recorded without {.arg n_max} (as in
           certificates of earlier versions of scimapR)
           {cli::qty(sum(missing))}fetch{?es/} up to {n_works} work{?s},
           the size of the certified corpus."
  ))
  n_max[missing] <- n_works
  n_max
}

#' Run one recorded search again with the fetcher that made it
#' @noRd
.replay_step <- function(step, verbose = TRUE, call = rlang::caller_env()) {
  value <- function(x) if (is.na(x) || !nzchar(x)) NULL else x
  engine <- function(choices) {
    if (isTRUE(step$engine %in% choices)) step$engine else "native"
  }
  args <- list(query = value(step$query), verbose = verbose, call = call)
  if (!is.na(step$n_max)) args$n_max <- step$n_max
  switch(
    step$source,
    openalex = do.call(sm_fetch_openalex, c(args, list(
      filter = value(step$filter), engine = engine(c("native", "openalexR"))
    ))),
    pubmed = do.call(sm_fetch_pubmed, c(args, list(
      engine = engine(c("native", "rentrez"))
    ))),
    crossref = do.call(sm_fetch_crossref, c(args, list(
      filter = value(step$filter), engine = engine(c("native", "rcrossref"))
    )))
  )
}

#' Text, or `alt` where it is missing or empty
#' @noRd
.or_text <- function(x, alt) {
  ifelse(is.na(x) | !nzchar(x), alt, x)
}

#' One line per step that is not replayed, for messages
#' @noRd
.step_lines <- function(steps) {
  if (nrow(steps) == 0L) return(character())
  text <- .or_text(.or_text(steps$query, steps$filter), "")
  text <- ifelse(nchar(text) > 60L, paste0(substr(text, 1L, 57L), "..."),
                 text)
  paste0("Step ", steps$step, ", \"", steps$source, "\" (", steps$kind, ")",
         ifelse(nzchar(text), paste0(" \"", text, "\""), ""), ": ",
         steps$reason, ".")
}

#' One line per local input, for messages
#' @noRd
.input_lines <- function(inputs) {
  if (nrow(inputs) == 0L) return(character())
  paste0("Local input \"", inputs$basename, "\": ",
         .or_text(inputs$role, "role not recorded"), ", SHA-256 ",
         substr(inputs$sha256, 1L, 12L), "..., builder ",
         .or_text(inputs$builder, "not recorded"), ".")
}

#' Stop: nothing in a certificate can be replayed
#' @noRd
.abort_not_replayable <- function(steps, inputs, call = rlang::caller_env()) {
  cli::cli_abort(
    c(
      "Nothing in this certificate can be replayed.",
      stats::setNames(.sm_cli_escape(.step_lines(steps)),
                      rep("x", nrow(steps))),
      stats::setNames(.sm_cli_escape(.input_lines(inputs)),
                      rep("x", nrow(inputs))),
      "i" = if (nrow(inputs) > 0L) {
        "Build the corpus again by running its builder on these files;
         {.fun sm_verify_certificate} checks their hashes."
      },
      "i" = "{.fun sm_rebuild_from_cert} replays searches of OpenAlex,
             PubMed and Crossref."
    ),
    class = "scimapR_cert_not_replayable",
    call = call
  )
}

#' Inform: the steps and local inputs a rebuild leaves out
#'
#' `replayed = FALSE` when no step was replayed, so the rebuild is empty.
#' @noRd
.inform_not_replayed <- function(steps, inputs, replayed = TRUE) {
  n_steps <- nrow(steps)
  n_inputs <- nrow(inputs)
  summary_line <- if (replayed) {
    "Not replayed: {n_steps} step{?s} and {n_inputs} local input{?s}. The
     rebuilt corpus holds the works of the replayed searches only."
  } else {
    "Nothing in this certificate can be replayed, so the rebuilt corpus is
     empty."
  }
  cli::cli_inform(
    c(
      "!" = summary_line,
      stats::setNames(.sm_cli_escape(.step_lines(steps)), rep("*", n_steps)),
      stats::setNames(.sm_cli_escape(.input_lines(inputs)),
                      rep("*", n_inputs)),
      "i" = if (!replayed) {
        "{.fun sm_rebuild_from_cert} replays searches of OpenAlex, PubMed
         and Crossref."
      }
    ),
    class = "scimapR_cert_not_replayed"
  )
}

#' Check the local inputs of a certificate against the files on disk
#'
#' Looks for each file in `dirs` (a relative path) or at its path (an
#' absolute one), and then at `path_abs`; see `?sm_certificate`. Warns
#' about the files found nowhere, which are not checked.
#' @return `NULL` without inputs, else rows of the `checks` table.
#' @noRd
.verify_local_inputs <- function(inputs, dirs) {
  inputs <- .as_local_inputs_tbl(inputs)
  if (nrow(inputs) == 0L) return(NULL)
  dirs <- unique(.normalize_path(dirs))

  location <- vapply(seq_len(nrow(inputs)), function(i) {
    .find_local_input(inputs$path[i], inputs$path_abs[i], dirs)
  }, character(1))
  found <- !is.na(location)
  sha <- vapply(location, function(loc) {
    if (is.na(loc)) NA_character_ else
      digest::digest(loc, algo = "sha256", file = TRUE)
  }, character(1), USE.NAMES = FALSE)
  same <- found & !is.na(inputs$sha256) & !is.na(sha) &
    sha == inputs$sha256

  if (any(!found)) {
    cli::cli_warn(
      c(
        "!" = "{sum(!found)} local input{?s} not found, so not
               checked: {.file {inputs$path[!found]}}.",
        "i" = "Searched {.path {dirs}}, and the absolute path recorded for
               each file when it was registered.",
        "i" = "Use {.arg base_dir} to name the folder their paths are
               relative to."
      ),
      class = "scimapR_cert_inputs_missing"
    )
  }

  tibble::tibble(
    check = .input_check_names(inputs),
    expected = substr(inputs$sha256, 1L, 16L),
    actual = ifelse(found, substr(sha, 1L, 16L), "missing"),
    pass = ifelse(found, same, NA),
    status = ifelse(found, ifelse(same, "pass", "fail"), "not checked"),
    location = location
  )
}

#' Where a local input is now: the first existing file, or NA
#' @noRd
.find_local_input <- function(path, path_abs, dirs) {
  candidates <- character()
  if (!is.na(path) && nzchar(path)) {
    candidates <- if (fs::is_absolute_path(path)) {
      path.expand(path)
    } else {
      file.path(dirs, path)
    }
  }
  if (!is.na(path_abs) && nzchar(path_abs)) {
    candidates <- c(candidates, path_abs)
  }
  hit <- candidates[file.exists(candidates) & !dir.exists(candidates)]
  if (length(hit) == 0L) NA_character_ else .normalize_file_path(hit[1])
}

#' Names of the input checks: `input:<basename>`, the path for files that
#' share a name, and an index for paths that are still the same
#' @noRd
.input_check_names <- function(inputs) {
  name <- inputs$basename
  name[is.na(name)] <- basename(inputs$path[is.na(name)])
  shared <- name %in% name[duplicated(name)]
  name[shared] <- inputs$path[shared]
  shared <- name %in% name[duplicated(name)]
  name[shared] <- paste0(name[shared], " (", which(shared), ")")
  paste0("input:", name)
}

#' A certificate object from an object or a YAML file
#' @noRd
.read_cert <- function(cert, call = rlang::caller_env()) {
  if (is.character(cert)) {
    rlang::check_installed("yaml", reason = "to read YAML certificates.")
    .check_file_exists(cert, call = call)
    cert_data <- yaml::read_yaml(cert)
    cert <- .list_to_cert(cert_data)
  }

  if (!inherits(cert, "sm_certificate")) {
    cli::cli_abort(
      "{.arg cert} must be an {.cls sm_certificate} or a path to a YAML
       certificate.",
      call = call
    )
  }
  cert
}

#' Convert certificate S3 to plain list for YAML
#'
#' The local inputs become one list per file (row by row, as `queries`),
#' with UTC text for `registered_at`.
#' @noRd
.cert_to_list <- function(cert) {
  out <- unclass(cert)
  out$created <- .format_utc_time(out$created, what = "certificate created")
  out$local_inputs <- .local_inputs_to_list(out$local_inputs)
  out
}

#' Convert plain list from YAML to certificate S3
#' @noRd
.list_to_cert <- function(x) {
  if (!is.null(x$created) && is.character(x$created)) {
    x$created <- .as_utc_time(x$created, what = "certificate created")
  }
  x$local_inputs <- .as_local_inputs_tbl(x$local_inputs)
  structure(x, class = "sm_certificate")
}

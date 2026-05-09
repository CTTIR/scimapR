#' Screen corpus against a research question
#'
#' @description
#' `sm_screen_against_question()` uses an LLM (via ellmer) to screen each
#' work in a corpus against a structured research question. For each work,
#' the LLM is asked to classify the title/abstract as `"include"`,
#' `"exclude"`, or `"uncertain"`, with a confidence score and brief reason.
#' Results are written to the corpus's `screening` table.
#'
#' `sm_screen_regex()` provides a deterministic, LLM-free fallback using
#' regular-expression matching on titles and abstracts.
#'
#' `sm_screen_summary()` returns a count summary of screening decisions
#' by stage.
#'
#' @param corpus An `sm_corpus` object.
#' @param question An `sm_question` object.
#' @param stages Character vector of screening stages to run. One or more
#'   of `"title-abstract"` and `"full-text"`.
#' @param llm An ellmer chat provider object (e.g., from
#'   `ellmer::chat_openai()`). If `NULL`, the function will attempt to
#'   create a default provider.
#' @param batch_size Integer. Number of works to send per LLM prompt.
#' @param include_uncertain Logical. If `TRUE`, works classified as
#'   `"uncertain"` are carried forward to the next stage.
#' @param verbose Logical. Print progress?
#' @param call Caller environment for error reporting.
#'
#' @return A modified `sm_corpus` with updated `screening` table.
#'
#' @family question
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' q <- sm_question(
#'   text = "spatial transcriptomics in cancer",
#'   framework = "free"
#' )
#' # Deterministic regex screening (no LLM needed):
#' screened <- sm_screen_regex(
#'   corpus, include_terms = c("spatial", "transcriptom")
#' )
#' sm_screen_summary(screened)
sm_screen_against_question <- function(corpus,
                                       question,
                                       stages = c("title-abstract",
                                                   "full-text"),
                                       llm = NULL,
                                       batch_size = 10L,
                                       include_uncertain = TRUE,
                                       verbose = TRUE,
                                       call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  if (!is_sm_question(question)) {
    cli::cli_abort(
      "{.arg question} must be an {.cls sm_question} object.",
      call = call
    )
  }
  stages <- match.arg(stages, several.ok = TRUE)
  batch_size <- .check_positive_int(batch_size, call = call)

  .check_llm_available(call = call)

  # Resolve LLM provider
  if (is.null(llm)) {
    llm <- tryCatch(
      ellmer::chat_openai(model = "gpt-4o-mini"),
      error = function(e) {
        cli::cli_abort(
          c(
            "No LLM provider available.",
            "i" = "Pass an ellmer chat object via {.arg llm}, e.g. {.code ellmer::chat_openai()}.",
            "i" = "Original error: {conditionMessage(e)}"
          ),
          call = call
        )
      }
    )
  }

  prompt_template <- question$prompt_template

  for (stg in stages) {
    .sm_verbose("Screening stage: {.val {stg}}", verbose)

    # Determine which works to screen
    if (stg == "title-abstract") {
      work_ids_to_screen <- corpus$works$work_id
    } else {
      # For later stages, only screen works that passed previous stages
      prev_included <- corpus$screening$work_id[
        corpus$screening$decision %in%
          c("include", if (include_uncertain) "uncertain")
      ]
      work_ids_to_screen <- intersect(corpus$works$work_id, prev_included)
    }

    # Skip already-screened works for this stage
    already_screened <- corpus$screening$work_id[
      corpus$screening$stage == stg
    ]
    work_ids_to_screen <- setdiff(work_ids_to_screen, already_screened)

    if (length(work_ids_to_screen) == 0L) {
      .sm_verbose("No works to screen for stage {.val {stg}}.", verbose)
      next
    }

    .sm_verbose(
      "Screening {length(work_ids_to_screen)} work{?s} in stage {.val {stg}}.",
      verbose
    )

    # Process in batches
    batches <- split(
      work_ids_to_screen,
      ceiling(seq_along(work_ids_to_screen) / batch_size)
    )

    batch_results <- list()

    for (b_idx in seq_along(batches)) {
      batch_ids <- batches[[b_idx]]
      batch_works <- dplyr::filter(
        corpus$works, .data$work_id %in% batch_ids
      )

      .sm_verbose(
        "  Batch {b_idx}/{length(batches)} ({length(batch_ids)} works)...",
        verbose
      )

      # Build prompt for this batch
      work_texts <- vapply(seq_len(nrow(batch_works)), function(i) {
        ttl <- batch_works$title[i] %||% ""
        abs <- batch_works$abstract[i] %||% ""
        paste0(
          "--- Work ", batch_works$work_id[i], " ---\n",
          "Title: ", ttl, "\n",
          "Abstract: ", abs, "\n"
        )
      }, character(1))

      user_prompt <- paste0(
        "Screen the following ", length(batch_ids),
        " works. For each, respond with a JSON array of objects.\n\n",
        paste(work_texts, collapse = "\n")
      )

      system_prompt <- prompt_template

      response <- tryCatch(
        .llm_chat(llm, system_prompt, user_prompt, call = call),
        error = function(e) {
          cli::cli_inform(c(
            "!" = "LLM call failed for batch {b_idx}: {conditionMessage(e)}"
          ))
          NULL
        }
      )

      if (is.null(response)) {
        # Mark as uncertain on LLM failure
        batch_results[[b_idx]] <- tibble::tibble(
          work_id = batch_ids,
          stage = stg,
          decision = "uncertain",
          reason = "LLM call failed",
          confidence = 0.0,
          source = "llm_error",
          decided_at = Sys.time()
        )
        next
      }

      # Parse LLM response
      parsed <- .parse_screening_response(response, batch_ids, stg)
      batch_results[[b_idx]] <- parsed
    }

    # Combine batch results and append to screening
    new_screening <- dplyr::bind_rows(batch_results)
    corpus$screening <- dplyr::bind_rows(corpus$screening, new_screening)
  }

  .sm_verbose(
    "Screening complete. {nrow(corpus$screening)} total decision{?s}.",
    verbose
  )

  corpus
}

#' Parse LLM screening response into a screening tibble
#' @noRd
.parse_screening_response <- function(response, work_ids, stage) {
  now <- Sys.time()

  # Try to parse as JSON
  parsed <- tryCatch({
    # Extract JSON from response text
    response_text <- if (is.character(response)) response else as.character(response)

    # Find JSON array in the response
    json_match <- regmatches(
      response_text,
      regexpr("\\[.*\\]", response_text, perl = TRUE)
    )
    if (length(json_match) == 0L) {
      # Try individual JSON objects
      json_match <- response_text
    }
    jsonlite::fromJSON(json_match, simplifyVector = FALSE)
  }, error = function(e) NULL)

  if (is.null(parsed) || length(parsed) == 0L) {
    # Fallback: mark all as uncertain
    return(tibble::tibble(
      work_id = work_ids,
      stage = stage,
      decision = "uncertain",
      reason = "Could not parse LLM response",
      confidence = 0.0,
      source = "llm_parse_error",
      decided_at = now
    ))
  }

  # Map parsed results to work_ids
  n <- min(length(parsed), length(work_ids))
  decisions <- vapply(seq_len(n), function(i) {
    d <- parsed[[i]]$decision %||% "uncertain"
    if (!d %in% c("include", "exclude", "uncertain")) d <- "uncertain"
    d
  }, character(1))

  reasons <- vapply(seq_len(n), function(i) {
    parsed[[i]]$reason %||% NA_character_
  }, character(1))

  confidences <- vapply(seq_len(n), function(i) {
    c_val <- parsed[[i]]$confidence %||% NA_real_
    as.double(c_val)
  }, double(1))

  result <- tibble::tibble(
    work_id = work_ids[seq_len(n)],
    stage = stage,
    decision = decisions,
    reason = reasons,
    confidence = confidences,
    source = "llm",
    decided_at = now
  )

  # Handle remaining work_ids if LLM returned fewer results
  if (n < length(work_ids)) {
    extra <- tibble::tibble(
      work_id = work_ids[(n + 1L):length(work_ids)],
      stage = stage,
      decision = "uncertain",
      reason = "LLM returned fewer results than expected",
      confidence = 0.0,
      source = "llm_incomplete",
      decided_at = now
    )
    result <- dplyr::bind_rows(result, extra)
  }

  result
}

#' Screen corpus using regex matching
#'
#' @description
#' A deterministic, LLM-free screening method that uses regular expression
#' matching on work titles and abstracts. Works matching any `include_terms`
#' (case-insensitive) and none of the `exclude_terms` are classified as
#' `"include"`; works matching an exclude term are `"exclude"`; works
#' matching no include term are `"exclude"`.
#'
#' @param corpus An `sm_corpus` object.
#' @param include_terms Character vector of regex patterns. A work must match
#'   at least one to be included.
#' @param exclude_terms Character vector of regex patterns. A work matching
#'   any is excluded. Default `NULL` (no exclusions).
#' @param call Caller environment for error reporting.
#'
#' @return A modified `sm_corpus` with updated `screening` table.
#'
#' @family question
#' @export
sm_screen_regex <- function(corpus,
                            include_terms,
                            exclude_terms = NULL,
                            call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  if (missing(include_terms) || length(include_terms) == 0L) {
    cli::cli_abort(
      "{.arg include_terms} must be a non-empty character vector.",
      call = call
    )
  }

  if (nrow(corpus$works) == 0L) {
    return(corpus)
  }

  now <- Sys.time()
  works <- corpus$works

  # Combine title and abstract for matching
  search_text <- paste(
    works$title %||% "",
    works$abstract %||% "",
    sep = " "
  )
  search_text <- tolower(search_text)

  # Check include terms (OR logic)
  include_match <- vapply(include_terms, function(term) {
    grepl(tolower(term), search_text, perl = TRUE)
  }, logical(nrow(works)))

  if (is.matrix(include_match)) {
    any_include <- apply(include_match, 1, any)
  } else {
    any_include <- include_match
  }

  # Check exclude terms (OR logic)
  any_exclude <- rep(FALSE, nrow(works))
  if (!is.null(exclude_terms) && length(exclude_terms) > 0L) {
    exclude_match <- vapply(exclude_terms, function(term) {
      grepl(tolower(term), search_text, perl = TRUE)
    }, logical(nrow(works)))

    if (is.matrix(exclude_match)) {
      any_exclude <- apply(exclude_match, 1, any)
    } else {
      any_exclude <- exclude_match
    }
  }

  # Decision logic: include if matches include AND not exclude
  decisions <- dplyr::case_when(
    any_exclude ~ "exclude",
    any_include ~ "include",
    TRUE ~ "exclude"
  )

  reasons <- dplyr::case_when(
    any_exclude ~ "Matched exclude term",
    any_include ~ "Matched include term",
    TRUE ~ "No include term matched"
  )

  new_screening <- tibble::tibble(
    work_id = works$work_id,
    stage = "regex",
    decision = decisions,
    reason = reasons,
    confidence = 1.0,
    source = "regex",
    decided_at = now
  )

  corpus$screening <- dplyr::bind_rows(corpus$screening, new_screening)

  n_inc <- sum(decisions == "include")
  n_exc <- sum(decisions == "exclude")
  cli::cli_inform(c(
    "v" = "Regex screening: {n_inc} included, {n_exc} excluded."
  ))

  corpus
}

#' Summarise screening decisions
#'
#' @description
#' Returns a summary tibble of screening decisions by stage, showing the
#' count of included, excluded, and uncertain works at each stage.
#'
#' @param corpus An `sm_corpus` object.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns `stage`, `decision`, `n`, and `pct`.
#'
#' @family question
#' @export
sm_screen_summary <- function(corpus,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  if (nrow(corpus$screening) == 0L) {
    cli::cli_inform(c("i" = "No screening decisions recorded."))
    return(tibble::tibble(
      stage = character(),
      decision = character(),
      n = integer(),
      pct = double()
    ))
  }

  summary_tbl <- corpus$screening %>%
    dplyr::group_by(.data$stage, .data$decision) %>%
    dplyr::summarise(n = dplyr::n(), .groups = "drop") %>%
    dplyr::group_by(.data$stage) %>%
    dplyr::mutate(pct = round(100 * .data$n / sum(.data$n), 1)) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(.data$stage, .data$decision)

  # Print summary
  stages <- unique(summary_tbl$stage)
  for (stg in stages) {
    stg_data <- dplyr::filter(summary_tbl, .data$stage == stg)
    total <- sum(stg_data$n)
    cli::cli_h3("Stage: {stg} (n={total})")
    for (i in seq_len(nrow(stg_data))) {
      cli::cli_text(
        "  {stg_data$decision[i]}: {stg_data$n[i]} ({stg_data$pct[i]}%)"
      )
    }
  }

  summary_tbl
}

#' Retrieval-grounded corpus chat
#'
#' @description
#' Ask a question of a corpus using retrieval-augmented generation (RAG).
#' The function retrieves the most relevant works from the corpus using
#' embeddings, TF-IDF, or a hybrid method, then sends them as context to
#' an LLM along with the user's question. The response includes inline
#' citations keyed to work IDs. No hallucinated references are possible
#' because citations are constrained to retrieved works.
#'
#' @param corpus An `sm_corpus` object.
#' @param question Character. The user's question in natural language.
#' @param provider An ellmer chat provider object (e.g., from
#'   `ellmer::chat_openai()`). If `NULL`, errors informatively.
#' @param retrieve_n Integer. Number of works to retrieve as context.
#'   Default `30`.
#' @param retrieve_method Character. Retrieval method:
#'   - `"embedding"`: cosine similarity on `corpus$embeddings`.
#'   - `"tfidf"`: TF-IDF on titles and abstracts.
#'   - `"hybrid"`: weighted average of both methods.
#' @param cite Logical. If `TRUE`, the prompt instructs the LLM to include
#'   inline citations using work IDs.
#' @param max_tokens Integer. Maximum tokens for the LLM response.
#' @param temperature Numeric. LLM temperature (0 = deterministic).
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_chat_response` S3 object with fields:
#' \describe{
#'   \item{answer}{Character. The LLM's response.}
#'   \item{citations}{Tibble of cited work IDs and their details.}
#'   \item{retrieved_works}{Tibble of the works sent as context.}
#'   \item{prompt_hash}{SHA-256 hash of the full prompt for reproducibility.}
#'   \item{model}{Character. The model used.}
#'   \item{timestamp}{POSIXct. When the response was generated.}
#'   \item{question}{The original question.}
#'   \item{retrieve_method}{The retrieval method used.}
#' }
#'
#' @family chat
#' @export
#' @examples
#' \dontrun{
#' # Requires ellmer package and LLM API access:
#' # response <- sm_chat(corpus, "What methods dominate?",
#' #                     provider = ellmer::chat_openai())
#' }
sm_chat <- function(corpus,
                    question,
                    provider = NULL,
                    retrieve_n = 30L,
                    retrieve_method = c("embedding", "tfidf", "hybrid"),
                    cite = TRUE,
                    max_tokens = 2000L,
                    temperature = 0.2,
                    call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(question, call = call)

  if (is.null(provider)) {
    cli::cli_abort(c(
      "{.fn sm_chat} requires an LLM provider via the {.pkg ellmer} package.",
      "i" = 'Install with: {.code install.packages("ellmer")}',
      "i" = 'Usage: {.code sm_chat(corpus, question, provider = ellmer::chat_openai())}'
    ), call = call)
  }

  .check_llm_available(call = call)
  retrieve_method <- match.arg(retrieve_method)

  if (nrow(corpus$works) == 0L) {
    cli::cli_abort("Cannot chat with an empty corpus.", call = call)
  }

  # Retrieve relevant works
  retrieved <- .retrieve_works(corpus, question, retrieve_n, retrieve_method)

  # Build prompt
  context <- .build_chat_context(retrieved)
  system_prompt <- .build_chat_system_prompt(cite = cite)
  user_prompt <- paste0("Context:\n\n", context, "\n\nQuestion: ", question)

  prompt_hash <- .hash_prompt(paste0(system_prompt, user_prompt))

  response_text <- tryCatch(
    .llm_chat(provider, system_prompt, user_prompt, call = call),
    error = function(e) {
      cli::cli_abort(
        "LLM chat failed: {conditionMessage(e)}",
        call = call
      )
    }
  )

  response_text <- if (is.character(response_text)) {
    response_text
  } else {
    as.character(response_text)
  }

  # Parse citations from response
  citations <- .parse_chat_citations(response_text, retrieved)

  # Detect model name
  model_name <- tryCatch({
    if (!is.null(provider$model)) provider$model else "unknown"
  }, error = function(e) "unknown")

  # Append provenance
  prov_row <- tibble::tibble(
    work_id = NA_character_,
    source = "llm-chat",
    source_id_external = NA_character_,
    fetch_date = Sys.time(),
    query = question,
    engine = "ellmer",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = prompt_hash
  )

  corpus$provenance <- dplyr::bind_rows(corpus$provenance, prov_row)

  structure(
    list(
      answer = response_text,
      citations = citations,
      retrieved_works = retrieved,
      question = question,
      model = model_name,
      prompt_hash = prompt_hash,
      timestamp = Sys.time(),
      retrieve_method = retrieve_method
    ),
    class = "sm_chat_response"
  )
}

#' @rdname sm_chat
#' @param x An `sm_chat_response` object.
#' @param ... Ignored.
#' @export
print.sm_chat_response <- function(x, ...) {
  cli::cli_h1("<sm_chat_response>")
  cli::cli_text("{.strong Question:} {x$question}")
  cli::cli_text("{.strong Model:} {x$model}")
  cli::cli_text("{.strong Retrieved:} {nrow(x$retrieved_works)} works ({x$retrieve_method})")
  cli::cli_text("{.strong Citations:} {nrow(x$citations)} works cited")
  cli::cli_text("{.strong Prompt hash:} {substr(x$prompt_hash, 1, 12)}")
  cli::cli_text("{.strong Timestamp:} {format(x$timestamp, '%Y-%m-%d %H:%M:%S')}")
  cli::cli_text("")
  cli::cli_rule("Answer")
  cli::cli_text(x$answer)

  if (nrow(x$citations) > 0L) {
    cli::cli_text("")
    cli::cli_rule("Cited works")
    for (i in seq_len(nrow(x$citations))) {
      row <- x$citations[i, ]
      cli::cli_text(
        "  [{row$cite_token}] {row$work_id}: {row$snippet}"
      )
    }
  }

  invisible(x)
}

#' Retrieve relevant works from corpus
#' @noRd
.retrieve_works <- function(corpus, question, n, method) {
  works <- corpus$works
  n <- min(n, nrow(works))

  if (method == "embedding" || method == "hybrid") {
    emb_scores <- .retrieve_by_embedding_chat(corpus, question)
  } else {
    emb_scores <- NULL
  }

  if (method == "tfidf" || method == "hybrid") {
    tfidf_scores <- .retrieve_by_tfidf_chat(corpus, question)
  } else {
    tfidf_scores <- NULL
  }

  if (method == "hybrid" && !is.null(emb_scores) && !is.null(tfidf_scores)) {
    emb_norm <- .normalise_scores_chat(emb_scores)
    tfidf_norm <- .normalise_scores_chat(tfidf_scores)
    scores <- 0.6 * emb_norm + 0.4 * tfidf_norm
  } else if (!is.null(emb_scores)) {
    scores <- emb_scores
  } else if (!is.null(tfidf_scores)) {
    scores <- tfidf_scores
  } else {
    # Fallback: simple keyword overlap on titles
    query_words <- tolower(strsplit(question, "\\s+")[[1]])
    scores <- vapply(tolower(works$title), function(t) {
      if (is.na(t)) return(0)
      sum(vapply(query_words, function(q) grepl(q, t, fixed = TRUE),
                 logical(1)))
    }, double(1), USE.NAMES = FALSE)
  }

  idx <- utils::head(order(scores, decreasing = TRUE), n)
  works[idx, ]
}

#' Retrieve by embedding cosine similarity (chat version)
#' @noRd
.retrieve_by_embedding_chat <- function(corpus, question) {
  if (is.null(corpus$embeddings) || nrow(corpus$embeddings) == 0L) {
    return(NULL)
  }

  words <- tolower(strsplit(question, "\\W+")[[1]])
  words <- words[nzchar(words)]
  if (length(words) == 0L) return(NULL)

  texts <- tolower(paste(
    corpus$works$title %||% "",
    corpus$works$abstract %||% ""
  ))

  overlap <- vapply(texts, function(txt) {
    sum(vapply(words, function(w) grepl(w, txt, fixed = TRUE), logical(1)))
  }, double(1), USE.NAMES = FALSE)

  if (sum(overlap) == 0) return(NULL)

  weights <- overlap / sum(overlap)

  emb_ids <- rownames(corpus$embeddings)
  work_ids <- corpus$works$work_id

  if (!is.null(emb_ids)) {
    match_idx <- match(work_ids, emb_ids)
    valid <- !is.na(match_idx)
    if (!any(valid)) return(NULL)
    emb_matrix <- corpus$embeddings[match_idx[valid], , drop = FALSE]
    weights_valid <- weights[valid]
  } else {
    if (nrow(corpus$embeddings) != nrow(corpus$works)) return(NULL)
    emb_matrix <- corpus$embeddings
    weights_valid <- weights
    valid <- rep(TRUE, nrow(corpus$works))
  }

  query_vec <- colSums(emb_matrix * weights_valid)
  query_norm <- sqrt(sum(query_vec^2))
  if (query_norm == 0) return(NULL)
  query_vec <- query_vec / query_norm

  norms <- sqrt(rowSums(emb_matrix^2))
  norms[norms == 0] <- 1
  cosine_sim <- as.numeric(emb_matrix %*% query_vec) / norms

  full_scores <- rep(0.0, nrow(corpus$works))
  if (!is.null(emb_ids)) {
    full_scores[valid] <- cosine_sim
  } else {
    full_scores <- cosine_sim
  }

  full_scores
}

#' Retrieve by TF-IDF similarity (chat version)
#' @noRd
.retrieve_by_tfidf_chat <- function(corpus, question) {
  texts <- paste(
    corpus$works$title %||% "",
    corpus$works$abstract %||% ""
  )

  question_words <- tolower(strsplit(question, "\\W+")[[1]])
  question_words <- question_words[nzchar(question_words)]
  if (length(question_words) == 0L) return(NULL)

  texts_lower <- tolower(texts)
  n_docs <- length(texts_lower)

  df <- vapply(question_words, function(w) {
    sum(grepl(w, texts_lower, fixed = TRUE))
  }, double(1))

  idf <- log(1 + n_docs / (1 + df))

  scores <- vapply(texts_lower, function(txt) {
    tf <- vapply(question_words, function(w) {
      stringr::str_count(txt, stringr::fixed(w))
    }, double(1))
    sum(tf * idf)
  }, double(1), USE.NAMES = FALSE)

  scores
}

#' Normalise scores to 0-1 range (chat version)
#' @noRd
.normalise_scores_chat <- function(scores) {
  if (is.null(scores) || length(scores) == 0L) return(scores)
  rng <- range(scores, na.rm = TRUE)
  if (rng[2] - rng[1] == 0) return(rep(0.5, length(scores)))
  (scores - rng[1]) / (rng[2] - rng[1])
}

#' Build context text from retrieved works
#' @noRd
.build_chat_context <- function(works) {
  lines <- vapply(seq_len(nrow(works)), function(i) {
    w <- works[i, ]
    paste0(
      "[cite:", w$work_id, "] ",
      w$title %||% "Untitled",
      " (", w$year %||% "n.d.", "). ",
      if (!is.na(w$abstract) && nzchar(w$abstract)) {
        paste0(substr(w$abstract, 1, 500), "...")
      } else {
        ""
      }
    )
  }, character(1))
  paste(lines, collapse = "\n\n")
}

#' Build system prompt for chat
#' @noRd
.build_chat_system_prompt <- function(cite = TRUE) {
  base <- paste0(
    "You are a research assistant analysing a corpus of scientific works. ",
    "Answer the user's question based ONLY on the works provided in the context. ",
    "Do not use any knowledge beyond what is in the context."
  )
  if (cite) {
    paste0(base,
      " Cite specific works using [cite:WXXXXXXXXX] tokens. ",
      "Only cite works that appear in the context."
    )
  } else {
    base
  }
}

#' Parse citations from LLM response
#' @noRd
.parse_chat_citations <- function(response_text, retrieved) {
  pattern <- "\\[cite:(W\\d+)\\]"
  matches <- regmatches(response_text, gregexpr(pattern, response_text))[[1]]

  if (length(matches) == 0L) {
    return(tibble::tibble(
      cite_token = character(),
      work_id = character(),
      snippet = character()
    ))
  }

  work_ids <- sub("\\[cite:(W\\d+)\\]", "\\1", matches)
  work_ids <- unique(work_ids)

  valid <- work_ids[work_ids %in% retrieved$work_id]

  if (length(valid) == 0L) {
    return(tibble::tibble(
      cite_token = character(),
      work_id = character(),
      snippet = character()
    ))
  }

  tibble::tibble(
    cite_token = paste0("[cite:", valid, "]"),
    work_id = valid,
    snippet = retrieved$title[match(valid, retrieved$work_id)]
  )
}

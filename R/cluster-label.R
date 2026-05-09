#' Label clusters with representative terms
#'
#' @description
#' Assigns human-readable labels to clusters by extracting representative
#' terms. Supports TF-IDF-based extraction (default), YAKE keyword extraction,
#' or LLM-generated labels via the \pkg{ellmer} package.
#'
#' @param corpus An [sm_corpus] object with a `cluster_id` column in
#'   `corpus$works`.
#' @param method Character; labelling method. One of `"tfidf"` (default),
#'   `"yake"`, or `"llm"`.
#' @param n_terms Integer; number of top terms to include in each cluster
#'   label. Defaults to `5L`.
#' @param llm_provider An \pkg{ellmer} chat provider object (e.g.,
#'   `ellmer::chat_openai()`). Required when `method = "llm"`, ignored
#'   otherwise.
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` with a `cluster_label` column added to
#'   `corpus$works`, containing a character string of representative terms
#'   for each cluster.
#'
#' @details
#' **TF-IDF method**: For each cluster, concatenates titles and abstracts of
#' member works, tokenises into unigrams, computes TF-IDF scores where each
#' cluster is treated as a document, and selects the top `n_terms`.
#'
#' **YAKE method**: Uses a simplified YAKE-like scoring based on term frequency,
#' position, and spread across works within each cluster.
#'
#' **LLM method**: Sends titles and abstracts of each cluster to an LLM with
#' a prompt asking for a concise topical label. Requires the \pkg{ellmer} package
#' and a configured provider.
#'
#' @family clustering
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("tidytext", quietly = TRUE)) {
#'   corpus <- sm_example_corpus(with_embeddings = TRUE)
#'   corpus <- sm_cluster_kmeans(corpus, k = 5)
#'   corpus <- sm_cluster_label(corpus, method = "tfidf", n_terms = 3L)
#'   head(corpus$works[, c("work_id", "cluster_id", "cluster_label")])
#' }
#' }
sm_cluster_label <- function(corpus,
                             method = c("tfidf", "yake", "llm"),
                             n_terms = 5L,
                             llm_provider = NULL,
                             call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  method <- rlang::arg_match(method, error_call = call)
  n_terms <- .check_positive_int(n_terms, call = call)
  if (method == "tfidf") {
    rlang::check_installed("tidytext",
      reason = "for TF-IDF cluster labelling.")
  }

  works <- corpus$works

  if (!"cluster_id" %in% names(works)) {
    cli::cli_abort(
      c("No {.field cluster_id} column found in works.",
        "i" = "Run a clustering function first (e.g., {.fun sm_cluster_hdbscan})."),
      call = call
    )
  }

  if (nrow(works) == 0L) {
    return(corpus)
  }

  # Remove existing label column if present
  if ("cluster_label" %in% names(corpus$works)) {
    corpus$works$cluster_label <- NULL
  }

  labels <- switch(method,
    tfidf = .label_tfidf(works, n_terms, call),
    yake  = .label_yake(works, n_terms, call),
    llm   = .label_llm(works, n_terms, llm_provider, call)
  )

  corpus$works <- dplyr::left_join(corpus$works, labels, by = "cluster_id")

  n_labelled <- length(unique(labels$cluster_id))
  cli::cli_inform(c(
    "v" = "{n_labelled} cluster{?s} labelled using {.val {method}} method."
  ))

  corpus
}


#' TF-IDF cluster labelling
#' @noRd
.label_tfidf <- function(works, n_terms, call) {
  # Prepare text per cluster
  cluster_text <- works %>%
    dplyr::filter(!is.na(.data$cluster_id)) %>%
    dplyr::mutate(
      text = paste(
        ifelse(is.na(.data$title), "", .data$title),
        ifelse(is.na(.data$abstract), "", .data$abstract)
      )
    ) %>%
    dplyr::select("cluster_id", "text")

  if (nrow(cluster_text) == 0L) {
    return(tibble::tibble(cluster_id = integer(), cluster_label = character()))
  }

  # Aggregate text by cluster
  cluster_docs <- cluster_text %>%
    dplyr::group_by(.data$cluster_id) %>%
    dplyr::summarise(text = paste(.data$text, collapse = " "), .groups = "drop")

  # Tokenise
  tokens <- tidytext::unnest_tokens(cluster_docs, output = "word",
                                     input = "text")

  # Remove stopwords
  tokens <- dplyr::anti_join(tokens, tidytext::stop_words, by = "word")

  # Remove very short tokens and numbers
  tokens <- tokens %>%
    dplyr::filter(nchar(.data$word) >= 3L, !grepl("^\\d+$", .data$word))

  if (nrow(tokens) == 0L) {
    clusters <- unique(works$cluster_id[!is.na(works$cluster_id)])
    return(tibble::tibble(cluster_id = clusters,
                          cluster_label = rep(NA_character_, length(clusters))))
  }

  # Count term frequency per cluster
  tf <- tokens %>%
    dplyr::count(.data$cluster_id, .data$word, name = "n")

  # Compute TF-IDF
  tfidf <- tidytext::bind_tf_idf(tf, term = "word", document = "cluster_id",
                                  n = "n")

  # Select top n_terms per cluster
  top_terms <- tfidf %>%
    dplyr::group_by(.data$cluster_id) %>%
    dplyr::slice_max(order_by = .data$tf_idf, n = n_terms,
                     with_ties = FALSE) %>%
    dplyr::summarise(
      cluster_label = paste(.data$word, collapse = "; "),
      .groups = "drop"
    )

  top_terms
}


#' YAKE-like cluster labelling
#' @noRd
.label_yake <- function(works, n_terms, call) {
  # Simplified YAKE-like scoring: combines frequency, spread across works,

  # and positional features
  cluster_works <- works %>%
    dplyr::filter(!is.na(.data$cluster_id)) %>%
    dplyr::mutate(
      text = paste(
        ifelse(is.na(.data$title), "", .data$title),
        ifelse(is.na(.data$abstract), "", .data$abstract)
      )
    ) %>%
    dplyr::select("work_id", "cluster_id", "text")

  if (nrow(cluster_works) == 0L) {
    return(tibble::tibble(cluster_id = integer(), cluster_label = character()))
  }

  # Tokenise at work level
  tokens <- tidytext::unnest_tokens(cluster_works, output = "word",
                                     input = "text")
  tokens <- dplyr::anti_join(tokens, tidytext::stop_words, by = "word")
  tokens <- tokens %>%
    dplyr::filter(nchar(.data$word) >= 3L, !grepl("^\\d+$", .data$word))

  if (nrow(tokens) == 0L) {
    clusters <- unique(works$cluster_id[!is.na(works$cluster_id)])
    return(tibble::tibble(cluster_id = clusters,
                          cluster_label = rep(NA_character_, length(clusters))))
  }

  # Score: frequency * document spread (number of unique works containing term)
  yake_scores <- tokens %>%
    dplyr::group_by(.data$cluster_id, .data$word) %>%
    dplyr::summarise(
      freq = dplyr::n(),
      spread = dplyr::n_distinct(.data$work_id),
      .groups = "drop"
    ) %>%
    dplyr::mutate(score = .data$freq * log1p(.data$spread))

  top_terms <- yake_scores %>%
    dplyr::group_by(.data$cluster_id) %>%
    dplyr::slice_max(order_by = .data$score, n = n_terms,
                     with_ties = FALSE) %>%
    dplyr::summarise(
      cluster_label = paste(.data$word, collapse = "; "),
      .groups = "drop"
    )

  top_terms
}


#' LLM cluster labelling
#' @noRd
.label_llm <- function(works, n_terms, llm_provider, call) {
  if (is.null(llm_provider)) {
    cli::cli_abort(
      c("{.arg llm_provider} is required when {.code method = \"llm\"}.",
        "i" = "Pass an {.pkg ellmer} chat provider, e.g. {.code ellmer::chat_openai()}."),
      call = call
    )
  }

  .check_llm_available(call = call)

  clusters <- unique(works$cluster_id[!is.na(works$cluster_id)])
  if (length(clusters) == 0L) {
    return(tibble::tibble(cluster_id = integer(), cluster_label = character()))
  }

  labels <- vapply(clusters, function(cid) {
    cworks <- works %>%
      dplyr::filter(.data$cluster_id == cid)

    # Sample up to 20 works for the prompt
    if (nrow(cworks) > 20L) {
      cworks <- cworks[sample(nrow(cworks), 20L), ]
    }

    titles <- cworks$title[!is.na(cworks$title)]
    if (length(titles) == 0L) return(paste("Cluster", cid))

    titles_text <- paste(paste0("- ", titles), collapse = "\n")

    system_prompt <- paste(
      "You are a scientific research analyst.",
      "Given a list of paper titles from a research cluster,",
      "provide a concise topical label (3-7 words) that captures the",
      "main theme. Respond with ONLY the label, no explanation."
    )
    user_prompt <- paste0(
      "Cluster contains ", nrow(cworks), " papers. Sample titles:\n",
      titles_text, "\n\nProvide a concise label for this cluster:"
    )

    tryCatch(
      .llm_chat(llm_provider, system_prompt, user_prompt, call = call),
      error = function(e) {
        cli::cli_inform(c(
          "!" = "LLM labelling failed for cluster {cid}: {conditionMessage(e)}"
        ))
        paste("Cluster", cid)
      }
    )
  }, character(1))

  tibble::tibble(
    cluster_id    = clusters,
    cluster_label = labels
  )
}

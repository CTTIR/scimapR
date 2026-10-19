#' Build a co-word (co-occurrence) network
#'
#' @description
#' Constructs an undirected co-word network. Nodes represent terms and an edge
#' connects two terms if they co-occur within the same work. Edge weight equals
#' the number of works in which both terms appear.
#'
#' @param corpus An [sm_corpus] object.
#' @param field Character; the text field to extract terms from. One of
#'   `"concepts"` (default, uses `corpus$concepts`), `"title"`, `"abstract"`,
#'   or `"keywords"`.
#' @param ngram Integer; for free-text fields (`"title"`, `"abstract"`), the
#'   n-gram size to tokenise into. Defaults to `1L` (unigrams).
#' @param min_freq Integer; minimum document frequency a term must have to be
#'   included. Defaults to `5L`.
#' @param stopwords Character vector of additional stopwords to remove when
#'   tokenising free text. Combined with [tidytext::stop_words]. Set to
#'   `NULL` (default) for no additional stopwords.
#' @param vocabulary For `field = "keywords"` or `"concepts"`, the concept
#'   vocabularies to take terms from: names of vocabularies or of families
#'   of [sm_concept_vocabularies()], such as `"author-keywords"` or
#'   `"indexer_keyword"`. `NULL` (default) means the author keywords for
#'   `"keywords"` (see Details) and every vocabulary for `"concepts"`. Must
#'   be `NULL` for `"title"` and `"abstract"`, whose terms come from the
#'   text.
#' @param call Caller environment for error reporting.
#'
#' @return A [tidygraph::tbl_graph] object (undirected). Nodes carry `name`
#'   (the term) and `freq` (document frequency). Edges carry a `weight` column
#'   (co-occurrence count).
#'
#' @details
#' When `field = "concepts"`, terms come from the `concept_name` column in
#' `corpus$concepts` (no tokenisation needed), of every vocabulary or of
#' those named in `vocabulary`.
#'
#' When `field = "keywords"`, terms are whole keywords from
#' `corpus$concepts`, not tokenised. By default these are the author
#' keywords (the `author_keyword` family: `author-keywords`,
#' `manual-tags`); a corpus without any falls back to the indexer keywords
#' (the `indexer_keyword` family: Keywords Plus, Scopus index keywords,
#' Zotero automatic tags and MeSH) with a message, and a corpus with
#' neither gives an empty network with a message. The fallback applies to
#' the whole corpus, not per work.
#'
#' When `field` is `"title"` or `"abstract"`, the text is tokenised with
#' [tidytext::unnest_tokens()] using the chosen `ngram` size and stopwords
#' are removed.
#'
#' Terms are lower-cased, and terms below `min_freq` are dropped. Empty
#' input returns an empty undirected `tbl_graph`.
#'
#' @family networks
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' g <- sm_network_coword(corpus, field = "concepts", min_freq = 5L)
#' g
#'
#' # Keyword networks from a Web of Science file
#' path <- tempfile(fileext = ".txt")
#' writeLines(c(
#'   "PT J", "AU Doe, J", "TI First work",
#'   "DE heat illness; recruits; cooling", "ID HYPERTHERMIA; EXERCISE",
#'   "PY 2021", "UT WOS:000000000000001", "ER",
#'   "PT J", "AU Roe, R", "TI Second work",
#'   "DE heat illness; recruits", "ID HYPERTHERMIA; EXERCISE",
#'   "PY 2022", "UT WOS:000000000000002", "ER", "EF"
#' ), path)
#' wos <- sm_read_wos(path, verbose = FALSE)
#' sm_network_coword(wos, field = "keywords", min_freq = 2L)
#' sm_network_coword(wos, field = "keywords", vocabulary = "keywords-plus",
#'                   min_freq = 2L)
sm_network_coword <- function(corpus,
                              field = c("concepts", "title", "abstract",
                                        "keywords"),
                              ngram = 1L,
                              min_freq = 5L,
                              stopwords = NULL,
                              vocabulary = NULL,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  field <- rlang::arg_match(field, error_call = call)
  ngram <- .check_positive_int(ngram, call = call)
  min_freq <- .check_positive_int(min_freq, call = call)
  vocab_levels <- NULL
  if (!is.null(vocabulary)) {
    if (field %in% c("title", "abstract")) {
      cli::cli_abort(
        c("{.arg vocabulary} must be {.code NULL} for
           {.code field = \"{field}\"}.",
          "i" = "{.arg vocabulary} selects concept vocabularies for
                 {.code field = \"keywords\"} and
                 {.code field = \"concepts\"}."),
        call = call
      )
    }
    vocab_levels <- .resolve_concept_vocab(vocabulary, call = call)
  }
  if (field %in% c("title", "abstract")) {
    rlang::check_installed("tidytext",
      reason = "to tokenise free text for co-word networks.")
  }

  works <- corpus$works

  # --- empty input guard ---
  if (nrow(works) == 0L) {
    nodes <- tibble::tibble(name = character(), freq = integer())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Extract work-term pairs
  work_terms <- .extract_terms(corpus, field, ngram, stopwords, vocab_levels,
                               call)

  if (nrow(work_terms) == 0L) {
    nodes <- tibble::tibble(name = character(), freq = integer())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Filter by minimum document frequency
  term_freq <- work_terms %>%
    dplyr::count(.data$term, name = "freq") %>%
    dplyr::filter(.data$freq >= min_freq)

  if (nrow(term_freq) == 0L) {
    nodes <- tibble::tibble(name = character(), freq = integer())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  work_terms <- dplyr::semi_join(work_terms, term_freq, by = "term")

  # Self-join to find co-occurrence pairs
  pairs <- work_terms %>%
    dplyr::inner_join(
      work_terms %>% dplyr::rename(term_2 = "term"),
      by = "work_id",
      relationship = "many-to-many"
    ) %>%
    dplyr::filter(.data$term < .data$term_2) %>%
    dplyr::count(.data$term, .data$term_2, name = "weight")

  if (nrow(pairs) == 0L) {
    nodes <- tibble::tibble(name = term_freq$term, freq = term_freq$freq)
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Build node table from terms that appear in at least one edge
  edge_terms <- unique(c(pairs$term, pairs$term_2))
  nodes <- term_freq %>%
    dplyr::filter(.data$term %in% edge_terms) %>%
    dplyr::rename(name = "term")

  # Build edge list
  node_idx <- stats::setNames(seq_along(nodes$name), nodes$name)
  edges <- tibble::tibble(
    from   = unname(node_idx[pairs$term]),
    to     = unname(node_idx[pairs$term_2]),
    weight = pairs$weight
  )

  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE)
}


#' Extract work-term pairs from a corpus
#'
#' `vocab_levels` holds the canonical vocabularies resolved from the
#' `vocabulary` argument, or `NULL`. It is never compared with the concepts
#' column of that name inside a data mask, where the column would win.
#' @noRd
.extract_terms <- function(corpus, field, ngram, stopwords, vocab_levels,
                           call) {
  if (field %in% c("concepts", "keywords")) {
    concepts <- corpus$concepts
    if (!is.null(vocab_levels)) {
      concepts <- .concepts_in_family(concepts, vocab_levels, call = call)
    } else if (field == "keywords") {
      concepts <- .keyword_concepts(concepts)
    }
    if (nrow(concepts) == 0L) {
      return(tibble::tibble(work_id = character(), term = character()))
    }
    out <- concepts %>%
      dplyr::select("work_id", term = "concept_name") %>%
      dplyr::mutate(term = tolower(.data$term)) %>%
      dplyr::distinct()
    return(out)
  }

  # title or abstract: tokenise
  text_col <- field
  works <- corpus$works
  if (!text_col %in% names(works)) {
    cli::cli_abort(
      "Column {.field {text_col}} not found in {.field works} table.",
      call = call
    )
  }

  text_data <- works %>%
    dplyr::select("work_id", text = dplyr::all_of(text_col)) %>%
    dplyr::filter(!is.na(.data$text), nzchar(.data$text))

  if (nrow(text_data) == 0L) {
    return(tibble::tibble(work_id = character(), term = character()))
  }

  # Tokenise
  tokens <- tidytext::unnest_tokens(
    text_data, output = "term", input = "text",
    token = "ngrams", n = ngram
  )

  # Remove stopwords
  sw <- tidytext::stop_words
  if (!is.null(stopwords)) {
    sw <- dplyr::bind_rows(
      sw,
      tibble::tibble(word = tolower(stopwords), lexicon = "custom")
    )
  }

  if (ngram == 1L) {
    tokens <- dplyr::anti_join(tokens, sw, by = c("term" = "word"))
  } else {
    # For n-grams, remove if any component is a stopword
    sw_vec <- unique(sw$word)
    tokens <- tokens %>%
      dplyr::filter(!vapply(.data$term, function(t) {
        words <- strsplit(t, "\\s+")[[1]]
        any(words %in% sw_vec)
      }, logical(1)))
  }

  tokens %>%
    dplyr::select("work_id", "term") %>%
    dplyr::distinct()
}


#' Keyword concepts for the default keyword network
#'
#' The author keywords of the corpus, or its indexer keywords when it has no
#' author keywords (with a message); a 0-row table when it has neither.
#' @noRd
.keyword_concepts <- function(concepts) {
  author_kw <- .concepts_in_family(concepts, "author_keyword")
  if (nrow(author_kw) > 0L) return(author_kw)
  indexer_kw <- .concepts_in_family(concepts, "indexer_keyword")
  if (nrow(indexer_kw) == 0L) {
    cli::cli_inform(
      c("i" = "The corpus has no author or indexer keywords, so the keyword
               network is empty.",
        "i" = "See {.fn sm_concept_vocabularies} for the vocabularies that
               count as keywords."),
      class = "scimapR_coword_no_keywords"
    )
    return(indexer_kw)
  }
  cli::cli_inform(
    c("i" = "The corpus has no author keywords; using its indexer keywords
             ({.val {unique(indexer_kw$vocabulary)}}) instead."),
    class = "scimapR_coword_keyword_fallback"
  )
  indexer_kw
}

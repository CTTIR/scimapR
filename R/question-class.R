#' Create a structured research question
#'
#' @description
#' Constructs an `sm_question` S3 object encoding a structured research
#' question using a recognised framework (PICO, PECO, PICOS, SPIDER, or
#' free-form). The object carries all structured fields, auto-generated
#' query strings suitable for bibliographic databases, and a prompt template
#' for LLM-based screening.
#'
#' The question receives a content-addressable ID (SHA-256 hash of all
#' input fields), ensuring that identical questions always produce the same
#' identifier regardless of when they are created.
#'
#' @param text Character. The full research question in natural language.
#' @param framework Character. The structuring framework. One of `"PICO"`
#'   (Population, Intervention, Comparison, Outcome), `"PECO"` (Population,
#'   Exposure, Comparison, Outcome), `"PICOS"` (adds Study design),
#'   `"SPIDER"` (Sample, Phenomenon of Interest, Design, Evaluation,
#'   Research type), or `"free"` for unstructured questions.
#' @param population Character. The population or sample under study.
#' @param intervention Character. The intervention or phenomenon of interest.
#' @param comparison Character. The comparator or control condition.
#' @param outcome Character. The outcome(s) of interest.
#' @param exposure Character. The exposure (for PECO framework).
#' @param design Character. Study design (for PICOS/SPIDER frameworks).
#' @param timeframe Character. Optional time restriction.
#' @param include_terms Character vector. Additional terms that must appear
#'   in relevant works.
#' @param exclude_terms Character vector. Terms whose presence disqualifies
#'   a work.
#' @param languages Character vector. ISO 639-1 language codes to restrict
#'   the search. Default `"en"`.
#' @param notes Character. Free-text notes about the question.
#'
#' @return An `sm_question` S3 object with fields:
#' \describe{
#'   \item{id}{Content-hash identifier.}
#'   \item{text}{The research question text.}
#'   \item{framework}{The structuring framework.}
#'   \item{created}{POSIXct creation timestamp.}
#'   \item{population, intervention, comparison, outcome, exposure, design,
#'     timeframe}{Structured facets (may be `NULL`).}
#'   \item{include_terms, exclude_terms}{Term filters.}
#'   \item{languages}{Language filter.}
#'   \item{notes}{Free-text notes.}
#'   \item{query_strings}{Named list of database-specific query strings.}
#'   \item{prompt_template}{A prompt template for LLM screening.}
#' }
#'
#' @family question
#' @export
#' @examples
#' q <- sm_question(
#'   text = "Does immunotherapy improve survival in metastatic melanoma?",
#'   framework = "PICO",
#'   population = "adults with metastatic melanoma",
#'   intervention = "immune checkpoint inhibitors",
#'   comparison = "chemotherapy",
#'   outcome = "overall survival"
#' )
#' print(q)
sm_question <- function(text,
                        framework = c("PICO", "PECO", "PICOS",
                                      "SPIDER", "free"),
                        population = NULL,
                        intervention = NULL,
                        comparison = NULL,
                        outcome = NULL,
                        exposure = NULL,
                        design = NULL,
                        timeframe = NULL,
                        include_terms = NULL,
                        exclude_terms = NULL,
                        languages = "en",
                        notes = NULL) {
  .check_string(text)
  framework <- match.arg(framework)

  # Validate framework-specific required fields
  .validate_question_fields(
    framework = framework,
    population = population,
    intervention = intervention,
    comparison = comparison,
    outcome = outcome,
    exposure = exposure,
    design = design
  )

  # Build content hash from all substantive fields
  hash_input <- list(
    text = text,
    framework = framework,
    population = population,
    intervention = intervention,
    comparison = comparison,
    outcome = outcome,
    exposure = exposure,
    design = design,
    timeframe = timeframe,
    include_terms = sort(include_terms %||% character()),
    exclude_terms = sort(exclude_terms %||% character()),
    languages = sort(languages)
  )
  qid <- paste0("Q-", substr(digest::digest(hash_input, algo = "sha256"), 1, 16))

  # Build query strings for multiple databases
  query_strings <- .build_query_strings(
    framework = framework,
    population = population,
    intervention = intervention,
    comparison = comparison,
    outcome = outcome,
    exposure = exposure,
    design = design,
    include_terms = include_terms,
    exclude_terms = exclude_terms
  )

  # Build LLM screening prompt template
  prompt_template <- .build_screening_prompt(
    text = text,
    framework = framework,
    population = population,
    intervention = intervention,
    comparison = comparison,
    outcome = outcome,
    exposure = exposure,
    design = design,
    include_terms = include_terms,
    exclude_terms = exclude_terms
  )

  structure(
    list(
      id = qid,
      text = text,
      framework = framework,
      created = Sys.time(),
      population = population,
      intervention = intervention,
      comparison = comparison,
      outcome = outcome,
      exposure = exposure,
      design = design,
      timeframe = timeframe,
      include_terms = include_terms,
      exclude_terms = exclude_terms,
      languages = languages,
      notes = notes,
      query_strings = query_strings,
      prompt_template = prompt_template
    ),
    class = "sm_question"
  )
}

#' Test if an object is an sm_question
#' @param x An object to test.
#' @return Logical.
#' @family question
#' @export
is_sm_question <- function(x) {
  inherits(x, "sm_question")
}

#' Validate framework-specific fields
#' @noRd
.validate_question_fields <- function(framework, population, intervention,
                                      comparison, outcome, exposure,
                                      design) {
  if (framework == "free") return(invisible(NULL))

  if (framework %in% c("PICO", "PICOS") && is.null(intervention)) {
    cli::cli_inform(c(
      "!" = "{framework} framework: {.arg intervention} not specified.",
      "i" = "Query strings may be less precise without it."
    ))
  }

  if (framework == "PECO" && is.null(exposure)) {
    cli::cli_inform(c(
      "!" = "PECO framework: {.arg exposure} not specified.",
      "i" = "Query strings may be less precise without it."
    ))
  }

  if (framework == "PICOS" && is.null(design)) {
    cli::cli_inform(c(
      "!" = "PICOS framework: {.arg design} not specified."
    ))
  }

  invisible(NULL)
}

#' Build database query strings from structured fields
#' @noRd
.build_query_strings <- function(framework, population, intervention,
                                 comparison, outcome, exposure,
                                 design, include_terms, exclude_terms) {
  # Collect non-NULL field terms
  terms <- list()

  if (!is.null(population)) terms$population <- population
  if (!is.null(intervention)) terms$intervention <- intervention
  if (!is.null(comparison)) terms$comparison <- comparison
  if (!is.null(outcome)) terms$outcome <- outcome
  if (!is.null(exposure)) terms$exposure <- exposure
  if (!is.null(design)) terms$design <- design

  if (length(terms) == 0L) {
    # Free-form: use include_terms or empty
    base_query <- paste(include_terms %||% character(), collapse = " AND ")
    if (!nzchar(base_query)) base_query <- "*"
  } else {
    # AND together the structured facets
    base_parts <- vapply(terms, function(t) {
      paste0("(", t, ")")
    }, character(1))
    base_query <- paste(base_parts, collapse = " AND ")
  }

  # Add include terms
  if (!is.null(include_terms) && length(include_terms) > 0L) {
    inc <- paste0("(", paste(include_terms, collapse = " OR "), ")")
    base_query <- paste(base_query, "AND", inc)
  }

  # Add exclude terms
  exclude_clause <- ""
  if (!is.null(exclude_terms) && length(exclude_terms) > 0L) {
    exclude_clause <- paste0(
      " NOT (",
      paste(exclude_terms, collapse = " OR "),
      ")"
    )
  }

  # PubMed query (MeSH-aware)
  pubmed_parts <- c()
  if (!is.null(population)) {
    pubmed_parts <- c(pubmed_parts, paste0("(", population, "[tiab])"))
  }
  if (!is.null(intervention)) {
    pubmed_parts <- c(pubmed_parts, paste0("(", intervention, "[tiab])"))
  }
  if (!is.null(exposure)) {
    pubmed_parts <- c(pubmed_parts, paste0("(", exposure, "[tiab])"))
  }
  if (!is.null(outcome)) {
    pubmed_parts <- c(pubmed_parts, paste0("(", outcome, "[tiab])"))
  }
  pubmed_query <- if (length(pubmed_parts) > 0L) {
    paste(pubmed_parts, collapse = " AND ")
  } else {
    base_query
  }

  list(
    generic = paste0(base_query, exclude_clause),
    pubmed = paste0(pubmed_query, exclude_clause),
    openalex = base_query,
    crossref = base_query
  )
}

#' Build LLM screening prompt template
#' @noRd
.build_screening_prompt <- function(text, framework, population, intervention,
                                    comparison, outcome, exposure, design,
                                    include_terms, exclude_terms) {
  parts <- c(
    "You are a systematic review screening assistant.",
    "",
    paste0("Research question: ", text),
    paste0("Framework: ", framework)
  )

  if (!is.null(population)) {
    parts <- c(parts, paste0("Population: ", population))
  }
  if (!is.null(intervention)) {
    parts <- c(parts, paste0("Intervention: ", intervention))
  }
  if (!is.null(exposure)) {
    parts <- c(parts, paste0("Exposure: ", exposure))
  }
  if (!is.null(comparison)) {
    parts <- c(parts, paste0("Comparison: ", comparison))
  }
  if (!is.null(outcome)) {
    parts <- c(parts, paste0("Outcome: ", outcome))
  }
  if (!is.null(design)) {
    parts <- c(parts, paste0("Study design: ", design))
  }

  parts <- c(parts, "", "Inclusion criteria:")
  if (!is.null(include_terms)) {
    parts <- c(parts, paste0("  - Must contain: ", paste(include_terms, collapse = ", ")))
  }
  if (!is.null(exclude_terms)) {
    parts <- c(parts, paste0("  - Must NOT contain: ", paste(exclude_terms, collapse = ", ")))
  }

  parts <- c(parts, "",
    "For each work, respond with a JSON object:",
    '{"decision": "include"|"exclude"|"uncertain", "reason": "brief explanation", "confidence": 0.0-1.0}',
    "",
    "Title: {{title}}",
    "Abstract: {{abstract}}"
  )

  paste(parts, collapse = "\n")
}

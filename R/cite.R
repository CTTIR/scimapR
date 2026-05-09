#' Generate citation block for a corpus
#'
#' @description
#' Produces a structured citation block for a corpus that can be included
#' in manuscripts. The block documents the number of works, sources queried,
#' date range, scimapR version, and corpus hash for reproducibility.
#'
#' @param corpus An `sm_corpus` object.
#' @param style Character. Citation style: `"text"` for a plain-text
#'   paragraph, `"bibtex"` for a BibTeX entry, or `"yaml"` for a YAML block.
#' @param call Caller environment for error reporting.
#'
#' @return A character string containing the formatted citation. Printed
#'   to the console and returned invisibly.
#'
#' @family reproducibility
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_cite_corpus(corpus)
sm_cite_corpus <- function(corpus,
                           style = c("text", "bibtex", "yaml"),
                           call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  style <- match.arg(style)

  n_works <- nrow(corpus$works)
  n_authors <- nrow(corpus$authors)
  n_sources <- length(unique(corpus$provenance$source))

  yr_range <- if (n_works > 0L && any(!is.na(corpus$works$year))) {
    rng <- range(corpus$works$year, na.rm = TRUE)
    paste0(rng[1], "-", rng[2])
  } else {
    "N/A"
  }

  build_date <- format(corpus$metadata$build_date, "%Y-%m-%d")
  pkg_version <- corpus$metadata$scimapR_version %||% "unknown"
  corpus_hash <- tryCatch(
    substr(sm_hash_corpus(corpus), 1, 12),
    error = function(e) "N/A"
  )

  prov_sources <- if (nrow(corpus$provenance) > 0L) {
    unique_src <- unique(corpus$provenance$source)
    unique_src <- unique_src[!grepl("_refresh$", unique_src)]
    paste(unique_src, collapse = ", ")
  } else {
    "N/A"
  }

  if (style == "text") {
    citation <- paste0(
      "Corpus assembled using scimapR v", pkg_version,
      " on ", build_date, ". ",
      "Contains ", n_works, " works by ", n_authors, " authors ",
      "(", yr_range, "). ",
      "Data sources: ", prov_sources, ". ",
      "Corpus hash: ", corpus_hash, "."
    )
  } else if (style == "bibtex") {
    citation <- paste0(
      "@misc{scimapR_corpus_", gsub("-", "", build_date), ",\n",
      "  title = {scimapR Corpus},\n",
      "  note = {", n_works, " works, ", n_authors, " authors, ",
      yr_range, "},\n",
      "  howpublished = {Assembled with scimapR v", pkg_version, "},\n",
      "  year = {", format(Sys.Date(), "%Y"), "},\n",
      "  url = {https://github.com/CTTIR/scimapR},\n",
      "  note = {hash: ", corpus_hash, "}\n",
      "}"
    )
  } else {
    citation <- paste0(
      "corpus_citation:\n",
      "  tool: scimapR\n",
      "  version: \"", pkg_version, "\"\n",
      "  build_date: \"", build_date, "\"\n",
      "  n_works: ", n_works, "\n",
      "  n_authors: ", n_authors, "\n",
      "  year_range: \"", yr_range, "\"\n",
      "  sources: \"", prov_sources, "\"\n",
      "  corpus_hash: \"", corpus_hash, "\"\n"
    )
  }

  cli::cli_text(citation)
  invisible(citation)
}

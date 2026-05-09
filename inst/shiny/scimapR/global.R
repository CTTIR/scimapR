# global.R -- scimapR Shiny application setup
# This file is sourced once at app startup.

# -- Load corpus from options (set by sm_run_app) or fall back to example ------
corpus_data <- getOption("scimapR.shiny_corpus")
if (is.null(corpus_data)) {
  corpus_data <- scimapR::sm_example_corpus(seed = 42)
}

# -- Pre-compute summary statistics -------------------------------------------
n_works   <- nrow(corpus_data$works)
n_authors <- nrow(corpus_data$authors)
n_sources <- nrow(corpus_data$sources)
n_refs    <- nrow(corpus_data$references)

year_range <- if (n_works > 0 && any(!is.na(corpus_data$works$year))) {
  range(corpus_data$works$year, na.rm = TRUE)
} else {
  c(NA_integer_, NA_integer_)
}

has_embeddings <- !is.null(corpus_data$embeddings) &&
  nrow(corpus_data$embeddings) > 0
has_screening  <- nrow(corpus_data$screening) > 0

# -- Author lookup table -------------------------------------------------------
author_names <- if (nrow(corpus_data$authors) > 0) {
  stats::setNames(corpus_data$authors$author_id,
                  corpus_data$authors$display_name)
} else {
  character(0)
}

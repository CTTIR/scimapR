# Helper: build an empty sm_corpus (no works) for empty-input branch tests.
make_empty_corpus <- function() {
  sm_corpus(.empty_works())
}

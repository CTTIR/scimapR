test_that("corpus modifiers reject locked inputs before other work", {
  locked <- suppressMessages(sm_lock(sm_example_corpus(
    n_works = 10, n_authors = 5, seed = 1
  )))
  locked$works$doi <- NA_character_
  locked$authors$orcid <- NA_character_
  local_mocked_bindings(req_perform = function(...) {
    stop("network access attempted")
  }, .package = "httr2")
  local_mocked_bindings(check_installed = function(...) {
    stop("package check attempted")
  }, .package = "rlang")
  local_mocked_bindings(.openalex_request = function(...) {
    stop("network access attempted")
  })
  plain <- sm_example_corpus(n_works = 3, seed = 2)
  modifiers <- list(
    bind_first = function(x) sm_bind_corpora(x, plain),
    bind_second = function(x) sm_bind_corpora(plain, x),
    dedupe = function(x) sm_dedupe(x),
    materialise = function(x) sm_materialise(x, list()),
    maturity = function(x) sm_citation_maturity(x),
    altmetric = function(x) sm_enrich_altmetric(x),
    concepts = function(x) sm_enrich_concepts(x),
    retraction = function(x) sm_enrich_retraction(x),
    orcid = function(x) sm_enrich_orcid(x),
    ror = function(x) sm_enrich_ror(x),
    citations = function(x) sm_enrich_opencitations(x),
    unpaywall = function(x) sm_enrich_unpaywall(x, mailto = "test@example.org"),
    impact = function(x) sm_enrich_openalex_impact(x),
    specter = function(x) sm_enrich_specter(x),
    embed = function(x) sm_embed_works(x, model = "invalid"),
    load = function(x) sm_embed_load(x, "missing-file"),
    kmeans = function(x) sm_cluster_kmeans(x, k = 2, reducer = "pca"),
    hdbscan = function(x) sm_cluster_hdbscan(x, reducer = "pca"),
    leiden = function(x) sm_cluster_leiden(x),
    label = function(x) sm_cluster_label(x),
    affiliation = function(x) sm_affiliation_match(x),
    institution = function(x) sm_attribute_institution(x),
    screen = function(x) sm_screen_against_question(x, question = NULL),
    regex = function(x) sm_screen_regex(x, include_terms = "study"),
    decisions = function(x) sm_merge_screening_decisions(x, tibble::tibble()),
    refresh = function(x) sm_refresh(x),
    input = function(x) sm_register_input(x, "missing-file")
  )
  for (name in names(modifiers)) {
    result <- tryCatch(
      suppressWarnings(suppressMessages(modifiers[[name]](locked))),
      error = identity
    )
    expect_true(inherits(result, "scimapR_corpus_locked"), info = name)
  }
})

test_that("locks record a content hash and subsets keep only lock status", {
  x <- sm_example_corpus(n_works = 10, n_authors = 5, seed = 1)
  locked <- suppressMessages(sm_lock(x))
  expect_identical(locked$metadata$lock_hash, sm_hash_corpus(x))
  expect_identical(suppressMessages(sm_lock(locked)), locked)
  sub <- locked[1:3]
  expect_true(sub$metadata$is_locked)
  expect_null(sub$metadata$lock_hash)
  expect_error(sm_cluster_kmeans(sub, k = 2), class = "scimapR_corpus_locked")
  unlocked <- suppressMessages(sm_unlock(locked, confirm = TRUE))
  expect_null(unlocked$metadata$lock_hash)
  bound <- sm_bind_corpora(unlocked, x, verbose = FALSE)
  expect_false(bound$metadata$is_locked)
  for (entry in c("locked_at", "lock_reason", "lock_hash")) {
    expect_null(bound$metadata[[entry]])
  }
  old <- locked
  old$metadata$lock_hash <- NULL
  expect_null(suppressMessages(sm_lock(old))$metadata$lock_hash)
})

# Tests for sm_enrich_openalex_impact() (offline: httptest2 mocks in
# fixtures/openalex-impact-api, fixtures/openalex-impact-429 and
# fixtures/openalex-impact-none; see helper-openalex.R).

test_that("the enrichment joins the impact fields by OpenAlex id and DOI", {
  corpus <- openalex_wos_corpus()
  out <- with_openalex_mocks("openalex-impact-api",
                             sm_enrich_openalex_impact(corpus, verbose = FALSE))
  expect_s3_class(out, "sm_corpus")
  w <- out$works
  # WOS 1: the DOI record with the most yearly citations of the two
  # records OpenAlex has for it; WOS 2: an upper-case DOI, found, without
  # fwci; WOS 3: looked up by its OpenAlex id; WOS 4: not on OpenAlex, so
  # its own fwci stays; WOS 5: no identifier; WOS 6: a DOI with a comma
  expect_equal(w$fwci, c(1.7, NA, 1.1, 0.9, NA, NA))
  expect_equal(w$citation_percentile, c(0.91, NA, 0.8, NA, NA, NA))
  expect_identical(w$is_top_10pct, c(TRUE, NA, FALSE, NA, NA, NA))
  expect_identical(w$is_top_1pct, c(FALSE, NA, FALSE, NA, NA, NA))
  expect_identical(w$citations_as_of,
                   as.Date(c("2026-10-15", "2026-10-14", "2026-10-15",
                             NA, NA, NA)))
  # other columns keep the values of their source
  expect_identical(w$cited_by_count, corpus$works$cited_by_count)
  expect_identical(w$openalex_id, corpus$works$openalex_id)
  expect_identical(out$metadata$last_refresh, corpus$metadata$last_refresh)

  # the yearly rows of the works found are replaced, the others stay
  yearly <- out$citations_by_year
  ids <- w$work_id
  expect_identical(yearly$work_id, ids[c(1, 1, 1, 3, 3, 4)])
  expect_identical(yearly$year, c(2020L, 2021L, 2023L, 2022L, 2023L, 2023L))
  expect_identical(yearly$cited_by_count, c(3L, 4L, 2L, 2L, 3L, 1L))
  expect_identical(nrow(sm_validate(out)), 0L)

  # provenance: one enrichment row per work found
  prov <- out$provenance[out$provenance$source == "openalex_impact", ]
  expect_identical(prov$work_id, ids[1:3])
  expect_identical(prov$source_id_external,
                   c("W9999200001", "W9999200002", "W9999200003"))
  expect_identical(unique(prov$kind), "enrichment")
  expect_identical(unique(prov$query),
                   "sm_enrich_openalex_impact(by = openalex_id, doi)")
  expect_identical(nrow(out$provenance), nrow(corpus$provenance) + 3L)
})

test_that("the enrichment reports what it found and what it left out", {
  corpus <- openalex_wos_corpus()
  msgs <- with_openalex_mocks(
    "openalex-impact-api",
    testthat::capture_messages(sm_enrich_openalex_impact(corpus))
  )
  msgs <- paste(msgs, collapse = "")
  expect_match(msgs, "4 works on OpenAlex in 2 batches", fixed = TRUE)
  expect_match(msgs, "3 of 6 works (1 not found on OpenAlex)", fixed = TRUE)
  expect_match(msgs, "1 work without an identifier", fixed = TRUE)
  expect_match(msgs, "1 with a DOI that contains a comma", fixed = TRUE)
})

test_that("a second run updates the values and keeps one row per year", {
  corpus <- openalex_wos_corpus()
  once <- with_openalex_mocks(
    "openalex-impact-api",
    sm_enrich_openalex_impact(corpus, verbose = FALSE)
  )
  once$works$fwci[1] <- 99
  # values of an earlier run or of another source where OpenAlex now has
  # none (WOS 2: null fwci and percentile) or no record at all (WOS 4)
  once$works$fwci[2] <- 3.3
  once$works$citation_percentile[2] <- 0.95
  once$works$is_top_10pct[2] <- TRUE
  once$works$is_top_1pct[2] <- FALSE
  once$works$citations_as_of[4] <- as.Date("2025-01-01")
  twice <- with_openalex_mocks(
    "openalex-impact-api",
    sm_enrich_openalex_impact(once, verbose = FALSE)
  )
  expect_identical(twice$works$fwci[1], 1.7)
  # a work found takes every value of its record, NA included, so its
  # values, their date and its yearly counts stay one record's
  expect_identical(twice$works$fwci[2], NA_real_)
  expect_identical(twice$works$citation_percentile[2], NA_real_)
  expect_identical(twice$works$is_top_10pct[2], NA)
  expect_identical(twice$works$is_top_1pct[2], NA)
  expect_identical(twice$works$citations_as_of[2], as.Date("2026-10-14"))
  # a work not found keeps its values and their date
  expect_identical(twice$works$fwci[4], 0.9)
  expect_identical(twice$works$citations_as_of[4], as.Date("2025-01-01"))
  expect_identical(twice$citations_by_year, once$citations_by_year)
  expect_identical(names(twice$works), names(once$works))
})

test_that("the columns are added even when OpenAlex has none of the works", {
  corpus <- openalex_wos_corpus()
  corpus$works$fwci <- NULL
  corpus$citations_by_year <- NULL
  msgs <- with_openalex_mocks(
    "openalex-impact-none",
    testthat::capture_messages(out <- sm_enrich_openalex_impact(corpus))
  )
  expect_match(paste(msgs, collapse = ""),
               "OpenAlex has none of the 4 works looked up", fixed = TRUE)
  w <- out$works
  expect_identical(setdiff(names(w), names(corpus$works)),
                   c("fwci", "citation_percentile", "is_top_10pct",
                     "is_top_1pct", "citations_as_of"))
  expect_identical(w$fwci, rep(NA_real_, 6))
  expect_identical(w$citation_percentile, rep(NA_real_, 6))
  expect_identical(w$is_top_10pct, rep(NA, 6))
  expect_identical(w$is_top_1pct, rep(NA, 6))
  expect_identical(w$citations_as_of, as.Date(rep(NA, 6)))
  expect_identical(out$citations_by_year,
                   scimapR:::.empty_citations_by_year())
  expect_identical(out$provenance, corpus$provenance)
  expect_identical(nrow(sm_validate(out)), 0L)

  # values already there stay, as none of their works was found
  corpus <- openalex_wos_corpus()
  kept <- with_openalex_mocks(
    "openalex-impact-none",
    sm_enrich_openalex_impact(corpus, verbose = FALSE)
  )
  expect_identical(kept$works$fwci, corpus$works$fwci)
  expect_identical(kept$citations_by_year, corpus$citations_by_year)
})

test_that("a citations_as_of stored as a day count keeps its date", {
  # A corpus restored from SQLite (through RSQLite) holds the dates as days
  # since 1970-01-01; the enrichment read them as text and lost them
  # without a message.
  corpus <- openalex_wos_corpus()
  day <- as.numeric(as.Date("2025-01-01"))
  corpus$works$citations_as_of <- c(day, NA, NA, day, NA, day)
  out <- with_openalex_mocks(
    "openalex-impact-api",
    sm_enrich_openalex_impact(corpus, verbose = FALSE)
  )
  expect_identical(out$works$citations_as_of,
                   as.Date(c("2026-10-15", "2026-10-14", "2026-10-15",
                             "2025-01-01", NA, "2025-01-01")))
  expect_identical(
    .coerce_impact_columns(corpus)$works$citations_as_of,
    as.Date(c("2025-01-01", NA, NA, "2025-01-01", NA, "2025-01-01"))
  )
})

test_that("HTTP 429 stops the enrichment at once and joins nothing", {
  corpus <- openalex_wos_corpus()
  err <- with_openalex_mocks(
    "openalex-impact-429",
    expect_error(sm_enrich_openalex_impact(corpus, verbose = FALSE),
                 class = "scimapR_openalex_rate_limit")
  )
  msg <- conditionMessage(err)
  expect_match(msg, "resets at [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8} UTC")
  expect_match(msg, "X-RateLimit-Remaining-USD", fixed = TRUE)
  expect_match(msg, "OPENALEX_API_KEY", fixed = TRUE)
  expect_match(msg, "1 of 2 batches had been fetched", fixed = TRUE)
  expect_match(msg, "Nothing was joined", fixed = TRUE)
  expect_identical(err$n_done, 1L)
  expect_identical(err$n_fetched, 1L)
  expect_identical(err$remaining, "0")
  # the corpus is unchanged: no impact columns, no new provenance
  expect_false("citation_percentile" %in% names(corpus$works))
  expect_identical(nrow(corpus$citations_by_year), 3L)
})

test_that("by sets the identifiers and their order", {
  corpus <- openalex_wos_corpus()
  keys <- .openalex_lookup_keys(corpus$works, "doi")
  expect_identical(keys$type, c(rep("doi", 4), NA, NA))
  expect_identical(keys$key[3], "10.9999/enr.003")
  keys <- .openalex_lookup_keys(corpus$works, "openalex_id")
  expect_identical(keys$type, c(NA, NA, "openalex_id", NA, NA, NA))
  expect_false(any(keys$unsafe_doi))
  keys <- .openalex_lookup_keys(corpus$works, c("doi", "openalex_id"))
  expect_identical(keys$type[3], "doi")
  expect_identical(.openalex_short_id(c("https://openalex.org/W12", "w7",
                                        "A12", NA)),
                   c("W12", "W7", NA, NA))
  batches <- .openalex_key_batches(
    .openalex_lookup_keys(corpus$works, c("openalex_id", "doi")), 2L
  )
  expect_identical(vapply(batches, function(b) b$filter_key, character(1)),
                   c("openalex", "doi", "doi"))
  expect_identical(lengths(lapply(batches, `[[`, "values")), c(1L, 2L, 1L))
  expect_error(sm_enrich_openalex_impact(corpus, by = "pmid"),
               class = "rlang_error")
})

test_that("the batch size is capped at 100, and empty corpora pass through", {
  corpus <- openalex_wos_corpus()
  expect_message(
    with_openalex_mocks(
      "openalex-impact-api",
      sm_enrich_openalex_impact(corpus, batch_size = 500L)
    ),
    "lowered to 100"
  )
  empty <- sm_corpus(works = scimapR:::.empty_works())
  expect_identical(sm_enrich_openalex_impact(empty, verbose = FALSE), empty)
  no_ids <- corpus[5]
  expect_identical(sm_enrich_openalex_impact(no_ids, verbose = FALSE),
                   no_ids)
})

test_that("neither the key nor the mailto is stored or shown", {
  skip_if_not_installed("yaml")
  corpus <- openalex_wos_corpus()
  key <- "KEY-9999-SECRET"
  msgs <- with_openalex_mocks("openalex-impact-api", {
    withr::local_envvar(SCIMAPR_MAILTO = "lab@example.org")
    testthat::capture_messages(
      out <- sm_enrich_openalex_impact(corpus, api_key = key)
    )
  })
  prov <- out$provenance
  text <- c(unlist(lapply(prov, as.character)), msgs)
  cert <- suppressMessages(sm_certificate(out))
  text <- c(text, unlist(cert$queries),
            yaml::as.yaml(scimapR:::.cert_to_list(cert)))
  expect_false(any(grepl(key, text, fixed = TRUE)))
  expect_false(any(grepl("example.org", text, fixed = TRUE)))
  expect_false(any(grepl("api.openalex.org", text, fixed = TRUE)))
  expect_false(any(grepl("10.9999/enr.001|", text, fixed = TRUE)))

  err <- with_openalex_mocks(
    "openalex-impact-429",
    expect_error(sm_enrich_openalex_impact(corpus, api_key = key,
                                           verbose = FALSE),
                 class = "scimapR_openalex_rate_limit")
  )
  expect_false(grepl(key, conditionMessage(err), fixed = TRUE))
  expect_match(conditionMessage(err), "An API key was sent", fixed = TRUE)
})

test_that("a certificate rebuild never replays the enrichment step", {
  skip_if_not_installed("yaml")
  corpus <- with_openalex_mocks(
    "openalex-impact-api",
    sm_enrich_openalex_impact(openalex_wos_corpus(), verbose = FALSE)
  )
  corpus$provenance$source[corpus$provenance$source == "wos"] <- "synthetic"
  cert <- suppressMessages(sm_certificate(corpus))
  kinds <- vapply(cert$queries, function(q) q$kind, character(1))
  sources <- vapply(cert$queries, function(q) q$source, character(1))
  expect_identical(kinds[sources == "openalex_impact"], "enrichment")
  fetched <- character()
  fetch <- function(source) {
    function(...) {
      fetched <<- c(fetched, source)
      sm_corpus(works = scimapR:::.empty_works())
    }
  }
  local_mocked_bindings(
    sm_fetch_openalex = fetch("openalex"),
    sm_fetch_pubmed = fetch("pubmed"),
    sm_fetch_crossref = fetch("crossref")
  )
  expect_message(rebuilt <- sm_rebuild_from_cert(cert, verbose = FALSE),
                 "\"openalex_impact\" (enrichment)", fixed = TRUE)
  expect_identical(fetched, character())
  expect_identical(nrow(rebuilt$works), 0L)

  # next to a search, only the search is replayed
  search <- list(source = "openalex", query = "field surgery",
                 engine = "native", kind = "api_query", n_max = 5L)
  with_search <- cert
  with_search$queries <- c(cert$queries, list(search))
  expect_message(
    rebuilt <- sm_rebuild_from_cert(with_search, verbose = FALSE),
    "\"openalex_impact\" (enrichment)", fixed = TRUE
  )
  expect_identical(fetched, "openalex")
  expect_identical(nrow(rebuilt$works), 0L)

  # a certificate written before step kinds infers them from the source
  fetched <- character()
  cert$queries <- lapply(cert$queries, function(q) {
    q[c("source", "query", "engine")]
  })
  rebuilt <- suppressMessages(sm_rebuild_from_cert(cert, verbose = FALSE))
  expect_identical(fetched, character())
})

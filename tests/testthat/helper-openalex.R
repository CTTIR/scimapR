# Helpers for the OpenAlex impact tests: a small corpus as Web of Science
# files give it (no OpenAlex ids but one), the saved works in
# fixtures/openalex-impact.json and the httptest2 mocks of the enrichment
# requests in fixtures/openalex-impact-api (every request answered),
# fixtures/openalex-impact-429 (the second batch answered with HTTP 429)
# and fixtures/openalex-impact-none (no request finds a work).
# All works, DOIs (10.9999/...) and ids are invented.
openalex_wos_corpus <- function() {
  ids <- sprintf("WOS:0009999000000%02d", 1:6)
  works <- tibble::tibble(
    work_id = ids,
    doi = c("10.9999/enr.001", "10.9999/ENR.002", "10.9999/enr.003",
            "10.9999/enr.004", NA, "10.9999/enr,006"),
    openalex_id = c(NA, NA, "https://openalex.org/W9999200003", NA, NA, NA),
    title = paste("Synthetic field-medicine work", 1:6),
    year = 2019:2024,
    cited_by_count = c(10L, 4L, 7L, 0L, 1L, 2L),
    fwci = c(0.5, NA, NA, 0.9, NA, NA)
  )
  yearly <- tibble::tibble(
    work_id = ids[c(1, 1, 4)],
    year = c(2019L, 2020L, 2023L),
    cited_by_count = c(1L, 2L, 1L)
  )
  provenance <- tibble::tibble(
    work_id = ids, source = "wos", source_id_external = ids,
    fetch_date = as.POSIXct("2026-10-01", tz = "UTC"),
    query = "synthetic Web of Science export", engine = "native",
    scimapR_version = "0.5.0", prompt_hash = NA_character_
  )
  suppressMessages(sm_corpus_from_tables(
    list(works = works, provenance = provenance, citations_by_year = yearly),
    metadata = list(last_refresh = 1792195200)
  ))
}

openalex_mock_dir <- function(name) {
  testthat::test_path("fixtures", name)
}

# Run code against the saved responses of one mock directory only. A
# request without a mock fails instead of reaching the network:
# with_mock_api() never records (with_mock_dir() would record into a
# directory it cannot find).
with_openalex_mocks <- function(name, code) {
  testthat::skip_if_not_installed("httptest2")
  dir <- normalizePath(openalex_mock_dir(name), mustWork = TRUE)
  withr::local_envvar(OPENALEX_API_KEY = "", SCIMAPR_MAILTO = "")
  withr::local_options(httptest2.mock.paths = dir)
  httptest2::with_mock_api(code)
}

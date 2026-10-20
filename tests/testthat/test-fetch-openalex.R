# Tests for R/fetch-openalex.R parsers (offline; no request is sent).

test_that("OpenAlex concepts are parsed into the openalex vocabulary", {
  results <- list(
    list(concepts = list(
      list(id = "https://openalex.org/C1", display_name = "Biology",
           level = 0L, score = 0.9),
      list(id = "https://openalex.org/C2", display_name = "Genetics",
           level = 1L, score = 0.4)
    )),
    list(concepts = list())
  )
  concepts <- .parse_openalex_concepts(results, c("W1", "W2"))
  expect_identical(concepts$work_id, c("W1", "W1"))
  expect_identical(concepts$concept_name, c("Biology", "Genetics"))
  expect_identical(concepts$vocabulary, c("openalex", "openalex"))
  expect_true(all(concepts$vocabulary %in% sm_concept_vocabularies()))
  expect_identical(.parse_openalex_concepts(list(), character()),
                   .empty_concepts())
})

test_that("the OpenAlex fetcher reads the corresponding author", {
  # The same saved works as for sm_read_openalex_json(): the second author
  # of W1 is corresponding, W2 and W3 do not tell (NA), W4 lists its
  # corresponding author in corresponding_author_ids.
  results <- jsonlite::fromJSON(test_path("fixtures",
                                          "openalex-corresponding.json"),
                                simplifyVector = FALSE)
  a <- .parse_openalex_authorships(results, paste0("W", 1:4))$authorships
  flags <- split(a$is_corresponding, a$work_id)
  expect_identical(unname(flags), list(c(FALSE, TRUE, FALSE), c(NA, NA),
                                       c(NA, NA), c(FALSE, TRUE)))
  expect_identical(a$position, c(1:3, 1:2, 1:2, 1:2))
})

# ---- impact fields (fixtures/openalex-impact.json) --------------------------

test_that("the native parser keeps fwci, percentiles and yearly counts", {
  results <- jsonlite::read_json(test_path("fixtures", "openalex-impact.json"))
  fetched <- as.POSIXct("2026-10-19 12:00:00", tz = "UTC")
  corpus <- suppressMessages(
    .parse_openalex_results(results, "test", FALSE, rlang::current_env(),
                            fetched = fetched)
  )
  w <- corpus$works
  expect_equal(w$fwci, c(2.4, NA, 0.35))
  expect_equal(w$citation_percentile, c(0.97, NA, 0.41))
  expect_identical(w$is_top_10pct, c(TRUE, NA, FALSE))
  expect_identical(w$is_top_1pct, c(FALSE, NA, FALSE))
  # the record's updated_date, else the day of the fetch
  expect_identical(w$citations_as_of,
                   as.Date(c("2026-10-01", "2026-09-30", "2026-10-19")))
  yearly <- corpus$citations_by_year
  expect_identical(yearly$work_id, w$work_id[c(1, 1, 1, 3)])
  expect_identical(yearly$year, c(2021L, 2023L, 2024L, 2025L))
  expect_identical(yearly$cited_by_count, c(4L, 5L, 3L, 1L))
  expect_no_error(validate_sm_corpus(corpus))
})

test_that("the native parser reads raw affiliation strings", {
  # raw_affiliation_strings (joined), else affiliations[], else the
  # institution names; the old single raw_affiliation_string still counts
  results <- jsonlite::read_json(test_path("fixtures", "openalex-impact.json"))
  a <- .parse_openalex_authorships(results, paste0("W", 1:3))$authorships
  expect_identical(a$raw_affiliation, c(
    paste("Northtown Field Hospital, Dept. of Emergency Medicine, Northtown;",
          "Reserve Medical Company 7, Northtown"),
    "Institute of Invented Microbiology, Southcity",
    "Southcity University Hospital",
    "Northtown Field Hospital"
  ))
  expect_false(anyNA(a$raw_affiliation))
  old <- list(list(authorships = list(list(
    author = list(id = "https://openalex.org/A9999100009",
                  display_name = "Old Record"),
    raw_affiliation_string = "Legacy Institute, Northtown"
  ))))
  a <- .parse_openalex_authorships(old, "W1")$authorships
  expect_identical(a$raw_affiliation, "Legacy Institute, Northtown")
  expect_identical(.openalex_raw_affiliation(list()), NA_character_)
})

test_that("the native parser stores ORCIDs without the URL prefix", {
  results <- jsonlite::read_json(test_path("fixtures", "openalex-impact.json"))
  authors <- .parse_openalex_authorships(results, paste0("W", 1:3))$authors
  expect_identical(unname(authors$orcid), c("0000-0002-9999-001X", NA, NA))
  expect_identical(
    .normalize_orcid(c("https://orcid.org/0000-0002-9999-001x",
                       "http://www.orcid.org/0000-0001-2345-6789",
                       " 0000-0001-2345-6789 ", "", NA)),
    c("0000-0002-9999-001X", "0000-0001-2345-6789", "0000-0001-2345-6789",
      NA, NA)
  )
  expect_identical(.normalize_orcid(NULL), NA_character_)
  expect_identical(.normalize_orcid(character()), character())
})

test_that("sm_fetch_openalex() stops on HTTP 429 with the reset time", {
  withr::local_envvar(OPENALEX_API_KEY = "", SCIMAPR_MAILTO = "")
  calls <- 0L
  local_mocked_bindings(
    req_perform = function(req, ...) {
      calls <<- calls + 1L
      httr2::response(
        status_code = 429L, url = "https://api.openalex.org/works",
        headers = list(`Retry-After` = "7200",
                       `X-RateLimit-Remaining` = "0"),
        body = charToRaw("{}")
      )
    },
    .package = "httr2"
  )
  err <- expect_error(
    sm_fetch_openalex(query = "field medicine", verbose = FALSE),
    class = "scimapR_openalex_rate_limit"
  )
  expect_identical(calls, 1L)
  expect_identical(err$n_fetched, 0L)
  msg <- conditionMessage(err)
  expect_match(msg, "resets at", fixed = TRUE)
  expect_match(msg, "0 works had been fetched", fixed = TRUE)
  expect_match(msg, "X-RateLimit-Remaining", fixed = TRUE)
  expect_match(msg, "OPENALEX_API_KEY", fixed = TRUE)
})

test_that("sm_fetch_openalex() pages through the API with the helper", {
  withr::local_envvar(OPENALEX_API_KEY = "", SCIMAPR_MAILTO = "")
  results <- jsonlite::read_json(test_path("fixtures", "openalex-impact.json"))
  local_mocked_bindings(
    req_perform = function(req, ...) {
      body <- list(meta = list(count = 3L, next_cursor = NULL),
                   results = results)
      httr2::response(
        status_code = 200L, url = "https://api.openalex.org/works",
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE,
                                          null = "null", digits = NA))
      )
    },
    .package = "httr2"
  )
  corpus <- suppressMessages(sm_fetch_openalex(query = "x", verbose = FALSE))
  expect_equal(corpus$works$fwci, c(2.4, NA, 0.35))
  expect_identical(nrow(corpus$citations_by_year), 4L)
})

# ---- the openalexR engine ----------------------------------------------------

openalexr_works <- function() {
  # works2df() columns of openalexR 3.1.2 (a subset)
  tibble::tibble(
    id = c("https://openalex.org/W9999100001",
           "https://openalex.org/W9999100002"),
    title = c("First", "Second"),
    display_name = c("First", "Second"),
    abstract = c("An abstract.", NA),
    doi = c("https://doi.org/10.9999/oaimp.2020.001", NA),
    publication_year = c(2020L, 2023L),
    fwci = c(2.4, NA),
    cited_by_count = c(12L, 0L),
    counts_by_year = list(
      data.frame(year = c(2024L, 2023L), cited_by_count = c(3L, 5L)),
      NA
    ),
    type = "article",
    oa_status = "closed",
    is_retracted = FALSE,
    language = "en"
  )
}

test_that("the openalexR engine keeps fwci and the yearly counts", {
  skip_if_not_installed("openalexR", minimum_version = "3.1.1")
  withr::local_envvar(OPENALEX_API_KEY = "", openalexR.max_tries = NA)
  seen <- list()
  local_mocked_bindings(
    oa_fetch = function(...) {
      seen <<- list(...)
      seen$max_tries <<- Sys.getenv("openalexR.max_tries")
      openalexr_works()
    },
    .package = "openalexR"
  )
  corpus <- suppressMessages(
    sm_fetch_openalex(query = "x", engine = "openalexR", verbose = FALSE)
  )
  w <- corpus$works
  expect_equal(w$fwci, c(2.4, NA))
  expect_identical(w$citation_percentile, c(NA_real_, NA_real_))
  expect_identical(w$is_top_10pct, c(NA, NA))
  expect_identical(w$abstract, c("An abstract.", NA))
  expect_false(anyNA(w$citations_as_of))
  expect_identical(corpus$citations_by_year$year, c(2023L, 2024L))
  # one attempt only, no mailto, per_page through options, no key given
  expect_identical(seen$max_tries, "1")
  expect_null(seen$mailto)
  expect_null(seen$api_key)
  expect_identical(seen$options$per_page, 200L)
  expect_identical(Sys.getenv("openalexR.max_tries", unset = "none"), "none")
})

test_that("the openalexR engine passes the key and turns 429 into an error", {
  skip_if_not_installed("openalexR", minimum_version = "3.1.1")
  withr::local_envvar(openalexR.apikey = NA)
  seen <- list()
  local_mocked_bindings(
    oa_fetch = function(...) {
      seen <<- list(...)
      seen$env_key <<- Sys.getenv("openalexR.apikey")
      cli::cli_warn("HTTP status 429 Too Many Requests",
                    class = c("openalexR_429", "openalexR_http_warning"))
      NULL
    },
    .package = "openalexR"
  )
  err <- expect_error(
    sm_fetch_openalex(query = "x", engine = "openalexR", api_key = "KEY-77",
                      verbose = FALSE),
    class = "scimapR_openalex_rate_limit"
  )
  expect_identical(seen$api_key, "KEY-77")
  expect_identical(seen$env_key, "KEY-77")
  expect_identical(Sys.getenv("openalexR.apikey", unset = "none"), "none")
  expect_true(err$key_set)
  expect_match(conditionMessage(err), "openalexR engine does not pass on",
               fixed = TRUE)
  expect_false(grepl("KEY-77", conditionMessage(err), fixed = TRUE))
})

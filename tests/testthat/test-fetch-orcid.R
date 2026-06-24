# Tests for sm_fetch_orcid() -- NO NETWORK.

.orcid_group <- function(title = "An ORCID Work",
                         doi = "10.1234/orcidwork",
                         year = "2021",
                         put_code = 99L) {
  list(
    `work-summary` = list(list(
      `put-code` = put_code,
      title = list(title = list(value = title)),
      `publication-date` = list(year = list(value = year)),
      type = "JOURNAL_ARTICLE",
      `journal-title` = list(value = "ORCID Journal"),
      `external-ids` = list(`external-id` = list(
        list(`external-id-type` = "doi", `external-id-value` = doi),
        list(`external-id-type` = "pmid", `external-id-value` = "44444444")
      ))
    ))
  )
}

.orcid_body <- function(groups) {
  list(group = groups)
}

test_that("sm_fetch_orcid validates the orcid argument", {
  expect_error(sm_fetch_orcid(orcid = ""), "non-empty")
  expect_error(sm_fetch_orcid(orcid = 123), "single string")
})

test_that("sm_fetch_orcid rejects malformed ORCID identifiers", {
  expect_error(sm_fetch_orcid(orcid = "not-an-orcid"), "valid ORCID")
  expect_error(sm_fetch_orcid(orcid = "1234-5678"), "valid ORCID")
})

test_that("sm_fetch_orcid parses works into an sm_corpus", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .orcid_body(list(.orcid_group())),
    .package = "httr2"
  )
  corpus <- sm_fetch_orcid("0000-0001-8006-9742", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 1L)
  expect_equal(corpus$works$title[[1]], "An ORCID Work")
  expect_equal(corpus$works$doi[[1]], "10.1234/orcidwork")
  expect_equal(corpus$works$year[[1]], 2021L)
  expect_equal(corpus$works$type[[1]], "journal-article")
  expect_equal(corpus$works$pmid[[1]], "44444444")
  expect_equal(corpus$works$source_id[[1]], "ORCID Journal")
  # single author entry is the ORCID holder
  expect_equal(nrow(corpus$authors), 1L)
  expect_equal(corpus$authors$orcid[[1]], "0000-0001-8006-9742")
  expect_equal(nrow(corpus$authorships), 1L)
  # provenance carries the put-code
  expect_true(all(corpus$provenance$source == "orcid"))
  expect_true("99" %in% corpus$provenance$source_id_external)
})

test_that("sm_fetch_orcid accepts a full https://orcid.org/ URL", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .orcid_body(list(.orcid_group())),
    .package = "httr2"
  )
  corpus <- sm_fetch_orcid("https://orcid.org/0000-0001-8006-9742",
                           verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(corpus$authors$orcid[[1]], "0000-0001-8006-9742")
})

test_that("sm_fetch_orcid verbose prints progress", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .orcid_body(list(.orcid_group())),
    .package = "httr2"
  )
  expect_message(
    sm_fetch_orcid("0000-0001-8006-9742", verbose = TRUE),
    "Fetching works for ORCID"
  )
})

test_that("sm_fetch_orcid returns empty corpus when no groups", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) .orcid_body(list()),
    .package = "httr2"
  )
  corpus <- sm_fetch_orcid("0000-0001-8006-9742", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_orcid returns empty corpus when groups have no summaries", {
  local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) {
      .orcid_body(list(list(`work-summary` = list())))
    },
    .package = "httr2"
  )
  corpus <- sm_fetch_orcid("0000-0001-8006-9742", verbose = FALSE)
  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
})

test_that("sm_fetch_orcid aborts on request failure", {
  local_mocked_bindings(
    req_perform = function(req, ...) stop("boom"),
    .package = "httr2"
  )
  expect_error(
    sm_fetch_orcid("0000-0001-8006-9742", verbose = FALSE),
    "ORCID API request failed"
  )
})

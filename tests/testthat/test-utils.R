test_that(".normalize_doi strips URL prefixes", {
  expect_equal(
    .normalize_doi("https://doi.org/10.1234/EXAMPLE"),
    "10.1234/example"
  )
  expect_equal(
    .normalize_doi("https://dx.doi.org/10.1234/EXAMPLE"),
    "10.1234/example"
  )
  expect_equal(
    .normalize_doi("doi: 10.1234/EXAMPLE"),
    "10.1234/example"
  )
})

test_that(".normalize_doi lowercases DOIs", {
  expect_equal(.normalize_doi("10.1234/ABC"), "10.1234/abc")
})

test_that(".normalize_doi returns NA for empty or NULL", {
  expect_true(is.na(.normalize_doi("")))
  expect_true(is.na(.normalize_doi(NULL)))
  expect_true(is.na(.normalize_doi("   ")))
})

test_that(".normalize_doi handles vector input", {
  dois <- c("https://doi.org/10.1234/A", "10.5678/B", "", NA)
  result <- .normalize_doi(dois)

  expect_equal(result[1], "10.1234/a")
  expect_equal(result[2], "10.5678/b")
  expect_true(is.na(result[3]))
  expect_true(is.na(result[4]))
})

test_that(".generate_work_id produces correct format", {
  ids <- .generate_work_id(3)

  expect_length(ids, 3L)
  expect_true(all(grepl("^W\\d{9}$", ids)))
  expect_equal(ids, c("W000000001", "W000000002", "W000000003"))
})

test_that(".generate_work_id handles n = 1", {
  id <- .generate_work_id(1)
  expect_equal(id, "W000000001")
})

test_that(".check_file_exists errors for missing file", {
  expect_error(.check_file_exists("nonexistent_file_12345.txt"),
               "not found")
})

test_that(".check_file_exists passes for existing file", {
  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "exists.txt")
  writeLines("test", path)

  expect_no_error(.check_file_exists(path))
})

test_that(".check_string validates string input", {
  expect_no_error(.check_string("hello"))
  expect_error(.check_string(42), "single string")
  expect_error(.check_string(c("a", "b")), "single string")
  expect_error(.check_string(""), "non-empty")
})

test_that(".check_string allows null when specified", {
  expect_no_error(.check_string(NULL, allow_null = TRUE))
  expect_error(.check_string(NULL), "single string")
})

test_that(".check_string allows empty when specified", {
  expect_no_error(.check_string("", allow_empty = TRUE))
  expect_error(.check_string(""), "non-empty")
})

test_that(".generate_author_id produces correct format", {
  ids <- .generate_author_id(2)

  expect_length(ids, 2L)
  expect_true(all(grepl("^A\\d{9}$", ids)))
})

test_that(".check_sm_corpus rejects non-corpus", {
  expect_error(.check_sm_corpus("not a corpus"), "sm_corpus")
})

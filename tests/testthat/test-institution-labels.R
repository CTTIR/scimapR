# Tests for the institution labels of authorship rows (R/institution-labels.R).

label_authorships <- function() {
  tibble::tibble(
    work_id = c("W1", "W1", "W2", "W3"),
    author_id = c("A1", "A2", "A3", "A4"),
    institution_match = c("Unit North", NA, NA, NA),
    institution_name = c(NA, "Unit South", NA, NA),
    institution_id = c(NA, NA, "I1", "I2"),
    country_code = c("DE", "DE", "NL", "NO")
  )
}

label_institutions <- function() {
  tibble::tibble(institution_id = c("I1", "I9"),
                 display_name = c("Coastal Institute", "Unused"))
}

test_that("one column labels every row, in order of precedence", {
  a <- label_authorships()
  res <- .resolve_institution_labels(a, label_institutions())
  expect_identical(res$column, "institution_match")
  expect_identical(res$label, c("Unit North", NA, NA, NA))

  a$institution_match <- NA_character_
  res <- .resolve_institution_labels(a, label_institutions())
  expect_identical(res$column, "institution_name")
  expect_identical(res$label, c(NA, "Unit South", NA, NA))

  # institution_id is named through the institutions table when listed
  a$institution_name <- NULL
  res <- .resolve_institution_labels(a, label_institutions())
  expect_identical(res$column, "institution_id")
  expect_identical(res$label, c(NA, NA, "Coastal Institute", "I2"))
  expect_identical(.resolve_institution_labels(a, NULL)$label,
                   c(NA, NA, "I1", "I2"))
})

test_that("a column without any value is not usable", {
  a <- label_authorships()
  a$institution_match <- NA_character_
  a$institution_name <- c("", " ", NA, NA)
  a$institution_id <- NA_character_
  res <- .resolve_institution_labels(a, label_institutions())
  expect_identical(res$column, "country_code")
  expect_identical(res$label, a$country_code)

  res <- .resolve_institution_labels(a, label_institutions(),
                                     country_fallback = FALSE)
  expect_identical(res$column, NA_character_)
  expect_identical(res$label, rep(NA_character_, 4))
  expect_identical(.institution_label_columns(FALSE),
                   c("institution_match", "institution_name",
                     "institution_id"))

  empty <- .resolve_institution_labels(a[0, ], NULL)
  expect_identical(empty$label, character())
  expect_identical(empty$column, NA_character_)
})

test_that("row by row, each row takes its first column with a value", {
  a <- label_authorships()
  a$raw_affiliation <- c("x", "y", "z", "Somewhere")
  a$institution_id[4] <- NA_character_
  res <- .institution_labels_by_row(
    a, label_institutions(),
    c(.institution_label_columns(FALSE), "raw_affiliation")
  )
  expect_identical(res$label, c("Unit North", "Unit South",
                                "Coastal Institute", "Somewhere"))
  expect_identical(res$column, c("institution_match", "institution_name",
                                 "institution_id", "raw_affiliation"))
})

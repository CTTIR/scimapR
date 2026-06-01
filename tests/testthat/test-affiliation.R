# Tests for Part B: affiliation matching and institution attribution.

test_that("sm_affiliation_match tags affiliations via pattern", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 6)
  corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin, Germany"
  corpus$authorships$raw_affiliation[2] <- "Charite - Universitatsmedizin Berlin"
  corpus$authorships$raw_affiliation[3] <- "Some Unrelated University"

  out <- sm_affiliation_match(corpus)
  expect_true(all(c("institution_match", "match_method") %in%
                    names(out$authorships)))
  expect_identical(out$authorships$institution_match[1], "Bundeswehr Hospital")
  expect_identical(out$authorships$institution_match[2], "Charite Berlin")
  expect_identical(out$authorships$match_method[1], "pattern")
  expect_identical(out$authorships$institution_match[3], NA_character_)
  expect_identical(out$authorships$match_method[3], "none")
})

test_that("sm_affiliation_match supports a named-list dictionary", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$authorships$raw_affiliation[1] <- "Institute of Foo Studies"
  patterns <- list("Foo Institute" = c("institute of foo", "foo studies"))
  out <- sm_affiliation_match(corpus, patterns = patterns)
  expect_identical(out$authorships$institution_match[1], "Foo Institute")
})

test_that("sm_affiliation_match uses email-domain fallback", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$authorships$raw_affiliation[1] <- NA_character_
  corpus$authorships$email <- NA_character_
  corpus$authorships$email[1] <- "jane.doe@bundeswehr.org"

  out <- sm_affiliation_match(corpus, email_domain_fallback = TRUE)
  expect_identical(out$authorships$institution_match[1], "Bundeswehr Hospital")
  expect_identical(out$authorships$match_method[1], "email_domain")
})

test_that("sm_affiliation_match handles multiple affiliations per author", {
  # two authorship rows for the same author with different institutions
  corpus <- sm_example_corpus(n_works = 4, n_authors = 4)
  corpus$authorships$raw_affiliation[1] <- "Walter Reed Army Institute"
  corpus$authorships$raw_affiliation[2] <- "Robert Koch Institut, Berlin"
  out <- sm_affiliation_match(corpus)
  expect_identical(out$authorships$institution_match[1], "Walter Reed")
  expect_identical(out$authorships$institution_match[2], "Robert Koch Institute")
})

test_that("sm_affiliation_match is type-stable with no authorships", {
  corpus <- sm_corpus(works = tibble::tibble(
    work_id = "W1", title = "x", year = 2020L
  ))
  out <- sm_affiliation_match(corpus)
  expect_true(is_sm_corpus(out))
  expect_equal(nrow(out$authorships), 0L)
  expect_true(all(c("institution_match", "match_method") %in%
                    names(out$authorships)))
})

# ---- B2: sm_attribute_institution -------------------------------------------

ror_tbl <- function() {
  utils::read.csv(
    system.file("extdata", "example_ror.csv", package = "scimapR"),
    stringsAsFactors = FALSE
  )
}

test_that("sm_attribute_institution maps matches to ROR ids", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
  corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
  corpus <- sm_affiliation_match(corpus)
  out <- sm_attribute_institution(corpus, vocabulary = "ror",
                                  ror_table = ror_tbl())
  expect_true(all(c("institution_id", "institution_name") %in%
                    names(out$authorships)))
  expect_identical(out$authorships$institution_id[1],
                   "https://ror.org/00897frq8")
  expect_identical(out$authorships$institution_name[1], "Bundeswehr Hospital")
})

test_that("sm_attribute_institution matches ROR aliases from raw text", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$authorships$raw_affiliation[1] <- "Harvard Med School"
  # no affiliation match, so attribution must use raw_affiliation against aliases
  corpus <- sm_affiliation_match(corpus)
  out <- sm_attribute_institution(corpus, vocabulary = "ror",
                                  ror_table = ror_tbl())
  expect_identical(out$authorships$institution_name[1], "Harvard University")
})

test_that("sm_attribute_institution custom vocabulary derives ids", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$authorships$raw_affiliation[1] <- "Charite Berlin"
  corpus <- sm_affiliation_match(corpus)
  out <- sm_attribute_institution(corpus, vocabulary = "custom")
  expect_identical(out$authorships$institution_name[1], "Charite Berlin")
  expect_identical(out$authorships$institution_id[1], "CUST:charite-berlin")
})

test_that("sm_attribute_institution leaves unmatched rows NA and runs match first", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
  corpus$authorships$raw_affiliation <- "Nowhere University"
  out <- sm_attribute_institution(corpus, vocabulary = "ror",
                                  ror_table = ror_tbl())
  expect_true(all(is.na(out$authorships$institution_id)))
  expect_true(all(is.na(out$authorships$institution_name)))
})

test_that("sm_attribute_institution errors without ror_table", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2)
  expect_snapshot(
    sm_attribute_institution(corpus, vocabulary = "ror"),
    error = TRUE
  )
})

# Tests for R/utils-language.R (.normalize_language).

test_that(".normalize_language reads names, ISO 639-1 and ISO 639-2 codes", {
  # Web of Science and Scopus names, OpenAlex and Crossref ISO 639-1
  # codes, PubMed ISO 639-2 codes (bibliographic and terminology forms)
  expect_identical(
    .normalize_language(c("English", "German", "en", "de", "eng", "ger",
                          "deu", "French", "fre", "fra")),
    c("en", "de", "en", "de", "en", "de", "de", "fr", "fr", "fr")
  )
  # case, white space, language tags and regions do not matter
  expect_identical(
    .normalize_language(c("ENGLISH", " German ", "en-US", "de_DE",
                          "Portuguese (Brazil)", "Norwegian Bokmal")),
    c("en", "de", "en", "de", "pt", "no")
  )
  expect_identical(.normalize_language("Fran\u00e7ais"), "fr")
  expect_identical(.normalize_language(factor(c("German", "English"))),
                   c("de", "en"))
})

test_that(".normalize_language keeps the first of several languages", {
  expect_identical(.normalize_language(c("English; German", "ger, eng")),
                   c("en", "de"))
})

test_that("missing and undetermined languages are NA, others are kept", {
  expect_identical(
    .normalize_language(c(NA, "", "  ", "und", "Unknown", "zxx")),
    rep(NA_character_, 6)
  )
  # a value it does not know still counts as a known language
  expect_identical(.normalize_language(c("Klingon", "Elvish ")),
                   c("klingon", "elvish"))
  expect_identical(.normalize_language(NULL), character())
  expect_identical(.normalize_language(character()), character())
})

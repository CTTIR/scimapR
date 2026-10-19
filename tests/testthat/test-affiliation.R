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
  expect_identical(as.character(out$authorships$match_method[1]), "pattern")
  expect_identical(out$authorships$institution_match[3], NA_character_)
  expect_identical(as.character(out$authorships$match_method[3]), "none")
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
  expect_identical(as.character(out$authorships$match_method[1]), "email_domain")
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

# ---- Unicode-aware dictionary patterns ---------------------------------------

# One work and one authorship per affiliation string.
aff_corpus <- function(raw) {
  ids <- sprintf("W%02d", seq_along(raw))
  sm_corpus(
    works = tibble::tibble(work_id = ids, title = "x", year = 2020L),
    authorships = tibble::tibble(
      work_id = ids, author_id = sprintf("A%02d", seq_along(raw)),
      position = 1L, is_corresponding = TRUE,
      institution_id = NA_character_, raw_affiliation = raw,
      country_code = NA_character_
    )
  )
}

match_aff <- function(raw, patterns, ...) {
  out <- suppressMessages(sm_affiliation_match(aff_corpus(raw), patterns, ...))
  out$authorships
}

test_that("sm_affiliation_match lets \\w consume umlauts and sharp s", {
  raw <- c(
    "Zentrales Institut des Sanit\u00e4tswesens Nordstadt",
    "Klinik f\u00fcr H\u00f6henmedizin, Southcity",
    "Institut f\u00fcr Mikrobiologie, Northtown",
    "Gro\u00dfklinikum Nordstadt"
  )
  dict <- data.frame(
    institution = c("Institute A", "Clinic B", "Institute C", "Hospital D"),
    pattern = c("sanit\\w+wesens", "h\\w+henmedizin",
                "institut f\\w+r mikrobiologie", "gro\\w+klinikum"),
    stringsAsFactors = FALSE
  )
  a <- match_aff(raw, dict)
  expect_identical(a$institution_match, dict$institution)
  expect_identical(as.character(a$match_signal), rep("name_token", 4L))
  expect_identical(a$match_evidence[c(1L, 4L)],
                   c("Sanit\u00e4tswesens", "Gro\u00dfklinikum"))
})

test_that("sm_affiliation_match finds \\b next to non-ASCII letters", {
  raw <- c(
    "Abt. \u00dcbung und Ausbildung, Nordstadt",
    "Sektion Fu\u00df- und Sprunggelenkchirurgie, Northtown",
    "Abt. Vor\u00fcbung, Nordstadt"
  )
  dict <- data.frame(
    institution = c("Training", "Foot surgery"),
    pattern = c("\\b\u00fcbung\\b", "\\bfu\u00df\\b"),
    stringsAsFactors = FALSE
  )
  a <- match_aff(raw, dict)
  # "Vor<u-umlaut>bung" has no word edge before the umlaut, so no match
  expect_identical(a$institution_match, c("Training", "Foot surgery", NA))
  expect_identical(a$match_evidence[1:2], c("\u00dcbung", "Fu\u00df"))
})

test_that(".ucp_regex() asks for Unicode mode once", {
  expect_identical(.ucp_regex("sanit\\w+"), "(*UCP)sanit\\w+")
  expect_identical(.ucp_regex("(*UCP)x"), "(*UCP)x")
  expect_identical(.ucp_regex("(*UTF)(*UCP)x"), "(*UTF)(*UCP)x")
  expect_identical(.ucp_regex("(*UTF)x"), "(*UCP)(*UTF)x")
  expect_identical(.ucp_regex(c("a", NA, "")), c("(*UCP)a", NA, ""))
  expect_identical(.ucp_regex("x", unicode = FALSE), "x")
  # dictionary rows that start with their own leading items still match
  a <- match_aff(rep("Sanit\u00e4tswesens", 2L),
                 list(ZIS = "(*UTF)sanit\\w+wesens"))
  expect_identical(a$institution_match, c("ZIS", "ZIS"))
})

test_that("sm_affiliation_match never turns NA or empty patterns into hits", {
  dict <- data.frame(
    institution = c("Missing", "Empty", "Microbiology"),
    pattern = c(NA, "", "mikrobiologie"),
    stringsAsFactors = FALSE
  )
  a <- match_aff(c("Institut f\u00fcr Mikrobiologie", "Nordstadt Clinic"),
                 dict)
  expect_identical(a$institution_match, c("Microbiology", NA))
})

test_that("sm_affiliation_match(unicode = FALSE) keeps ASCII-only classes", {
  raw <- c("Zentrales Institut des Sanit\u00e4tswesens",
           "Abt. Vor\u00fcbung, Nordstadt",
           "M\u00fchlstadt Clinic")
  dict <- data.frame(
    institution = c("ZIS", "Training", "Clinic"),
    pattern = c("sanit\\w+wesens", "\\b\u00fcbung\\b", "m\\Whlstadt"),
    stringsAsFactors = FALSE
  )
  # \W stood for the umlaut in ASCII mode; in Unicode mode it is a letter
  old <- match_aff(raw, dict, unicode = FALSE)
  expect_identical(old$institution_match, c(NA, "Training", "Clinic"))
  new <- match_aff(raw, dict)
  expect_identical(new$institution_match, c("ZIS", NA, NA))
  expect_error(sm_affiliation_match(aff_corpus("x"), unicode = NA),
               "unicode")
})

test_that("the postcode signal matches in Unicode mode", {
  dict <- data.frame(
    institution = "Nordstadt Clinic", pattern = NA_character_,
    email_domain = NA_character_, postcode = "12 345",
    stringsAsFactors = FALSE
  )
  raw <- c("Klinikweg 1, 12\u00a0345 Nordstadt", "12345 Nordstadt",
           "Postfach 412 345")
  a <- match_aff(raw, dict, postcode_signal = TRUE)
  # \s matches the no-break space only in Unicode mode
  expect_identical(a$institution_match,
                   c("Nordstadt Clinic", "Nordstadt Clinic", NA))
  expect_identical(a$match_evidence[1], "12\u00a0345")
  old <- match_aff(raw, dict, postcode_signal = TRUE, unicode = FALSE)
  expect_identical(old$institution_match, c(NA, "Nordstadt Clinic", NA))
})

test_that("sm_affiliation_dict matches the probe strings alike in both modes", {
  # The affiliation strings of the OpenAlex example (its institutions)
  oa <- jsonlite::read_json(
    system.file("extdata", "example_openalex.json", package = "scimapR")
  )
  oa_aff <- unlist(lapply(oa, function(w) {
    vapply(w$authorships, function(x) x$institutions[[1]]$display_name,
           character(1))
  }))
  probe <- c(
    "Charite - Universitatsmedizin Berlin",
    "Charit\u00e9 \u2013 Universit\u00e4tsmedizin Berlin",
    "Universit\u00e4tsmedizin Berlin, Klinik f\u00fcr Neurologie",
    "Robert Koch Institut, Berlin",
    "Robert-Koch-Institut, Abteilung f\u00fcr Infektionsepidemiologie",
    "Institut f\u00fcr NATO-Studien, Universit\u00e4t Southcity",
    "Senatorial Office, Nordstadt",
    "Instituto Natoli, Southcity",
    "Some Unrelated University",
    "Universit\u00e4t Nordstadt, Klinik f\u00fcr Dermatologie",
    oa_aff
  )
  expected <- c(
    rep("Charite Berlin", 3L), rep("Robert Koch Institute", 2L), "NATO",
    rep(NA_character_, 4L),
    "Charite Berlin", rep(NA_character_, 8L)
  )
  expect_length(oa_aff, 9L)
  new <- match_aff(probe, sm_affiliation_dict)
  expect_identical(new$institution_match, expected)
  old <- match_aff(probe, sm_affiliation_dict, unicode = FALSE)
  expect_identical(old$institution_match, new$institution_match)
  expect_identical(old$match_evidence, new$match_evidence)
})

test_that("sm_affiliation_dict finds no NATO edge before an umlaut", {
  # In ASCII mode the umlaut is a non-word character, so \bnato\b finds a
  # word edge inside the compound; in Unicode mode only before the hyphen
  raw <- c("Comit\u00e9 NATO\u00e4rzte", "NATO\u00dcbungszentrum Nordstadt",
           "NATO-\u00dcbungszentrum Nordstadt")
  old <- match_aff(raw, sm_affiliation_dict, unicode = FALSE)
  expect_identical(old$institution_match, rep("NATO", 3L))
  new <- match_aff(raw, sm_affiliation_dict)
  expect_identical(new$institution_match, c(NA, NA, "NATO"))
})

test_that("sm_affiliation_dict leaves other military hospitals unmatched", {
  # Before, its rows credited any "military hospital", "army hospital" or
  # "armed forces hospital" to the Bundeswehr hospital; the English names it
  # keeps need "Bundeswehr" or "German" in front
  raw <- c("Military Hospital of Southcity, Southland",
           "Army Hospital Research and Referral, Northtown",
           "Armed Forces Hospital Northtown",
           "US Army Hospital, Southcity",
           "Bundeswehr Hospital Nordstadt",
           "German Army Field Hospital, Nordstadt",
           "Bundeswehrkrankenhaus Nordstadt")
  expected <- c(NA, NA, NA, "US Army", rep("Bundeswehr Hospital", 3L))
  expect_identical(match_aff(raw, sm_affiliation_dict)$institution_match,
                   expected)
  old <- match_aff(raw, sm_affiliation_dict, unicode = FALSE)
  expect_identical(old$institution_match, expected)

  # sm_attribute_institution() matches with this dictionary itself when the
  # corpus has not been matched
  out <- suppressMessages(sm_attribute_institution(aff_corpus(raw), "custom"))
  expect_identical(out$authorships$institution_name, expected)
  expect_identical(out$authorships$institution_id,
                   c(NA, NA, NA, "CUST:us-army",
                     rep("CUST:bundeswehr-hospital", 3L)))
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

test_that("sm_attribute_institution keeps an ASCII-mode match", {
  # It matches in Unicode mode only when institution_match is missing, so a
  # corpus matched with unicode = FALSE keeps its earlier institutions
  corpus <- aff_corpus(c("Comit\u00e9 NATO\u00e4rzte", "Charite Berlin"))
  uni <- suppressMessages(sm_attribute_institution(corpus, "custom"))
  expect_identical(uni$authorships$institution_name, c(NA, "Charite Berlin"))
  ascii <- suppressMessages(sm_affiliation_match(corpus, unicode = FALSE))
  out <- sm_attribute_institution(ascii, "custom")
  expect_identical(out$authorships$institution_name,
                   c("NATO", "Charite Berlin"))
  # a match without any hit is kept as well
  none <- suppressMessages(sm_affiliation_match(corpus, list(X = "zzz")))
  out <- sm_attribute_institution(none, "custom")
  expect_identical(out$authorships$institution_name, c(NA_character_, NA))
})

test_that("sm_attribute_institution finds ROR names in other scripts", {
  # names are compared after a normalisation that keeps the letters of
  # every script; before, a Cyrillic name normalised to nothing
  name <- paste("\u0421\u0435\u0432\u0435\u0440\u043d\u044b\u0439",
                "\u0438\u043d\u0441\u0442\u0438\u0442\u0443\u0442")
  ror <- data.frame(ror_id = "https://ror.org/09999zz01", name = name,
                    aliases = NA_character_, stringsAsFactors = FALSE)
  corpus <- aff_corpus(c(paste0(name, ","), "Nowhere University"))
  out <- suppressMessages(
    sm_attribute_institution(corpus, vocabulary = "ror", ror_table = ror)
  )
  expect_identical(out$authorships$institution_id,
                   c("https://ror.org/09999zz01", NA))
  expect_identical(out$authorships$institution_name, c(name, NA))
})

test_that("sm_attribute_institution errors without ror_table", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2)
  expect_snapshot(
    sm_attribute_institution(corpus, vocabulary = "ror"),
    error = TRUE
  )
})

# ---- sm_affiliation_unmatched ------------------------------------------------

test_that("sm_affiliation_unmatched counts the unmatched strings", {
  matched <- suppressMessages(
    sm_affiliation_match(realuse_corpus(), realuse_dict())
  )
  res <- sm_affiliation_unmatched(matched, n = Inf)
  expect_s3_class(res, "tbl_df")
  expect_named(res, c("raw_affiliation", "n_authorships", "n_works"))
  expect_type(res$n_authorships, "integer")
  expect_type(res$n_works, "integer")

  a <- matched$authorships
  un <- a[is.na(a$institution_match), ]
  expect_setequal(res$raw_affiliation, unique(un$raw_affiliation))
  n_authorships <- vapply(res$raw_affiliation, function(s) {
    sum(un$raw_affiliation == s)
  }, integer(1), USE.NAMES = FALSE)
  n_works <- vapply(res$raw_affiliation, function(s) {
    length(unique(un$work_id[un$raw_affiliation == s]))
  }, integer(1), USE.NAMES = FALSE)
  expect_identical(res$n_authorships, n_authorships)
  expect_identical(res$n_works, n_works)
  # most frequent first, ties in code-point order of the string
  ord <- order(-res$n_authorships, res$raw_affiliation, method = "radix")
  expect_identical(ord, seq_len(nrow(res)))

  expect_identical(sm_affiliation_unmatched(matched, n = 3L), res[1:3, ])
  expect_identical(sm_affiliation_unmatched(matched),
                   res[seq_len(min(25L, nrow(res))), ])
})

test_that("sm_affiliation_unmatched leaves out rows matched by any signal", {
  corpus <- aff_corpus(c("Nordstadt Clinic", "Southcity Lab",
                         "Southcity Lab", "Northtown Unit", NA, "  "))
  corpus$authorships$email <- c(NA, NA, "x@lab.example", NA, NA, NA)
  dict <- data.frame(
    institution = c("Clinic", "Lab"), pattern = c("clinic", NA),
    email_domain = c(NA, "lab.example"), stringsAsFactors = FALSE
  )
  matched <- suppressMessages(sm_affiliation_match(corpus, dict))
  res <- sm_affiliation_unmatched(matched)
  # missing and blank strings are not listed
  expect_identical(res$raw_affiliation, c("Northtown Unit", "Southcity Lab"))
  expect_identical(res$n_authorships, c(1L, 1L))
  expect_identical(res$n_works, c(1L, 1L))
})

test_that("sm_affiliation_unmatched is type-stable", {
  empty <- tibble::tibble(raw_affiliation = character(),
                          n_authorships = integer(), n_works = integer())
  corpus <- aff_corpus(c("Nordstadt Clinic", NA))
  matched <- suppressMessages(
    sm_affiliation_match(corpus, list(Clinic = "clinic"))
  )
  expect_identical(sm_affiliation_unmatched(matched), empty)
  expect_warning(res <- sm_affiliation_unmatched(corpus),
                 "sm_affiliation_match")
  expect_identical(res, empty)
  none <- sm_corpus(works = tibble::tibble(work_id = "W1", title = "x"))
  none <- sm_affiliation_match(none)
  expect_identical(sm_affiliation_unmatched(none), empty)
  expect_error(sm_affiliation_unmatched(matched, n = 0), "n")
  expect_error(sm_affiliation_unmatched(matched, n = 2.5), "n")
  expect_error(sm_affiliation_unmatched(matched, n = NA), "n")
  expect_error(sm_affiliation_unmatched(list()), "sm_corpus")
})

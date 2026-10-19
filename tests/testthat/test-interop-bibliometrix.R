test_that("sm_to_bibliometrix produces a data.frame with bibliometrixDB class", {
  skip_if_not_installed("bibliometrix")


  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  M <- sm_to_bibliometrix(corpus)

  expect_s3_class(M, "data.frame")
  expect_true("bibliometrixDB" %in% class(M))
  expect_equal(nrow(M), 10L)
})

test_that("sm_to_bibliometrix includes required bibliometrix columns", {
  skip_if_not_installed("bibliometrix")

  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  M <- sm_to_bibliometrix(corpus)

  expected_cols <- c("DI", "TI", "AB", "PY", "DT", "TC", "AU", "DB", "SR")
  for (col in expected_cols) {
    expect_true(col %in% names(M),
                info = paste("Missing column:", col))
  }
})

test_that("sm_to_bibliometrix and back round-trips", {
  skip_if_not_installed("bibliometrix")

  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  M <- sm_to_bibliometrix(corpus)
  roundtrip <- as_sm_corpus(M)

  expect_s3_class(roundtrip, "sm_corpus")
  expect_equal(nrow(roundtrip$works), 10L)
  # DOIs should be preserved (lowercased)
  original_dois <- sort(tolower(corpus$works$doi[!is.na(corpus$works$doi)]))
  rt_dois <- sort(roundtrip$works$doi[!is.na(roundtrip$works$doi)])
  expect_equal(original_dois, rt_dois)
})

test_that("sm_to_bibliometrix errors on non-corpus input", {
  skip_if_not_installed("bibliometrix")

  expect_error(sm_to_bibliometrix("not_a_corpus"), "sm_corpus")
})

# ---- DE: author keywords -------------------------------------------------
# sm_to_bibliometrix() itself does not need bibliometrix, so these tests run
# without it. DE is compared by term and ignoring case.

de_terms <- function(m) {
  lapply(strsplit(toupper(m$DE), ";", fixed = TRUE), trimws)
}

de_corpus <- function() {
  works <- tibble::tibble(work_id = paste0("W", 1:4),
                          title = paste("Work", 1:4), year = 2020L)
  concepts <- tibble::tibble(
    work_id = c("W1", "W1", "W1", "W2", "W2", "W3", "W3", "W4", "W4"),
    concept_id = NA_character_,
    concept_name = c("Alpha", "beta", "PLUS TERM", "Oncology", "gamma",
                     "Biology", "wos cat", "physics.gen-ph", "Mesh Term"),
    level = NA_integer_,
    score = NA_real_,
    vocabulary = c("author-keywords", "author-keywords", "keywords-plus",
                   "openalex", "manual-tags", "openalex", "wos-category",
                   "arxiv", "mesh")
  )
  sm_corpus(works, concepts = concepts)
}

test_that("DE holds the author keywords of each work", {
  m <- sm_to_bibliometrix(de_corpus())
  de <- de_terms(m)
  expect_identical(m$work_id, paste0("W", 1:4))
  expect_identical(de[[1]], c("ALPHA", "BETA"))
  # Zotero manual tags are author keywords too, and they win over OpenAlex
  # concepts of the same work.
  expect_identical(de[[2]], "GAMMA")
})

test_that("DE falls back to OpenAlex concepts only", {
  m <- sm_to_bibliometrix(de_corpus())
  de <- de_terms(m)
  expect_identical(de[[3]], "BIOLOGY")
  # arXiv categories, MeSH, Keywords Plus and categories never enter DE.
  expect_identical(de[[4]], NA_character_)
})

test_that("DE is filled for a corpus read from a Web of Science file", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "PT J",
    "AU Smith, J",
    "TI A Keyworded Work",
    "SO SOME JOURNAL",
    "DE heat illness; recruits",
    "ID HYPERTHERMIA",
    "WC Physiology",
    "SC Physiology",
    "PY 2021",
    "UT WOS:000000000000009",
    "ER",
    "",
    "EF"
  ), path)
  corpus <- sm_read_wos(path, verbose = FALSE)
  m <- sm_to_bibliometrix(corpus)
  expect_identical(de_terms(m)[[1]], c("HEAT ILLNESS", "RECRUITS"))
})

test_that("DE finds author keywords stored under a legacy name", {
  corpus <- de_corpus()
  # Direct assignment bypasses sm_corpus(), so the name stays as written.
  corpus$concepts$vocabulary[1:2] <- "keywords-author"
  m <- sm_to_bibliometrix(corpus)
  expect_identical(de_terms(m)[[1]], c("ALPHA", "BETA"))
})

test_that("DE keeps the OpenAlex concepts of the example corpus", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  m <- sm_to_bibliometrix(corpus)
  oa <- corpus$concepts[corpus$concepts$vocabulary == "openalex", ]
  expected <- lapply(m$work_id, function(w) {
    terms <- toupper(oa$concept_name[oa$work_id == w])
    if (length(terms) == 0L) NA_character_ else terms
  })
  expect_identical(de_terms(m), expected)
})

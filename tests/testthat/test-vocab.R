# Tests for the concept vocabularies in R/vocab.R: sm_concept_vocabularies()
# and the internal helpers that every consumer of corpus$concepts uses.

concepts_of <- function(vocabulary) {
  tibble::tibble(
    work_id = paste0("W", seq_along(vocabulary)),
    concept_id = NA_character_,
    concept_name = paste("term", seq_along(vocabulary)),
    level = NA_integer_,
    score = NA_real_,
    vocabulary = vocabulary
  )
}

test_that("sm_concept_vocabularies() lists the canonical vocabularies", {
  lv <- sm_concept_vocabularies()
  expect_type(lv, "character")
  expect_false(anyDuplicated(lv) > 0L)
  expect_true(all(c("author-keywords", "keywords-plus", "index-keywords",
                    "wos-category", "wos-subject-category", "mesh",
                    "openalex", "custom") %in% lv))
  # Legacy spellings are aliases, never canonical names.
  expect_false(any(c("keywords-author", "keyword", "medline") %in% lv))
})

test_that("sm_concept_vocabularies(describe = TRUE) gives level and family", {
  d <- sm_concept_vocabularies(describe = TRUE)
  expect_s3_class(d, "tbl_df")
  expect_named(d, c("level", "family", "description"))
  expect_true(is.factor(d$level))
  expect_identical(levels(d$level), sm_concept_vocabularies())
  expect_identical(as.character(d$level), sm_concept_vocabularies())
  expect_true(is.factor(d$family))
  expect_identical(levels(d$family), c("author_keyword", "indexer_keyword",
                                       "category", "concept", "custom"))
  expect_type(d$description, "character")
  expect_false(any(is.na(d$description) | !nzchar(d$description)))

  family_of <- function(f) as.character(d$level[d$family == f])
  expect_setequal(family_of("author_keyword"),
                  c("author-keywords", "manual-tags"))
  expect_setequal(family_of("indexer_keyword"),
                  c("keywords-plus", "index-keywords", "automatic-tags",
                    "mesh"))
  expect_setequal(family_of("category"),
                  c("wos-category", "wos-subject-category"))
  expect_setequal(family_of("concept"),
                  c("openalex", "arxiv", "biorxiv", "medrxiv"))
  expect_identical(family_of("custom"), "custom")
})

test_that("legacy and common spellings normalise to the canonical names", {
  expect_identical(
    .normalize_concept_vocab(c("keywords-author", "keyword", "keywords",
                               "author_keywords", "medline")),
    c("author-keywords", "author-keywords", "author-keywords",
      "author-keywords", "mesh")
  )
  # Case, white space and the separators - _ . / do not matter.
  expect_identical(
    .normalize_concept_vocab(c("Author Keywords", " MeSH ", "KEYWORDS_PLUS",
                               "WoS Category", "Index.Keywords",
                               "wos subject category", "OpenAlex")),
    c("author-keywords", "mesh", "keywords-plus", "wos-category",
      "index-keywords", "wos-subject-category", "openalex")
  )
  # Web of Science field tags and export column names name their
  # vocabularies.
  expect_identical(.normalize_concept_vocab(c("DE", "ID", "WC", "SC")),
                   c("author-keywords", "keywords-plus", "wos-category",
                     "wos-subject-category"))
  expect_identical(
    .normalize_concept_vocab(c("KeyWords Plus", "MeSH Terms",
                               "Medical Subject Headings",
                               "Web of Science Categories", "Research Areas",
                               "OpenAlex concepts")),
    c("keywords-plus", "mesh", "mesh", "wos-category",
      "wos-subject-category", "openalex")
  )
  expect_identical(.normalize_concept_vocab(sm_concept_vocabularies()),
                   sm_concept_vocabularies())
})

test_that("normalisation keeps unknown values, NA and handles factors", {
  expect_identical(
    .normalize_concept_vocab(c("my tags", NA, "Keywords-Author")),
    c("my tags", NA, "author-keywords")
  )
  expect_identical(
    .normalize_concept_vocab(factor(c("medline", "openalex", NA))),
    c("mesh", "openalex", NA)
  )
  expect_identical(.normalize_concept_vocab(character()), character())
  expect_identical(.normalize_concept_vocab(NA), NA_character_)
})

test_that("vocabulary names that are not valid UTF-8 are kept as written", {
  # "Schl" + latin1 u-umlaut + "ssel": latin1 text read as UTF-8
  bad <- rawToChar(as.raw(c(0x53, 0x63, 0x68, 0x6c, 0xfc, 0x73, 0x73, 0x65,
                            0x6c)))
  expect_identical(.normalize_concept_vocab(c(bad, "Keywords-Author", NA)),
                   c(bad, "author-keywords", NA))
  expect_identical(.concept_vocab_family(bad), NA_character_)
  concepts <- concepts_of(c(bad, "author-keywords"))
  expect_identical(.concepts_in_family(concepts, "author_keyword")$work_id,
                   "W2")
  expect_error(.resolve_concept_vocab(bad), "sm_concept_vocabularies")

  # Building a corpus keeps the value and names it in the message, without
  # errors or warnings.
  works <- tibble::tibble(work_id = c("W1", "W2"), title = c("a", "b"),
                          year = 2020L)
  expect_no_warning(expect_message(
    corpus <- sm_corpus(works, concepts = concepts),
    class = "scimapR_concept_vocab_unknown"
  ))
  expect_identical(corpus$concepts$vocabulary, c(bad, "author-keywords"))

  # Consumers that select concepts by vocabulary still run.
  ex <- sm_example_corpus(n_works = 5, with_embeddings = FALSE)
  ex$concepts$vocabulary[1] <- bad
  expect_equal(nrow(sm_to_bibliometrix(ex)), 5L)
  g <- sm_network_coword(corpus, field = "keywords", min_freq = 1L)
  expect_identical(tibble::as_tibble(tidygraph::activate(g, "nodes"))$name,
                   "term 2")
})

test_that(".concept_vocab_family() returns the family of each value", {
  expect_identical(
    .concept_vocab_family(c("author-keywords", "Manual Tags", "MEDLINE",
                            "wos-category", "biorxiv", "custom",
                            "my tags", NA)),
    c("author_keyword", "author_keyword", "indexer_keyword", "category",
      "concept", "custom", NA, NA)
  )
  expect_identical(.concept_vocab_family(factor("keywords-plus")),
                   "indexer_keyword")
  expect_identical(.concept_vocab_family(character()), character())
})

test_that(".concepts_in_family() selects by family or vocabulary", {
  concepts <- concepts_of(c("Keywords-Author", "manual-tags", "keywords-plus",
                            "MeSH", "openalex", "my tags", NA))
  kw <- .concepts_in_family(concepts, "author_keyword")
  expect_identical(kw$work_id, c("W1", "W2"))
  # The vocabulary of the selected rows is normalised.
  expect_identical(kw$vocabulary, c("author-keywords", "manual-tags"))
  expect_named(kw, names(concepts))

  idx <- .concepts_in_family(concepts, "indexer_keyword")
  expect_identical(idx$vocabulary, c("keywords-plus", "mesh"))

  # Vocabulary names (and their spellings) select single vocabularies, and
  # families and vocabularies can be mixed.
  expect_identical(.concepts_in_family(concepts, "medline")$work_id, "W4")
  expect_identical(
    .concepts_in_family(concepts, c("openalex", "author_keyword"))$work_id,
    c("W1", "W2", "W5")
  )
})

test_that(".concepts_in_family() is type-stable when nothing matches", {
  concepts <- concepts_of(c("openalex", "openalex"))
  out <- .concepts_in_family(concepts, "category")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_named(out, names(concepts))
  expect_type(out$vocabulary, "character")

  empty <- .concepts_in_family(.empty_concepts(), "author_keyword")
  expect_identical(empty, .empty_concepts())

  no_vocab <- .concepts_in_family(concepts[, 1:3], "author_keyword")
  expect_equal(nrow(no_vocab), 0L)
})

test_that(".concepts_in_family() rejects names that are no vocabulary", {
  concepts <- concepts_of("openalex")
  expect_error(.concepts_in_family(concepts, "indexer_keywords"),
               "indexer_keywords")
})

test_that(".resolve_concept_vocab() expands families in canonical order", {
  expect_identical(.resolve_concept_vocab("category"),
                   c("wos-category", "wos-subject-category"))
  expect_identical(.resolve_concept_vocab(c("mesh", "author_keyword")),
                   c("author-keywords", "manual-tags", "mesh"))
  expect_identical(.resolve_concept_vocab(c("Keywords Plus", "keywords-plus")),
                   "keywords-plus")
  expect_error(.resolve_concept_vocab(c("mesh", "nope", "nada")),
               class = "rlang_error")
  expect_error(.resolve_concept_vocab("nope"), "sm_concept_vocabularies")
  expect_error(.resolve_concept_vocab(NA_character_), class = "rlang_error")
  expect_error(.resolve_concept_vocab(character()), class = "rlang_error")
  expect_error(.resolve_concept_vocab(1), class = "rlang_error")
})

test_that("open-access vocabulary is shared and normalises export spellings", {
  levels <- c("diamond", "gold", "hybrid", "bronze", "green", "open", "closed")
  expect_identical(sm_oa_statuses(), levels)
  desc <- sm_oa_statuses(describe = TRUE)
  expect_identical(levels(desc$level), levels)
  expect_identical(desc$is_open, c(rep(TRUE, 6), FALSE))
  input <- c(
    "Gold", "All OA; Gold", "Green Published, Bronze", "gold, Green Published",
    "TRUE", "Closed", "", NA, "embargoed", " platinum ",
    "Hybrid OA", "green accepted",
    "Free to read", "yes", "1", "closed access",
    "FALSE", "no", "none", "0", "oa"
  )
  expected <- c(
    "gold", "gold", "bronze", "gold", "open", "closed", NA, NA, "embargoed",
    "diamond", "hybrid", "green", "bronze", "open", "open", "closed", "closed",
    "closed", "closed", "closed", "open"
  )
  expect_identical(.normalize_oa_status(input), expected)
  expect_identical(.oa_is_open(c("embargoed", NA, "Closed", "diamond")),
                   c(NA, NA, FALSE, TRUE))
  bad <- rawToChar(as.raw(c(0xff, 0x78)))
  expect_identical(.normalize_oa_status(bad), bad)
})

test_that("access normalisation reports blank and invalid text safely", {
  bad <- rawToChar(as.raw(c(0xff, 0x78)))
  works <- tibble::tibble(
    work_id = paste0("W", 1:4), oa_status = c(" ", bad, "{system('bad')}", NA)
  )
  expect_message(corpus <- sm_corpus(works = works),
                 class = "scimapR_oa_status_renamed")
  expect_identical(corpus$works$oa_status, c(NA, bad, "{system('bad')}", NA))
  expect_equal(sm_audit_oa(corpus)$coverage, 0)
})

test_that("sm_example_corpus returns a valid corpus with defaults", {
  corpus <- sm_example_corpus()

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 200L)
  expect_equal(nrow(corpus$authors), 80L)
  expect_true(!is.null(corpus$embeddings))
  expect_equal(ncol(corpus$embeddings), 64L)
})

test_that("sm_example_corpus respects custom arguments", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              year_range = c(2020L, 2023L),
                              n_clusters = 3L,
                              with_embeddings = FALSE,
                              seed = 99)

  expect_equal(nrow(corpus$works), 30L)
  expect_equal(nrow(corpus$authors), 10L)
  expect_null(corpus$embeddings)
  expect_true(all(corpus$works$year >= 2020L & corpus$works$year <= 2023L))
})

test_that("sm_example_corpus is reproducible with same seed", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 123)
  c2 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 123)

  expect_identical(c1$works$doi, c2$works$doi)
  expect_identical(c1$works$title, c2$works$title)
})

test_that("sm_example_corpus includes screening when requested", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_screening = TRUE,
                              with_embeddings = FALSE, seed = 1)

  expect_gt(nrow(corpus$screening), 0L)
  expect_true(all(c("work_id", "stage", "decision") %in%
                    names(corpus$screening)))
})

test_that("sm_example_corpus validates successfully", {
  corpus <- sm_example_corpus(n_works = 50, seed = 7)
  expect_no_error(validate_sm_corpus(corpus))
})

test_that("sm_example_files lists available files", {
  # This will only work when the package is installed or extdata is present
  skip_if_not(
    nzchar(system.file("extdata", package = "scimapR")),
    message = "Package not installed; extdata not accessible"
  )

  files <- sm_example_files()
  expect_type(files, "character")
  expect_gt(length(files), 0L)
})

test_that("sm_example_files returns a path for a known file", {
  skip_if_not(
    nzchar(system.file("extdata", package = "scimapR")),
    message = "Package not installed; extdata not accessible"
  )

  path <- sm_example_files("example.bib")
  expect_true(file.exists(path))
})

test_that("sm_example_files errors for unknown file", {
  skip_if_not(
    nzchar(system.file("extdata", package = "scimapR")),
    message = "Package not installed; extdata not accessible"
  )

  expect_error(sm_example_files("nonexistent_file.xyz"), "not found")
})

test_that("sm_example_files lists the real-use fixture files", {
  files <- sm_example_files()
  expect_true(all(c("example_realuse_corpus.rds",
                    "example_realuse_reference.csv",
                    "example_realuse_affiliation_dict.csv") %in% files))
})

test_that("the real-use fixture has the documented shape", {
  fix <- realuse_corpus()
  expect_s3_class(fix, "sm_corpus")
  works <- fix$works
  expect_equal(nrow(works), 150L)
  counts <- table(works$year)
  expect_equal(as.vector(counts[c("2016", "2017", "2026")]), c(1L, 2L, 10L))
  expect_true(all(startsWith(works$work_id, "WOS:")))
  expect_true(all(c("quartile", "fwci", "field") %in% names(works)))
  expect_true(all(is.na(works$quartile[works$year == 2026L])))
  known <- tapply(!is.na(works$quartile), works$year, any)
  expect_true(all(known[as.character(2016:2025)]))
  expect_identical(fix$metadata$last_refresh, 1792195200)
  expect_identical(works$doi, tolower(works$doi))

  a <- fix$authorships
  corresponding <- unique(a[a$is_corresponding, c("work_id", "author_id")])
  expect_setequal(corresponding$work_id, works$work_id)
  expect_equal(anyDuplicated(corresponding$work_id), 0L)
  expect_equal(sum(grepl("[^ -~]", a$raw_affiliation)), 10L)
  expect_true(all(is.na(fix$references$cited_work_id)))

  ref <- realuse_reference()
  dict <- realuse_dict()
  expect_equal(nrow(ref), 160L)
  expect_equal(sum(ref$title %in% works$title), 120L)
  expect_setequal(unique(ref$institution), unique(dict$institution))
})

test_that("the real-use fixture marks every non-ASCII string as UTF-8", {
  # Unmarked strings are read in the native encoding, so a German title
  # without a mark would read differently outside a UTF-8 locale.
  char_values <- function(x) {
    if (is.character(x)) return(x)
    if (is.list(x)) return(unlist(lapply(x, char_values), use.names = FALSE))
    character()
  }
  values <- char_values(unclass(realuse_corpus()))
  non_ascii <- values[grepl("[^ -~]", values, useBytes = TRUE)]
  expect_gt(length(non_ascii), 0L)
  expect_identical(unique(Encoding(non_ascii)), "UTF-8")
})

test_that("the real-use plaintext twin matches the fixture works", {
  fix <- realuse_corpus()
  twin <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)
  expect_equal(nrow(twin$works), 10L)
  expect_true(all(twin$works$doi %in% fix$works$doi))
  expect_true(all(twin$provenance$source_id_external %in% fix$works$work_id))
  ids <- fix$works$work_id[match(twin$works$doi, fix$works$doi)]
  for (i in seq_along(ids)) {
    expect_identical(
      twin$references$cited_raw[twin$references$work_id ==
                                  twin$works$work_id[i]],
      fix$references$cited_raw[fix$references$work_id == ids[i]]
    )
  }
})

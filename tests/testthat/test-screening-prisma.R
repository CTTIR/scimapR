# Tests for R/screening-prisma.R (sm_screen_prisma and screening exports).

test_that("sm_screen_prisma rejects a non-corpus input", {
  expect_error(sm_screen_prisma(list()), class = "rlang_error")
})

test_that("sm_screen_prisma returns counts and a ggplot", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE,
                              with_screening = TRUE, seed = 1)
  out <- sm_screen_prisma(corpus)
  expect_type(out, "list")
  expect_named(out, c("counts", "plot"))
  expect_s3_class(out$plot, "ggplot")
  expect_s3_class(out$counts, "tbl_df")
  expect_equal(nrow(out$counts), 4L)
  # First stage entry count equals total works.
  expect_equal(out$counts$n_entering[1], 20L)
})

test_that("default stages do not match the 'title-abstract' stage, so nothing is excluded", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 6,
                              with_embeddings = FALSE,
                              with_screening = TRUE, seed = 2)
  out <- sm_screen_prisma(corpus)
  # Synthetic screening uses stage "title-abstract"; default PRISMA stages are
  # identification/screening/eligibility/inclusion -> zero matched exclusions.
  expect_true(all(out$counts$n_excluded == 0L))
  expect_true(all(out$counts$n_remaining == 15L))
})

test_that("exclusions reduce the remaining counts across stages", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE,
                              with_screening = TRUE, seed = 3)
  decisions <- tibble::tibble(
    work_id = paste0("X", 1:5),
    stage = c("screening", "screening", "eligibility",
              "eligibility", "eligibility"),
    decision = c("exclude", "exclude", "exclude", "exclude", "include"),
    reason = "test",
    confidence = 0.9,
    source = "manual",
    decided_at = Sys.time()
  )
  out <- sm_screen_prisma(corpus, decisions = decisions)

  scr_row <- out$counts[out$counts$stage == "screening", ]
  elig_row <- out$counts[out$counts$stage == "eligibility", ]
  expect_equal(scr_row$n_excluded, 2L)
  expect_equal(elig_row$n_excluded, 2L)
  # 10 -> after screening 8 -> after eligibility 6.
  expect_equal(scr_row$n_remaining, 8L)
  expect_equal(elig_row$n_remaining, 6L)
})

test_that("custom stage names are honoured", {
  corpus <- sm_example_corpus(n_works = 8, n_authors = 4,
                              with_embeddings = FALSE,
                              with_screening = TRUE, seed = 4)
  out <- sm_screen_prisma(corpus, stages = c("a", "b"))
  expect_equal(out$counts$stage, c("a", "b"))
  expect_equal(nrow(out$counts), 2L)
})

test_that("works with empty screening yields no exclusions", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 4,
                              with_embeddings = FALSE,
                              with_screening = FALSE, seed = 5)
  out <- sm_screen_prisma(corpus)
  expect_true(all(out$counts$n_excluded == 0L))
  expect_equal(out$counts$n_entering[1], 6L)
})

test_that("sm_export_rayyan writes RIS records for each work", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 3,
                              with_embeddings = FALSE, seed = 6)
  path <- withr::local_tempfile(fileext = ".ris")
  ret <- suppressMessages(sm_export_rayyan(corpus, path))
  expect_equal(ret, path)
  expect_true(file.exists(path))

  lines <- readLines(path)
  expect_equal(sum(lines == "TY  - JOUR"), 3L)
  expect_equal(sum(lines == "ER  - "), 3L)
  expect_true(any(grepl("^TI  - ", lines)))
})

test_that("sm_export_covidence delegates to the RIS exporter", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2,
                              with_embeddings = FALSE, seed = 7)
  path <- withr::local_tempfile(fileext = ".ris")
  suppressMessages(sm_export_covidence(corpus, path))
  lines <- readLines(path)
  expect_equal(sum(lines == "TY  - JOUR"), 2L)
})

test_that("sm_import_rayyan parses a decision CSV", {
  path <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(decision = c("include", "exclude"),
                   reason = c("relevant", "off-topic")),
    path
  )
  out <- sm_import_rayyan(path)
  expect_s3_class(out, "tbl_df")
  expect_equal(out$decision, c("include", "exclude"))
  expect_equal(out$reason, c("relevant", "off-topic"))
  expect_true(all(out$source == "rayyan"))
})

test_that("sm_merge_screening_decisions appends to the screening table", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 3,
                              with_embeddings = FALSE,
                              with_screening = TRUE, seed = 8)
  before <- nrow(corpus$screening)
  decisions <- tibble::tibble(
    work_id = "W000000001",
    stage = "screening",
    decision = "include",
    reason = "x",
    confidence = 1,
    source = "manual",
    decided_at = Sys.time()
  )
  out <- sm_merge_screening_decisions(corpus, decisions)
  expect_equal(nrow(out$screening), before + 1L)
})

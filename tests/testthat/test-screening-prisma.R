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

test_that("default stages count title-abstract exclusions once per work", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 6,
                              with_screening = TRUE, seed = 2)
  expect_no_warning(out <- sm_screen_prisma(corpus))
  excluded <- sum(corpus$screening$decision == "exclude")
  expect_identical(out$counts$n_excluded[2], as.integer(excluded))
  twice <- sm_screen_prisma(corpus, decisions = corpus$screening)
  expect_identical(twice$counts, out$counts)
  expect_true(all(twice$counts$n_remaining >= 0L))
})

test_that("exclusions reduce the remaining counts across stages", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE,
                              with_screening = FALSE, seed = 3)
  decisions <- tibble::tibble(
    work_id = corpus$works$work_id[1:5],
    stage = c("screening", "screening", "eligibility",
              "eligibility", "eligibility"),
    decision = c("exclude", "exclude", "exclude", "exclude", "include"),
    reason = "test",
    confidence = 0.9,
    source = "manual",
    decided_at = Sys.time()
  )
  out <- sm_screen_prisma(
    corpus, decisions = decisions,
    stages = c("identification", "screening", "eligibility", "inclusion")
  )

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
  expect_warning(out <- sm_screen_prisma(corpus, stages = c("a", "b")),
                 class = "scimapR_prisma_unmatched_stages")
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
  expect_warning(out <- sm_import_rayyan(path),
                 class = "scimapR_rayyan_unmatched")
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

test_that("PRISMA counts only current flow works and reports ignored rows", {
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2)
  ids <- corpus$works$work_id
  scr <- tibble::tibble(
    work_id = c(ids[1], ids[1], ids[2], "outside"),
    stage = c("title-abstract", "full-text", "full-text", "title-abstract"),
    decision = "exclude", source = c("manual", "manual", "llm_error", "manual")
  )
  expect_warning(out <- sm_screen_prisma(corpus, scr),
                 class = "scimapR_prisma_unknown_works")
  expect_identical(out$counts$n_excluded, c(0L, 1L, 0L, 0L))
  corpus <- suppressMessages(sm_screen_regex(corpus, "zzzz"))
  expect_warning(sm_screen_prisma(corpus),
                 class = "scimapR_prisma_unmatched_stages")
  expect_no_warning(
    out <- sm_screen_prisma(
      corpus, stages = c("identification", "regex", "inclusion")
    )
  )
  expect_identical(out$counts$n_remaining, c(3L, 0L, 0L))
})

test_that("PRISMA identification records losses before screening", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 3)
  out <- sm_screen_prisma(corpus, n_identified = 25)
  expect_identical(out$counts$n_entering[1], 25L)
  expect_identical(out$counts$n_excluded[1], 10L)
  for (bad in list(10, 25.5, NA, Inf, c(25, 26), "25", TRUE)) {
    expect_error(sm_screen_prisma(corpus, n_identified = bad),
                 class = "scimapR_invalid_n_identified")
  }
  corpus$metadata$n_identified <- 30L
  expect_identical(sm_screen_prisma(corpus)$counts$n_entering[1], 30L)
  expect_identical(
    sm_screen_prisma(corpus, stages = "inclusion",
                     n_identified = "unused")$counts$n_entering,
    15L
  )
})

test_that("screening export preserves ids and omits missing fields", {
  corpus <- sm_example_corpus(n_works = 1, n_authors = 1)
  corpus$works$doi <- NA_character_
  corpus$works$abstract <- NA_character_
  path <- withr::local_tempfile(fileext = ".ris")
  suppressMessages(sm_export_rayyan(corpus, path))
  lines <- readLines(path)
  expect_true(paste0("ID  - ", corpus$works$work_id) %in% lines)
  expect_true(
    paste0("N1  - scimapR work_id: ", corpus$works$work_id) %in% lines
  )
  expect_false(any(grepl("^(DO|AB)  - ", lines)))
})

test_that("Rayyan note decisions and identifiers survive a round trip", {
  # Invented notes follow the documented format; no real export was available.
  path <- test_path("fixtures", "rayyan-decisions.csv")
  out <- sm_import_rayyan(path)
  expect_identical(out$work_id, c("paper-a", "paper-b", "paper-c"))
  expect_identical(out$decision, c("include", "exclude", "uncertain"))
  expect_identical(out$reason[2], "Wrong design")
  expect_equal(nrow(out), 3L)
})

test_that("Rayyan matches explicit IDs or DOIs and keeps every input row", {
  corpus <- sm_example_corpus(n_works = 2, n_authors = 2)
  corpus$works$doi <- c("10.9999/a", "10.9999/b")
  path <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(DOI = c("https://doi.org/10.9999/A",
                           "10.9999/b", "10.9999/missing")),
    path
  )
  expect_warning(out <- sm_import_rayyan(path, corpus),
                 class = "scimapR_rayyan_unmatched")
  expect_equal(nrow(out), 3L)
  expect_identical(out$work_id, c(corpus$works$work_id, NA_character_))
  expect_true(all(is.na(out$decision)))
  readr::write_csv(tibble::tibble(key = corpus$works$work_id,
                                  Decision = c("Included", "Maybe")), path)
  expect_no_warning(out <- sm_import_rayyan(path, corpus, id_col = "key"))
  expect_identical(out$work_id, corpus$works$work_id)
  expect_identical(out$decision, c("include", "uncertain"))
  readr::write_csv(
    tibble::tibble(key = c("outside", corpus$works$work_id[1])), path
  )
  expect_warning(out <- sm_import_rayyan(path, corpus, id_col = "key"),
                 class = "scimapR_rayyan_unmatched")
  expect_true(is.na(out$work_id[1]))
})

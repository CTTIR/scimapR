# Tests for Part F: figure manifest and tabular constructor.

# ---- F1: sm_figure_manifest -------------------------------------------------

test_that("sm_figure_manifest scans a directory and reads sidecar captions", {
  d <- withr::local_tempdir()
  # write two dummy figure files (content irrelevant for listing)
  writeLines("", file.path(d, "fig1.svg"))
  writeLines("", file.path(d, "fig2.pdf"))
  utils::write.csv(
    data.frame(file = "fig1.svg", caption = "First figure",
               alt_text = "Alt one", stringsAsFactors = FALSE),
    file.path(d, "captions.csv"), row.names = FALSE
  )

  m <- sm_figure_manifest(d)
  expect_named(m, c("file", "caption", "alt_text", "width", "height", "dpi"))
  expect_setequal(m$file, c("fig1.svg", "fig2.pdf"))
  expect_identical(m$caption[m$file == "fig1.svg"], "First figure")
  expect_identical(m$caption[m$file == "fig2.pdf"], "")  # no sidecar entry
})

test_that("sm_figure_manifest never errors on missing or empty directory", {
  expect_warning(
    m1 <- sm_figure_manifest(file.path(tempdir(), "definitely-not-here-xyz"))
  )
  expect_equal(nrow(m1), 0L)
  expect_named(m1, c("file", "caption", "alt_text", "width", "height", "dpi"))

  d <- withr::local_tempdir()
  expect_warning(m2 <- sm_figure_manifest(d))
  expect_equal(nrow(m2), 0L)
})

test_that("sm_figure_manifest reads PNG dimensions and writes output", {
  skip_if_not_installed("png")
  d <- withr::local_tempdir()
  png_path <- file.path(d, "plot.png")
  grDevices::png(png_path, width = 320, height = 240)
  graphics::plot(1:10)
  grDevices::dev.off()

  m <- sm_figure_manifest(d)
  expect_equal(m$width, 320L)
  expect_equal(m$height, 240L)

  out_csv <- file.path(d, "manifest.csv")
  m2 <- sm_figure_manifest(d, output = out_csv)
  expect_true(file.exists(out_csv))
  expect_equal(nrow(utils::read.csv(out_csv)), nrow(m2))
})

# ---- F2: sm_corpus_from_tables ----------------------------------------------

test_that("sm_corpus_from_tables builds and coerces types", {
  works <- data.frame(
    work_id = c("W1", "W2"),
    title = c("First", "Second"),
    year = c("2020", "2021"),
    doi = c("10.1/a", "10.1/b"),
    stringsAsFactors = FALSE
  )
  aus <- data.frame(
    work_id = c("W1", "W1", "W2"),
    author_id = c("A1", "A2", "A1"),
    position = c(1, 2, 1)
  )
  corpus <- suppressMessages(
    sm_corpus_from_tables(list(works = works, authorships = aus))
  )
  expect_true(is_sm_corpus(corpus))
  expect_type(corpus$works$year, "integer")
  expect_type(corpus$authorships$position, "integer")
  expect_equal(nrow(corpus$works), 2L)
  # absent tables become typed 0-row tibbles
  expect_equal(nrow(corpus$sources), 0L)
  expect_identical(names(corpus$sources), names(.empty_sources()))
})

test_that("sm_corpus_from_tables fills missing columns with typed NA", {
  works <- data.frame(work_id = "W1", title = "Only title",
                      stringsAsFactors = FALSE)
  corpus <- suppressMessages(sm_corpus_from_tables(list(works = works)))
  expect_true(all(names(.empty_works()) %in% names(corpus$works)))
  expect_true(is.integer(corpus$works$year))
  expect_true(is.na(corpus$works$year))
})

test_that("sm_corpus_from_tables generates work_id when absent", {
  works <- data.frame(title = c("a", "b"), year = c(2020L, 2021L))
  corpus <- suppressMessages(sm_corpus_from_tables(list(works = works)))
  expect_equal(nrow(corpus$works), 2L)
  expect_false(any(is.na(corpus$works$work_id)))
})

test_that("sm_corpus_from_tables errors without a works table", {
  expect_snapshot(
    sm_corpus_from_tables(list(authorships = data.frame(work_id = "W1"))),
    error = TRUE
  )
})

test_that("sm_corpus_from_tables warns on unrecognised tables", {
  works <- data.frame(work_id = "W1", title = "x", year = 2020L)
  expect_warning(
    suppressMessages(
      sm_corpus_from_tables(list(works = works, nonsense = data.frame(a = 1)))
    ),
    "unrecognised"
  )
})

test_that("sm_corpus_from_tables preserves extra user columns", {
  works <- data.frame(work_id = "W1", title = "x", year = 2020L,
                      my_custom = "keep me", stringsAsFactors = FALSE)
  corpus <- suppressMessages(sm_corpus_from_tables(list(works = works)))
  expect_true("my_custom" %in% names(corpus$works))
  expect_identical(corpus$works$my_custom, "keep me")
})

test_that("sm_corpus_from_tables normalises concept vocabularies", {
  works <- data.frame(work_id = c("W1", "W2"), title = c("x", "y"))
  concepts <- data.frame(
    work_id = c("W1", "W1", "W2"),
    concept_name = c("alpha", "BETA", "gamma"),
    vocabulary = c("Author Keywords", "ID", "author-keywords")
  )
  suppressMessages(expect_message(
    corpus <- sm_corpus_from_tables(list(works = works, concepts = concepts)),
    class = "scimapR_concept_vocab_renamed"
  ))
  expect_identical(corpus$concepts$vocabulary,
                   c("author-keywords", "keywords-plus", "author-keywords"))

  # A factor column is coerced and normalised too, also with .coerce = FALSE.
  concepts$vocabulary <- factor(concepts$vocabulary)
  for (coerce in c(TRUE, FALSE)) {
    corpus <- suppressMessages(sm_corpus_from_tables(
      list(works = works, concepts = concepts), .coerce = coerce
    ))
    expect_identical(corpus$concepts$vocabulary,
                     c("author-keywords", "keywords-plus", "author-keywords"))
  }
})

test_that("sm_corpus_from_tables does not inform for canonical vocabularies", {
  works <- data.frame(work_id = "W1", title = "x")
  concepts <- data.frame(work_id = "W1", concept_name = "alpha",
                         vocabulary = "wos-category")
  msgs <- character()
  corpus <- withCallingHandlers(
    sm_corpus_from_tables(list(works = works, concepts = concepts)),
    message = function(m) {
      vocab_classes <- c("scimapR_concept_vocab_renamed",
                         "scimapR_concept_vocab_unknown")
      if (inherits(m, vocab_classes)) {
        msgs <<- c(msgs, conditionMessage(m))
      }
      invokeRestart("muffleMessage")
    }
  )
  expect_length(msgs, 0L)
  expect_identical(corpus$concepts$vocabulary, "wos-category")
})

test_that("sm_corpus_from_tables recognises citations_by_year", {
  works <- data.frame(work_id = c("W1", "W2"), title = c("a", "b"),
                      year = c(2020L, 2021L))
  yearly <- data.frame(work_id = c("W1", "W1", "W2"),
                       year = c("2021", "2022", "2022"),
                       cited_by_count = c(1, 4, 2))
  corpus <- suppressMessages(
    sm_corpus_from_tables(list(works = works, citations_by_year = yearly))
  )
  expect_identical(corpus$citations_by_year$year, c(2021L, 2022L, 2022L))
  expect_identical(corpus$citations_by_year$cited_by_count, c(1L, 4L, 2L))
  expect_no_warning(suppressMessages(
    sm_corpus_from_tables(list(works = works, citations_by_year = yearly))
  ))
  # without the table the corpus has no such element, not a 0-row one
  plain <- suppressMessages(sm_corpus_from_tables(list(works = works)))
  expect_false("citations_by_year" %in% names(plain))
  bad <- yearly
  bad$year[2] <- "2021"
  expect_error(
    suppressMessages(
      sm_corpus_from_tables(list(works = works, citations_by_year = bad))
    ),
    "more than one row"
  )
})

test_that("a legacy metrics table still feeds the impact outcome", {
  # corpus$metrics stays outside the schema: from_tables ignores it with a
  # warning, while the impact resolver keeps reading it (test-v040.R)
  works <- data.frame(work_id = c("W1", "W2"), title = c("a", "b"))
  expect_warning(
    suppressMessages(
      sm_corpus_from_tables(list(works = works,
                                 metrics = data.frame(work_id = "W1")))
    ),
    "metrics"
  )
  corpus <- sm_example_corpus(n_works = 60, seed = 1)
  corpus$works$cited_by_count <- NA_integer_
  corpus$metrics <- tibble::tibble(work_id = corpus$works$work_id,
                                   cnci = seq_len(60) / 30)
  res <- .resolve_impact_values(corpus)
  expect_identical(res$source, "corpus$metrics$cnci")
  expect_false("metrics" %in% names(corpus[1:5]))
})

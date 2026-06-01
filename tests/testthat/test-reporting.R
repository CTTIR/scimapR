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

# Tests for R/plot-collab.R (sm_plot_collab) -- pure ggplot, no network.

test_that("sm_plot_collab rejects a non-corpus input", {
  skip_if_not_installed("ggraph")
  expect_error(sm_plot_collab(list()), class = "rlang_error")
})

test_that("sm_plot_collab validates the level argument", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_plot_collab(corpus, level = "planet"), class = "error")
})

test_that("sm_plot_collab errors cleanly when ggraph is missing", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      stop(structure(
        class = c("rlang_error", "error", "condition"),
        list(message = "ggraph not installed", call = NULL)
      ))
    },
    .package = "rlang"
  )
  expect_error(sm_plot_collab(corpus, level = "country"))
})

test_that("country-level collaboration returns a ggplot with layers", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 60, n_authors = 25,
                              with_embeddings = FALSE, seed = 2)
  p <- sm_plot_collab(corpus, level = "country", top_n = 15)
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
})

test_that("author-level collaboration returns a ggplot", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 60, n_authors = 25,
                              with_embeddings = FALSE, seed = 3)
  p <- sm_plot_collab(corpus, level = "author", top_n = 15)
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
})

test_that("institution-level returns a placeholder ggplot when no data", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 30, n_authors = 12,
                              with_embeddings = FALSE, seed = 4)
  # Example corpus has institution_id = NA throughout -> empty pairs branch.
  p <- sm_plot_collab(corpus, level = "institution")
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$title, "No institutional collaboration data")
})

test_that("country-level with no country data returns a placeholder", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 5)
  corpus$authorships$country_code <- NA_character_
  p <- sm_plot_collab(corpus, level = "country")
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$title, "No collaboration data")
})

test_that("precompute = TRUE yields a plain ggplot", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 60, n_authors = 25,
                              with_embeddings = FALSE, seed = 6)
  p <- sm_plot_collab(corpus, level = "country", precompute = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("dark mode renders without error", {
  skip_if_not_installed("ggraph")
  corpus <- sm_example_corpus(n_works = 40, n_authors = 15,
                              with_embeddings = FALSE, seed = 7)
  p <- sm_plot_collab(corpus, level = "country", dark = TRUE)
  expect_s3_class(p, "ggplot")
})

# Tests for R/plot-equity.R (sm_plot_equity_dashboard) -- pure ggplot.

test_that("sm_plot_equity_dashboard rejects a non-corpus input", {
  skip_if_not_installed("patchwork")
  expect_error(sm_plot_equity_dashboard(list()), class = "rlang_error")
})

test_that("errors cleanly when patchwork is missing", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 1)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      stop(structure(
        class = c("rlang_error", "error", "condition"),
        list(message = "patchwork not installed", call = NULL)
      ))
    },
    .package = "rlang"
  )
  expect_error(sm_plot_equity_dashboard(corpus))
})

test_that("dashboard returns a patchwork/ggplot object", {
  skip_if_not_installed("patchwork")
  corpus <- sm_example_corpus(n_works = 80, n_authors = 25,
                              with_embeddings = FALSE, seed = 2)
  p <- sm_plot_equity_dashboard(corpus)
  expect_true(inherits(p, "patchwork") || inherits(p, "ggplot"))
})

test_that("dark mode renders a dashboard", {
  skip_if_not_installed("patchwork")
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 3)
  p <- sm_plot_equity_dashboard(corpus, dark = TRUE)
  expect_true(inherits(p, "patchwork") || inherits(p, "ggplot"))
})

test_that("geographic panel returns a labelled ggplot", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 4)
  p <- scimapR:::.plot_equity_geographic(corpus)
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
  expect_equal(p$labels$title, "Geographic Distribution")
})

test_that("geographic panel handles absent country data", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 5)
  corpus$authorships$country_code <- NA_character_
  p <- scimapR:::.plot_equity_geographic(corpus)
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$subtitle, "No country data")
})

test_that("oa, type and productivity panels render", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 6)
  p_oa <- scimapR:::.plot_equity_oa(corpus)
  p_type <- scimapR:::.plot_equity_type(corpus)
  p_prod <- scimapR:::.plot_equity_productivity(corpus)
  expect_s3_class(p_oa, "ggplot")
  expect_s3_class(p_type, "ggplot")
  expect_s3_class(p_prod, "ggplot")
  expect_equal(p_oa$labels$title, "Open Access Status")
  expect_equal(p_prod$labels$title, "Annual Production")
})

test_that("oa/type/productivity panels handle empty data", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 7)
  corpus$works$oa_status <- NA_character_
  corpus$works$type <- NA_character_
  corpus$works$year <- NA_integer_
  expect_equal(scimapR:::.plot_equity_oa(corpus)$labels$subtitle, "No data")
  expect_equal(scimapR:::.plot_equity_type(corpus)$labels$subtitle, "No data")
  expect_equal(scimapR:::.plot_equity_productivity(corpus)$labels$subtitle,
               "No data")
})

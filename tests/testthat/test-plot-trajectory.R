# Tests for R/plot-trajectory.R -- pure ggplot, no network.
# sm_plot_trajectory, sm_plot_topic_pivots, sm_plot_collab_turnover.

# A trajectory for the prolific seed author (A000000001) in the example corpus.
build_traj <- function(seed = 1L, n_works = 120L, n_authors = 30L,
                       n_periods = 5L) {
  corpus <- sm_example_corpus(n_works = n_works, n_authors = n_authors,
                              with_embeddings = FALSE, seed = seed)
  suppressMessages(
    sm_author_trajectory(corpus, author_id = corpus$authors$author_id[1],
                         n_periods = n_periods)
  )
}

# ---- sm_plot_trajectory ----------------------------------------------------

test_that("sm_plot_trajectory rejects non-trajectory input", {
  expect_error(sm_plot_trajectory(list()), "sm_trajectory")
})

test_that("sm_plot_trajectory errors cleanly when patchwork is missing", {
  traj <- build_traj()
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      stop(structure(
        class = c("rlang_error", "error", "condition"),
        list(message = "patchwork not installed", call = NULL)
      ))
    },
    .package = "rlang"
  )
  expect_error(sm_plot_trajectory(traj))
})

test_that("sm_plot_trajectory returns a composed patchwork/ggplot", {
  skip_if_not_installed("patchwork")
  traj <- build_traj()
  p <- sm_plot_trajectory(traj)
  expect_s3_class(p, "ggplot")
})

test_that("sm_plot_trajectory works in dark mode", {
  skip_if_not_installed("patchwork")
  traj <- build_traj(seed = 2L)
  p <- sm_plot_trajectory(traj, dark = TRUE)
  expect_s3_class(p, "ggplot")
})

# ---- sm_plot_topic_pivots --------------------------------------------------

test_that("sm_plot_topic_pivots rejects non-trajectory input", {
  expect_error(sm_plot_topic_pivots(list()), "sm_trajectory")
})

test_that("sm_plot_topic_pivots returns a ggplot with layers", {
  traj <- build_traj(seed = 3L)
  p <- sm_plot_topic_pivots(traj)
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
})

test_that("sm_plot_topic_pivots returns a placeholder when no pivots", {
  traj <- build_traj()
  traj$topic_pivots <- traj$topic_pivots[0, ]
  p <- sm_plot_topic_pivots(traj)
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$title, "No topic pivots")
})

# ---- sm_plot_collab_turnover -----------------------------------------------

test_that("sm_plot_collab_turnover rejects non-trajectory input", {
  expect_error(sm_plot_collab_turnover(list()), "sm_trajectory")
})

test_that("sm_plot_collab_turnover returns a stacked-area ggplot", {
  traj <- build_traj(seed = 4L)
  p <- sm_plot_collab_turnover(traj)
  expect_s3_class(p, "ggplot")
  expect_gt(length(p$layers), 0L)
  expect_equal(p$labels$title, "Collaborator Turnover")
})

test_that("sm_plot_collab_turnover returns placeholder when no turnover data", {
  traj <- build_traj()
  traj$collaborator_turnover <- traj$collaborator_turnover[0, ]
  p <- sm_plot_collab_turnover(traj)
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$title, "No collaborator data")
})

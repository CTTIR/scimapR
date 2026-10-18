test_that("run_example_exprs() skips interactive-only example code", {
  # An interactive session, as when devtools::test() runs in a console:
  # without the helper's own interactive(), the block below would run.
  session <- new.env(parent = globalenv())
  session$interactive <- function() TRUE
  exprs <- parse(text = c("ran <- FALSE", "if (interactive()) ran <- TRUE"),
                 keep.source = FALSE)
  env <- run_example_exprs(exprs, parent = session)
  expect_false(env$ran)
})

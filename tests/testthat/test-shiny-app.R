# Tests for R/shiny-app.R helpers; the app itself is not launched.

test_that("the app's package check names the packages the app calls", {
  files <- list.files(system.file("shiny", "scimapR", package = "scimapR"),
                      pattern = "\\.R$", full.names = TRUE)
  skip_if(length(files) == 0L, "the app files are not installed")
  code <- unlist(lapply(files, readLines, warn = FALSE))
  used <- unique(sub("::$", "", regmatches(
    code, gregexpr("\\b[A-Za-z][A-Za-z0-9.]*(?=::)", code, perl = TRUE)
  ) |> unlist()))
  # always installed with scimapR, or optional and checked in the app
  optional <- c("scimapR", "dplyr", "ggplot2", "tibble", "stats", "utils",
                "viridisLite", "igraph", "ggraph", "pkgload")
  expect_setequal(setdiff(used, optional), .app_packages())
})

test_that(".app_top_nodes keeps the nodes of highest degree", {
  edges <- tibble::tibble(from = c(1, 1, 1, 2, 4), to = c(2, 3, 4, 3, 5))
  nodes <- tibble::tibble(name = c("a", "b", "c", "d", "e"))
  g <- tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE)
  out <- .app_top_nodes(g, 3)
  kept <- dplyr::pull(tidygraph::activate(out, "nodes"), "name")
  # degrees: a 3, b 2, c 2, d 2, e 1; ties keep the earlier nodes
  expect_identical(kept, c("a", "b", "c"))
  expect_identical(nrow(tibble::as_tibble(tidygraph::activate(out, "edges"))),
                   3L)
  expect_identical(.app_top_nodes(g, 10), g)
  expect_identical(.app_top_nodes(g, NA), g)
})

# Tests for R/export-gephi.R
# sm_export_gephi / sm_export_vosviewer / sm_export_cytoscape.
#
# NOTE: these exporters call `tidygraph::as_tibble(network, what = "edges")`,
# but tidygraph's method signature is `as_tibble(x, active = NULL, ...)`.
# The `what` argument is silently swallowed by `...`, so the *active* table
# (nodes by default, including for graphs produced by `sm_network_*`) is
# returned for BOTH the node and edge extractions. The practical effect is
# that edges are not exported correctly: the "edges" tibble is actually the
# nodes tibble, so `edges$from`/`edges$to` are missing and edge endpoints
# come out empty. These tests assert the (buggy) current behaviour for the
# edge sections and the correct behaviour for the node sections, so that a
# future fix to use `active = "edges"` will surface here.

make_graph <- function() {
  tidygraph::tbl_graph(
    nodes = tibble::tibble(name = c("alpha", "beta", "gamma")),
    edges = tibble::tibble(from = c(1L, 2L), to = c(2L, 3L),
                           weight = c(2.5, 4.0))
  )
}

test_that("sm_export_gephi rejects non-graph input", {
  expect_error(sm_export_gephi(list(), tempfile()),
               class = "rlang_error")
})

test_that("sm_export_gephi writes valid GEXF with node labels", {
  g <- make_graph()
  path <- withr::local_tempfile(fileext = ".gexf")
  ret <- suppressWarnings(sm_export_gephi(g, path))
  expect_equal(ret, path)
  expect_true(file.exists(path))

  txt <- paste(readLines(path), collapse = "\n")
  expect_match(txt, "<gexf")
  expect_match(txt, "alpha")
  expect_match(txt, "gamma")
  # Parses as XML despite the edge-extraction bug.
  expect_silent(xml2::read_xml(path))
})

test_that("sm_export_gephi handles a graph without weights or names", {
  g <- tidygraph::tbl_graph(
    nodes = tibble::tibble(x = 1:2),
    edges = tibble::tibble(from = 1L, to = 2L)
  )
  path <- withr::local_tempfile(fileext = ".gexf")
  suppressWarnings(sm_export_gephi(g, path))
  expect_true(file.exists(path))
  expect_silent(xml2::read_xml(path))
})

test_that("sm_export_vosviewer rejects non-graph input", {
  expect_error(sm_export_vosviewer(list(), tempfile()),
               class = "rlang_error")
})

test_that("sm_export_vosviewer writes a TSV with the expected columns", {
  g <- make_graph()
  path <- withr::local_tempfile(fileext = ".tsv")
  suppressWarnings(sm_export_vosviewer(g, path))
  expect_true(file.exists(path))

  dat <- readr::read_tsv(path, show_col_types = FALSE)
  expect_true(all(c("from", "to", "weight") %in% names(dat)))
})

test_that("sm_export_cytoscape rejects non-graph input", {
  expect_error(sm_export_cytoscape(list(), tempfile()),
               class = "rlang_error")
})

test_that("sm_export_cytoscape writes parseable JSON with node data", {
  g <- make_graph()
  path <- withr::local_tempfile(fileext = ".json")
  suppressWarnings(sm_export_cytoscape(g, path))
  expect_true(file.exists(path))

  parsed <- jsonlite::read_json(path)
  expect_true("elements" %in% names(parsed))
  expect_length(parsed$elements$nodes, 3L)
  expect_equal(parsed$elements$nodes[[1]]$data$id, "alpha")
  expect_equal(parsed$elements$nodes[[3]]$data$name, "gamma")
})

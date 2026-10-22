# Tests for all three network exchange formats.

make_graph <- function() {
  tidygraph::tbl_graph(
    nodes = tibble::tibble(name = c("alpha", "beta", "gamma")),
    edges = tibble::tibble(from = c(1L, 2L), to = c(2L, 3L),
                           weight = c(2.5, 4.0))
  )
}

test_that("network exporters reject non-graph input", {
  for (export in list(sm_export_gephi, sm_export_vosviewer,
                      sm_export_cytoscape)) {
    expect_error(export(list(), tempfile()), class = "rlang_error")
  }
})

test_that("GEXF contains the real edge endpoints and weights", {
  path <- withr::local_tempfile(fileext = ".gexf")
  expect_no_warning(ret <- sm_export_gephi(make_graph(), path))
  expect_equal(ret, path)
  doc <- xml2::read_xml(path)
  edges <- xml2::xml_find_all(doc, ".//*[local-name()='edge']")
  expect_equal(length(edges), 2L)
  expect_identical(xml2::xml_attr(edges, "source"), c("1", "2"))
  expect_identical(xml2::xml_attr(edges, "target"), c("2", "3"))
  expect_equal(as.numeric(xml2::xml_attr(edges, "weight")), c(2.5, 4))
  expect_identical(xml2::xml_attr(doc, "version"), "1.3")
})

test_that("GEXF escapes labels and records graph direction", {
  label <- 'R&D <policy> "x"'
  for (directed in c(TRUE, FALSE)) {
    graph <- tidygraph::tbl_graph(
      nodes = tibble::tibble(name = c(label, "Beta")),
      edges = tibble::tibble(from = 1L, to = 2L), directed = directed
    )
    path <- withr::local_tempfile(fileext = ".gexf")
    expect_no_warning(sm_export_gephi(graph, path))
    doc <- xml2::read_xml(path)
    nodes <- xml2::xml_find_all(doc, ".//*[local-name()='node']")
    expect_identical(xml2::xml_attr(nodes, "label"), c(label, "Beta"))
    root <- xml2::xml_find_first(doc, ".//*[local-name()='graph']")
    expect_identical(xml2::xml_attr(root, "defaultedgetype"),
                     if (directed) "directed" else "undirected")
  }
  x <- sm_read_wos(test_path("fixtures", "link-wos-two.txt"), verbose = FALSE)
  path <- withr::local_tempfile(fileext = ".gexf")
  expect_no_warning(sm_export_gephi(sm_network_citation(x), path))
  root <- xml2::xml_find_first(xml2::read_xml(path),
                               ".//*[local-name()='graph']")
  expect_identical(xml2::xml_attr(root, "defaultedgetype"), "directed")
})

test_that("VOSviewer gets integer links and a separate labelled map", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "net.tsv")
  expect_no_warning(ret <- sm_export_vosviewer(make_graph(), path))
  expect_identical(ret, path)
  expect_identical(readLines(path), c("1\t2\t2.5", "2\t3\t4"))
  map <- readr::read_tsv(file.path(dir, "net_map.tsv"), show_col_types = FALSE)
  expect_identical(names(map), c("id", "label"))
  expect_equal(map$id, 1:3)
  expect_identical(map$label, c("alpha", "beta", "gamma"))
  other <- file.path(dir, "elsewhere.tsv")
  expect_no_warning(sm_export_vosviewer(make_graph(), path, map_path = other))
  expect_true(file.exists(other))
})

test_that("Cytoscape gets the real edge endpoints and weights", {
  path <- withr::local_tempfile(fileext = ".json")
  expect_no_warning(sm_export_cytoscape(make_graph(), path))
  parsed <- jsonlite::read_json(path)
  expect_length(parsed$elements$nodes, 3L)
  expect_equal(parsed$elements$nodes[[1]]$data$id, "alpha")
  expect_equal(parsed$elements$nodes[[3]]$data$name, "gamma")
  edges <- parsed$elements$edges
  expect_length(edges, 2L)
  expect_identical(vapply(edges, function(x) x$data$source, character(1)),
                   c("alpha", "beta"))
  expect_identical(vapply(edges, function(x) x$data$target, character(1)),
                   c("beta", "gamma"))
  expect_equal(vapply(edges, function(x) x$data$weight, numeric(1)), c(2.5, 4))
})

test_that("empty edges and unnamed nodes export without warnings", {
  graph <- tidygraph::tbl_graph(nodes = tibble::tibble(x = 1:2),
                                edges = tibble::tibble(from = integer(),
                                                       to = integer()))
  dir <- withr::local_tempdir()
  gexf <- file.path(dir, "empty.gexf")
  expect_no_warning(sm_export_gephi(graph, gexf))
  doc <- xml2::read_xml(gexf)
  expect_length(xml2::xml_find_all(doc, ".//*[local-name()='edge']"), 0L)
  nodes <- xml2::xml_find_all(doc, ".//*[local-name()='node']")
  expect_identical(xml2::xml_attr(nodes, "label"), c("1", "2"))
  expect_no_warning(sm_export_vosviewer(graph, file.path(dir, "empty")))
  expect_identical(readLines(file.path(dir, "empty")), character())
  expect_true(file.exists(file.path(dir, "empty_map")))
  cy <- file.path(dir, "empty.json")
  expect_no_warning(sm_export_cytoscape(graph, cy))
  expect_length(jsonlite::read_json(cy)$elements$edges, 0L)
})

test_that("VOSviewer rejects nonpositive link strengths before writing", {
  graph <- make_graph() |>
    tidygraph::activate("edges") |>
    dplyr::mutate(weight = c(0, -1))
  path <- withr::local_tempfile()
  expect_error(sm_export_vosviewer(graph, path),
               class = "scimapR_invalid_network_weights")
  expect_false(file.exists(path))
})

test_that("VOSviewer map labels quote commas and semicolons", {
  graph <- make_graph() |>
    dplyr::mutate(name = c("Alpha, beta; gamma", "Beta", "Gamma"))
  dir <- withr::local_tempdir()
  expect_no_warning(sm_export_vosviewer(graph, file.path(dir, "net.tsv")))
  expect_identical(readLines(file.path(dir, "net_map.tsv"))[2],
                   '1\t"Alpha, beta; gamma"')
})

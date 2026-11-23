test_that("sm_plot_production returns a ggplot", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 10,
                              with_embeddings = FALSE, seed = 1)
  p <- sm_plot_production(corpus)

  expect_s3_class(p, "ggplot")
})

test_that("sm_plot_production handles empty corpus", {
  works <- tibble::tibble(
    work_id = character(), doi = character(), title = character(),
    abstract = character(), year = integer(), type = character(),
    source_id = character(), cited_by_count = integer(),
    oa_status = character(), language = character(),
    pmid = character(), arxiv_id = character(),
    openalex_id = character(), is_retracted = logical(),
    retraction_date = as.Date(character()),
    last_refreshed = as.POSIXct(character())
  )
  corpus <- sm_corpus(works = works)
  p <- sm_plot_production(corpus)

  expect_s3_class(p, "ggplot")
})

test_that("sm_plot_top returns a ggplot for each level", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)

  p_authors <- sm_plot_top(corpus, level = "authors", n = 5)
  expect_s3_class(p_authors, "ggplot")

  p_sources <- sm_plot_top(corpus, level = "sources", n = 5)
  expect_s3_class(p_sources, "ggplot")

  p_countries <- sm_plot_top(corpus, level = "countries", n = 5)
  expect_s3_class(p_countries, "ggplot")
})

test_that("sm_plot_top ranks by summed citations with metric = 'citations'", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)
  p <- sm_plot_top(corpus, level = "sources", n = 3, metric = "citations")
  name <- corpus$sources$display_name[match(corpus$works$source_id,
                                            corpus$sources$source_id)]
  expected <- sort(tapply(as.double(corpus$works$cited_by_count), name, sum,
                          na.rm = TRUE), decreasing = TRUE)[1:3]
  expect_equal(p$data$count, as.vector(expected))
  expect_identical(as.character(p$data$name), names(expected))
  expect_identical(p$labels$x, "Citations")

  counts <- sm_plot_top(corpus, level = "sources", n = 3, metric = "count")
  expect_identical(counts$labels$x, "Count")
  expect_true(all(counts$data$count <= 50))
})

test_that("sm_plot_top leaves out unnamed entities before taking the top n", {
  corpus <- sm_example_corpus(n_works = 30, n_authors = 10,
                              with_embeddings = FALSE, seed = 2)
  top <- sm_plot_top(corpus, level = "authors", n = 4)$data$name
  corpus$authors$display_name[corpus$authors$display_name ==
                                as.character(top[1])] <- NA
  p <- sm_plot_top(corpus, level = "authors", n = 4)
  expect_identical(nrow(p$data), 4L)
  expect_false(anyNA(p$data$name))
})

test_that("sm_plot_lotka returns a ggplot", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)
  p <- sm_plot_lotka(corpus)

  expect_s3_class(p, "ggplot")
})

test_that("sm_plot_bradford returns a ggplot", {
  corpus <- sm_example_corpus(n_works = 50, n_authors = 20,
                              with_embeddings = FALSE, seed = 1)
  p <- sm_plot_bradford(corpus)

  expect_s3_class(p, "ggplot")
})

test_that("plot functions reject non-corpus input", {
  expect_error(sm_plot_production("not_a_corpus"), "sm_corpus")
  expect_error(sm_plot_top("not_a_corpus"), "sm_corpus")
  expect_error(sm_plot_lotka("not_a_corpus"), "sm_corpus")
  expect_error(sm_plot_bradford("not_a_corpus"), "sm_corpus")
})

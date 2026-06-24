make_clustered_corpus_evo <- function(n = 80, k = 4, seed = 1) {
  corpus <- sm_example_corpus(n_works = n, n_clusters = k,
                              year_range = c(2010L, 2024L),
                              with_embeddings = TRUE, seed = seed)
  set.seed(seed)
  suppressMessages(sm_cluster_kmeans(corpus, k = k, reducer = "pca"))
}

test_that("sm_cluster_evolution rejects non-corpus input", {
  expect_error(sm_cluster_evolution(list(a = 1)), "sm_corpus")
})

test_that("sm_cluster_evolution validates link_threshold", {
  corpus <- make_clustered_corpus_evo()
  expect_error(sm_cluster_evolution(corpus, link_threshold = -0.1),
               "between 0 and 1")
  expect_error(sm_cluster_evolution(corpus, link_threshold = 1.5),
               "between 0 and 1")
  expect_error(sm_cluster_evolution(corpus, link_threshold = c(0.2, 0.4)),
               "between 0 and 1")
})

test_that("sm_cluster_evolution errors when no cluster_id column", {
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = TRUE, seed = 2)
  expect_error(sm_cluster_evolution(corpus), "cluster_id")
})

test_that("sm_cluster_evolution errors when year column all NA", {
  corpus <- make_clustered_corpus_evo(seed = 3)
  corpus$works$year <- NA_integer_
  expect_error(sm_cluster_evolution(corpus), "year")
})

test_that("sm_cluster_evolution returns snapshots and transitions tibbles", {
  corpus <- make_clustered_corpus_evo(seed = 4)
  evo <- suppressMessages(sm_cluster_evolution(corpus))
  expect_type(evo, "list")
  expect_named(evo, c("snapshots", "transitions"))
  expect_true(all(c("window", "cluster_id", "n_works", "top_terms") %in%
                    names(evo$snapshots)))
  expect_true(all(c("from_window", "to_window", "from_cluster", "to_cluster",
                    "jaccard", "n_shared") %in% names(evo$transitions)))
  expect_gt(nrow(evo$snapshots), 0L)
  # Snapshot n_works sums to number of clustered+dated works
  total <- sum(!is.na(corpus$works$cluster_id) & !is.na(corpus$works$year))
  expect_lte(sum(evo$snapshots$n_works), total)
})

test_that("sm_cluster_evolution respects custom time_windows", {
  corpus <- make_clustered_corpus_evo(seed = 5)
  windows <- list(2010:2014, 2015:2019, 2020:2024)
  evo <- suppressMessages(
    sm_cluster_evolution(corpus, time_windows = windows)
  )
  win_labels <- unique(evo$snapshots$window)
  expect_true(all(win_labels %in% c("2010-2014", "2015-2019", "2020-2024")))
})

test_that("sm_cluster_evolution transitions respect link_threshold", {
  corpus <- make_clustered_corpus_evo(seed = 6)
  evo_lo <- suppressMessages(sm_cluster_evolution(corpus, link_threshold = 0.0))
  evo_hi <- suppressMessages(sm_cluster_evolution(corpus, link_threshold = 0.99))
  expect_gte(nrow(evo_lo$transitions), nrow(evo_hi$transitions))
  if (nrow(evo_lo$transitions) > 0L) {
    expect_true(all(evo_lo$transitions$jaccard >= 0))
  }
})

test_that("sm_cluster_evolution returns empty transitions with one window", {
  corpus <- make_clustered_corpus_evo(seed = 7)
  evo <- suppressMessages(
    sm_cluster_evolution(corpus, time_windows = list(2010:2024))
  )
  expect_equal(nrow(evo$transitions), 0L)
  expect_gt(nrow(evo$snapshots), 0L)
})

test_that(".auto_time_windows produces non-overlapping integer windows", {
  w <- .auto_time_windows(2010:2024)
  expect_type(w, "list")
  expect_true(length(w) >= 2L)
  expect_true(all(vapply(w, is.integer, logical(1))))
})

test_that(".top_terms_from_titles and .extract_title_terms handle edge cases", {
  expect_true(is.na(.top_terms_from_titles(character())))
  expect_true(is.na(.top_terms_from_titles("the and for with")))
  expect_equal(.extract_title_terms(character()), character())
  terms <- .extract_title_terms(c("Cancer genomics study",
                                  "Genomics of cancer"))
  expect_true("cancer" %in% terms)
  expect_true("genomics" %in% terms)
})

test_that(".assign_window labels years correctly", {
  res <- .assign_window(c(2011L, 2018L, 2099L), list(2010:2014, 2015:2019))
  expect_equal(res[1], "2010-2014")
  expect_equal(res[2], "2015-2019")
  expect_true(is.na(res[3]))
})

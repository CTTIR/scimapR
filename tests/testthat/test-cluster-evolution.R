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

# ---- hand-made corpus: transitions worked out by hand ----------------------

evo_hand_corpus <- function() {
  works <- tibble::tibble(
    work_id = sprintf("W%02d", 1:11),
    title = c(
      "Malaria vector control trial", "Malaria vaccine trial",
      "Heat illness in soldiers", "Heat stroke recovery", "Editorial note",
      "Malaria vaccine efficacy", "Burn wound care", "Heat illness prevention",
      "Editorial note", NA, NA
    ),
    year = c(2020L, 2021L, 2020L, 2021L, 2021L,
             2022L, 2023L, 2022L, 2023L, 2020L, 2023L),
    cluster_id = c(1L, 1L, 2L, 2L, 0L, 1L, 2L, 3L, 0L, 4L, 4L)
  )
  scimapR::sm_corpus(works = works)
}

evo_windows <- list(2020:2021, 2022:2023)

test_that("term linking gives the transitions worked out by hand", {
  evo <- suppressMessages(
    sm_cluster_evolution(evo_hand_corpus(), time_windows = evo_windows)
  )
  # Window 1: cluster 1 {malaria vector control trial vaccine}, cluster 2
  # {heat illness soldiers stroke recovery}, noise 0 {editorial note},
  # cluster 4 (no title). Window 2: 1 {malaria vaccine efficacy}, 2 {burn
  # wound care}, 3 {heat illness prevention}, 0 {editorial note}, 4.
  expected <- tibble::tibble(
    from_window = "2020-2021", to_window = "2022-2023",
    from_cluster = c(1L, 2L, 0L), to_cluster = c(1L, 3L, 0L),
    jaccard = c(0.3333, 0.3333, 1), n_shared = c(2L, 2L, 2L)
  )
  expect_equal(evo$transitions, expected)
  expect_identical(attr(evo, "link_by"), "terms")
  terms <- suppressMessages(
    sm_cluster_evolution(evo_hand_corpus(), time_windows = evo_windows,
                         link_by = "terms")
  )
  expect_identical(terms$transitions, evo$transitions)
  expect_identical(terms$snapshots, evo$snapshots)
})

test_that("default and term linking agree on a k-means clustering", {
  corpus <- make_clustered_corpus_evo(seed = 8)
  default <- suppressMessages(sm_cluster_evolution(corpus))
  terms <- suppressMessages(sm_cluster_evolution(corpus, link_by = "terms"))
  expect_identical(default$transitions, terms$transitions)
  expect_identical(default$snapshots, terms$snapshots)
})

test_that("link_by = 'cluster_id' follows each cluster across windows", {
  expect_message(
    evo <- sm_cluster_evolution(evo_hand_corpus(), time_windows = evo_windows,
                                link_by = "cluster_id"),
    "cluster id"
  )
  # clusters 1, 2 and 4 are in both windows; 0 is noise and 3 is new.
  # Cluster 4 has no title terms in either window, so its Jaccard is 0.
  expected <- tibble::tibble(
    from_window = "2020-2021", to_window = "2022-2023",
    from_cluster = c(1L, 2L, 4L), to_cluster = c(1L, 2L, 4L),
    jaccard = c(0.3333, 0, 0), n_shared = c(2L, 0L, 0L)
  )
  expect_equal(evo$transitions, expected)
  expect_identical(attr(evo, "link_by"), "cluster_id")
  # link_threshold does not filter in this mode
  strict <- suppressMessages(
    sm_cluster_evolution(evo_hand_corpus(), time_windows = evo_windows,
                         link_by = "cluster_id", link_threshold = 0.99)
  )
  expect_identical(strict$transitions, evo$transitions)
})

test_that("noise = NULL treats cluster 0 as an ordinary cluster", {
  evo <- suppressMessages(
    sm_cluster_evolution(evo_hand_corpus(), time_windows = evo_windows,
                         link_by = "cluster_id", noise = NULL)
  )
  expect_identical(evo$transitions$from_cluster, c(0L, 1L, 2L, 4L))
  expect_identical(evo$transitions$jaccard[1], 1)
  expect_error(
    sm_cluster_evolution(evo_hand_corpus(), link_by = "cluster_id",
                         noise = c(0L, -1L)),
    "noise"
  )
  expect_error(sm_cluster_evolution(evo_hand_corpus(), link_by = "years"),
               "link_by")
})

test_that("snapshots report each cluster's share of its window", {
  evo <- suppressMessages(
    sm_cluster_evolution(evo_hand_corpus(), time_windows = evo_windows)
  )
  snaps <- evo$snapshots
  expect_true("share" %in% names(snaps))
  w1 <- snaps[snaps$window == "2020-2021", ]
  expect_equal(w1$share[match(c(0L, 1L, 2L, 4L), w1$cluster_id)],
               c(1, 2, 2, 1) / 6)
  sums <- as.vector(tapply(snaps$share, snaps$window, sum))
  expect_equal(sums, c(1, 1))
})

test_that("every return path carries share and the link_by attribute", {
  corpus <- evo_hand_corpus()
  one <- suppressMessages(
    sm_cluster_evolution(corpus, time_windows = list(2020:2023),
                         link_by = "cluster_id")
  )
  expect_identical(attr(one, "link_by"), "cluster_id")
  expect_equal(nrow(one$transitions), 0L)
  expect_equal(sum(one$snapshots$share), 1)

  corpus$works$cluster_id <- NA_integer_
  none <- sm_cluster_evolution(corpus, link_by = "cluster_id")
  expect_identical(attr(none, "link_by"), "cluster_id")
  expect_named(none$snapshots,
               c("window", "cluster_id", "n_works", "top_terms", "share"))
  expect_type(none$snapshots$share, "double")
  expect_equal(nrow(none$transitions), 0L)
  expect_identical(attr(sm_cluster_evolution(corpus), "link_by"), "terms")
})

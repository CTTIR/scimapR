# Tests for R/trajectory-build.R and the sm_trajectory S3 class

test_that("sm_author_trajectory rejects a non-corpus input", {
  expect_error(
    sm_author_trajectory(list(), author_id = "A000000001"),
    class = "rlang_error"
  )
})

test_that("sm_author_trajectory requires orcid or author_id", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_author_trajectory(corpus),
    "must be provided"
  )
})

test_that("sm_author_trajectory rejects a non-positive n_periods", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_author_trajectory(corpus, author_id = "A000000001", n_periods = 0L),
    "positive integer"
  )
})

test_that("sm_author_trajectory errors on unknown author_id", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_author_trajectory(corpus, author_id = "A999999999"),
    "No author found"
  )
})

test_that("sm_author_trajectory errors on unknown orcid", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_author_trajectory(corpus, orcid = "0000-0000-0000-0000"),
    "No author found with ORCID"
  )
})

test_that("sm_author_trajectory resolves an author by orcid", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 15,
                              with_embeddings = FALSE, seed = 4)
  # Find an author that actually has an ORCID
  with_orcid <- corpus$authors[!is.na(corpus$authors$orcid), ]
  skip_if(nrow(with_orcid) == 0L, "No author with ORCID in this seed")
  the_orcid <- with_orcid$orcid[1]
  traj <- sm_author_trajectory(corpus, orcid = the_orcid, n_periods = 3L)
  expect_s3_class(traj, "sm_trajectory")
  expect_equal(traj$orcid, the_orcid)
})

test_that("sm_author_trajectory builds a full trajectory for the seeded author", {
  corpus <- sm_example_corpus(n_works = 60, n_authors = 20,
                              with_embeddings = FALSE, seed = 7)
  traj <- sm_author_trajectory(corpus, author_id = "A000000001",
                               n_periods = 4L)

  expect_s3_class(traj, "sm_trajectory")
  expect_true(is_sm_trajectory(traj))
  expect_equal(traj$author_id, "A000000001")

  # The seeded author is prolific so spans multiple periods
  expect_equal(traj$n_periods, 4L)
  expect_equal(nrow(traj$career_stages), 4L)
  expect_equal(nrow(traj$h_index_curve), 4L)
  expect_equal(nrow(traj$novelty_curve), 4L)
  expect_equal(nrow(traj$citation_acceleration), 4L)

  # Topic pivots / turnover have n_periods - 1 rows
  expect_equal(nrow(traj$topic_pivots), 3L)
  expect_equal(nrow(traj$collaborator_turnover), 3L)

  # Career stages structure
  expect_named(
    traj$career_stages,
    c("period", "year_range", "n_works", "dominant_topics", "h_index")
  )
  expect_true(all(traj$career_stages$n_works >= 0L))
  expect_true(all(traj$h_index_curve$h_index >= 0L))

  # Pivot scores are valid Jaccard distances in [0, 1]
  expect_true(all(traj$topic_pivots$pivot_score >= 0 &
                    traj$topic_pivots$pivot_score <= 1))

  # Collaborator jaccard in [0, 1]
  expect_true(all(traj$collaborator_turnover$jaccard_to_prev >= 0 &
                    traj$collaborator_turnover$jaccard_to_prev <= 1))
})

test_that("sm_author_trajectory returns empty tibbles for an author with no works", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE,
                              with_trajectory_seed = FALSE, seed = 2)
  # Add an author with no authorships
  corpus$authors <- dplyr::bind_rows(
    corpus$authors,
    tibble::tibble(
      author_id = "A999999999", orcid = NA_character_,
      display_name = "Ghost Author",
      display_name_alternatives = list(character()),
      inferred_gender = NA_character_, gender_confidence = NA_real_,
      gender_method = NA_character_
    )
  )

  expect_message(
    traj <- sm_author_trajectory(corpus, author_id = "A999999999"),
    "no works"
  )
  expect_s3_class(traj, "sm_trajectory")
  expect_equal(nrow(traj$career_stages), 0L)
  expect_equal(nrow(traj$topic_pivots), 0L)
  expect_equal(nrow(traj$emerging_collaborators), 0L)
})

test_that("sm_author_trajectory collapses when all works share a single year", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 12,
                              year_range = c(2020L, 2024L),
                              with_embeddings = FALSE,
                              with_trajectory_seed = FALSE, seed = 11)
  aid <- corpus$authorships$author_id[1]
  aw_ids <- unique(corpus$authorships$work_id[
    corpus$authorships$author_id == aid
  ])
  # Force all of this author's works into one year
  corpus$works$year[corpus$works$work_id %in% aw_ids] <- 2021L

  traj <- sm_author_trajectory(corpus, author_id = aid, n_periods = 5L)
  # A single shared year produces a single (degenerate) break, so
  # length(breaks) - 1 == 0: the trajectory collapses to zero periods.
  expect_s3_class(traj, "sm_trajectory")
  expect_equal(traj$n_periods, 0L)
  expect_equal(nrow(traj$career_stages), 0L)
  # No pivots / turnover possible
  expect_equal(nrow(traj$topic_pivots), 0L)
  expect_equal(nrow(traj$collaborator_turnover), 0L)
})

# --- Internal helpers ---------------------------------------------------

test_that(".compute_h_index implements the h-index correctly", {
  f <- scimapR:::.compute_h_index
  expect_equal(f(integer()), 0L)
  expect_equal(f(c(NA_integer_, NA_integer_)), 0L)
  # 3 papers with >=3 citations -> h = 3
  expect_equal(f(c(10L, 8L, 5L, 4L, 3L)), 4L)
  expect_equal(f(c(1L, 1L, 1L)), 1L)
  expect_equal(f(c(0L, 0L)), 0L)
})

test_that(".make_period_breaks and .assign_periods behave at edges", {
  mk <- scimapR:::.make_period_breaks
  as_p <- scimapR:::.assign_periods

  expect_equal(mk(c(NA, NA), 5L), c(0L, 1L))

  breaks <- mk(c(2010L, 2020L), 5L)
  expect_equal(length(breaks), 6L)
  expect_equal(breaks[1], 2010L)
  expect_equal(breaks[length(breaks)], 2020L)

  # Single-element break => everything period 1
  expect_equal(as_p(c(2015L, 2016L), c(2010L)), c(1L, 1L))

  p <- as_p(c(2010L, 2020L), breaks)
  expect_true(all(p >= 1L & p <= length(breaks) - 1L))
})

# --- S3 print / format / is_ -------------------------------------------

test_that("is_sm_trajectory discriminates correctly", {
  expect_false(is_sm_trajectory(1))
  expect_false(is_sm_trajectory(list()))
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE, seed = 5)
  traj <- sm_author_trajectory(corpus, author_id = "A000000001")
  expect_true(is_sm_trajectory(traj))
})

test_that("format.sm_trajectory returns a single descriptive string", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 12,
                              with_embeddings = FALSE, seed = 7)
  traj <- sm_author_trajectory(corpus, author_id = "A000000001")
  out <- format(traj)
  expect_type(out, "character")
  expect_length(out, 1L)
  expect_match(out, "<sm_trajectory>")
  expect_match(out, "periods")
})

test_that("print.sm_trajectory runs and returns invisibly", {
  corpus <- sm_example_corpus(n_works = 40, n_authors = 12,
                              with_embeddings = FALSE, seed = 7)
  traj <- sm_author_trajectory(corpus, author_id = "A000000001")
  full <- paste(cli::cli_fmt(print(traj)), collapse = "\n")
  expect_match(full, "sm_trajectory")
  expect_invisible(print(traj))
})

test_that("print.sm_trajectory handles an empty trajectory", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8,
                              with_embeddings = FALSE,
                              with_trajectory_seed = FALSE, seed = 2)
  corpus$authors <- dplyr::bind_rows(
    corpus$authors,
    tibble::tibble(
      author_id = "A999999999", orcid = NA_character_,
      display_name = "Ghost", display_name_alternatives = list(character()),
      inferred_gender = NA_character_, gender_confidence = NA_real_,
      gender_method = NA_character_
    )
  )
  suppressMessages(
    traj <- sm_author_trajectory(corpus, author_id = "A999999999")
  )
  full <- paste(cli::cli_fmt(print(traj)), collapse = "\n")
  expect_match(full, "sm_trajectory")
})

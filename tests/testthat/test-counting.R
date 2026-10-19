# Tests for Parts D & E: citation maturity, counting, robust summaries.

# ---- D1: sm_citation_maturity -----------------------------------------------

test_that("sm_citation_maturity flags recent years based on as-of date", {
  corpus <- sm_example_corpus(n_works = 40, year_range = c(2015L, 2024L),
                              seed = 1)
  # force the as-of date to the max publication year
  corpus$metadata$last_refresh <- NA
  corpus <- sm_citation_maturity(corpus, lag = 2)
  expect_true(all(c("citation_mature", "cnci_provisional") %in%
                    names(corpus$works)))
  # max year 2024, lag 2 -> cutoff 2022 -> 2023/2024 provisional
  prov_years <- unique(corpus$works$year[corpus$works$cnci_provisional])
  expect_setequal(prov_years, c(2023L, 2024L))
  expect_identical(corpus$works$cnci_provisional,
                   !corpus$works$citation_mature)
})

test_that("sm_citation_maturity uses metadata last_refresh when present", {
  corpus <- sm_example_corpus(n_works = 20, year_range = c(2015L, 2024L),
                              seed = 1)
  corpus$metadata$last_refresh <- as.Date("2030-01-01")
  corpus <- sm_citation_maturity(corpus, lag = 2)
  # as-of 2030, cutoff 2028 -> every year mature
  expect_true(all(corpus$works$citation_mature))
})

test_that("sm_citation_maturity reads a numeric last_refresh as seconds", {
  corpus <- sm_example_corpus(n_works = 40, year_range = c(2015L, 2026L),
                              seed = 1)
  # 2026-10-17 00:00:00 UTC, as a corpus restored from a table stores it
  corpus$metadata$last_refresh <- 1792195200
  expect_identical(.maturity_cutoff(corpus, lag = 2L), 2024L)
  corpus <- sm_citation_maturity(corpus, lag = 2)
  expect_identical(corpus$works$cnci_provisional,
                   corpus$works$year > 2024L)
})

test_that("sm_citation_maturity ignores an implausible last_refresh", {
  corpus <- sm_example_corpus(n_works = 40, year_range = c(2015L, 2024L),
                              seed = 1)
  # milliseconds instead of seconds: falls back to the maximum year
  corpus$metadata$last_refresh <- 1792195200000
  expect_message(corpus <- sm_citation_maturity(corpus, lag = 2),
                 "last_refresh", class = "scimapR_implausible_time")
  prov_years <- unique(corpus$works$year[corpus$works$cnci_provisional])
  expect_setequal(prov_years, c(2023L, 2024L))
})

test_that("sm_citation_maturity is type-stable on empty corpus", {
  corpus <- sm_corpus(works = .empty_works())
  out <- sm_citation_maturity(corpus)
  expect_true(is_sm_corpus(out))
  expect_equal(nrow(out$works), 0L)
  expect_true(all(c("citation_mature", "cnci_provisional") %in%
                    names(out$works)))
})

# ---- D2: sm_count -----------------------------------------------------------

test_that("sm_count fractional credit sums to the number of works", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  fr <- sm_count(corpus, method = "fractional", level = "author")
  n_works_with_authors <- dplyr::n_distinct(corpus$authorships$work_id)
  expect_equal(round(sum(fr$credit)), n_works_with_authors)
})

test_that("sm_count full credit equals n_works per entity", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  full <- sm_count(corpus, method = "full", level = "author")
  expect_equal(full$credit, as.double(full$n_works))
  expect_named(full, c("entity_id", "entity_name", "n_works", "credit",
                       "weighted_citations"))
})

test_that("sm_count source counting is identical for full and fractional", {
  corpus <- sm_example_corpus(n_works = 30, seed = 1)
  f <- sm_count(corpus, "full", "source")
  fr <- sm_count(corpus, "fractional", "source")
  expect_equal(sort(f$credit), sort(fr$credit))
})

test_that("sm_count(institution) counts matches and raw strings per row", {
  # sm_count() applies no dictionary itself: unmatched rows keep their raw
  # string, and a corpus matched first (in either mode) is counted by
  # institution_match, row by row, with the unmatched rows under their raw
  # string
  raw <- c("Bundeswehrkrankenhaus Berlin", "Nowhere University",
           "Comit\u00e9 NATO\u00e4rzte")
  ids <- sprintf("W%d", seq_along(raw))
  corpus <- sm_corpus(
    works = tibble::tibble(work_id = ids, title = "x", year = 2020L),
    authorships = tibble::tibble(
      work_id = ids, author_id = sprintf("A%d", seq_along(raw)),
      position = 1L, is_corresponding = TRUE,
      institution_id = NA_character_, raw_affiliation = raw,
      country_code = NA_character_
    )
  )
  expect_warning(res <- sm_count(corpus), "raw_affiliation")
  expect_setequal(res$entity_id, raw)

  uni <- suppressMessages(sm_affiliation_match(corpus))
  expect_warning(res <- sm_count(uni), class = "scimapR_count_raw_affiliation")
  expect_setequal(res$entity_id, c("Bundeswehr Hospital", raw[2:3]))

  ascii <- suppressMessages(sm_affiliation_match(corpus, unicode = FALSE))
  expect_warning(res <- sm_count(ascii), "raw_affiliation")
  expect_setequal(res$entity_id, c("Bundeswehr Hospital", "NATO", raw[2]))
})

test_that("sm_count(institution) never applies the shipped dictionary", {
  # the shipped dictionary matches the first string, and before also the
  # generic hospital phrases of the others; sm_count() counts them all under
  # their raw strings
  raw <- c("Bundeswehrkrankenhaus Nordstadt",
           "Military Hospital of Southcity, Southland",
           "Army Hospital Research and Referral, Northtown")
  ids <- sprintf("W%d", seq_along(raw))
  corpus <- sm_corpus(
    works = tibble::tibble(work_id = ids, title = "x", year = 2020L),
    authorships = tibble::tibble(
      work_id = ids, author_id = sprintf("A%d", seq_along(raw)),
      position = 1L, is_corresponding = TRUE,
      institution_id = NA_character_, raw_affiliation = raw,
      country_code = NA_character_
    )
  )
  expect_warning(res <- sm_count(corpus),
                 class = "scimapR_count_raw_affiliation")
  expect_setequal(res$entity_id, raw)
  expect_false("Bundeswehr Hospital" %in% res$entity_name)
})

test_that("sm_count(institution) counts a vocabulary roll-up put first", {
  # sm_attribute_institution() keeps institution_match, which sm_count()
  # labels first, so its roll-up of two dictionary names to one ROR id only
  # counts once the vocabulary names are put first
  corpus <- sm_corpus(
    works = tibble::tibble(work_id = c("W1", "W2"), title = "x",
                           year = 2020L),
    authorships = tibble::tibble(
      work_id = c("W1", "W2"), author_id = c("A1", "A2"), position = 1L,
      is_corresponding = TRUE, institution_id = NA_character_,
      raw_affiliation = c("Coastal Inst North, Northtown",
                          "Coastal Inst South, Southcity"),
      country_code = NA_character_
    )
  )
  dict <- list("Coastal Inst North" = "coastal inst north",
               "Coastal Inst South" = "coastal inst south")
  ror <- data.frame(ror_id = "https://ror.org/09999zz01",
                    name = "Coastal Institute",
                    aliases = "Coastal Inst North;Coastal Inst South",
                    stringsAsFactors = FALSE)
  matched <- suppressMessages(sm_affiliation_match(corpus, dict))
  out <- sm_attribute_institution(matched, "ror", ror_table = ror)
  expect_identical(out$authorships$institution_id,
                   rep("https://ror.org/09999zz01", 2L))

  res <- sm_count(out)
  expect_setequal(res$entity_id, c("Coastal Inst North", "Coastal Inst South"))
  expect_identical(res$n_works, c(1L, 1L))

  a <- out$authorships
  out$authorships$institution_match <- dplyr::coalesce(a$institution_name,
                                                       a$institution_match)
  res <- sm_count(out)
  expect_identical(res$entity_id, "Coastal Institute")
  expect_identical(res$n_works, 2L)
})

test_that("sm_count(institution) resolves each authorship on its own", {
  corpus <- sm_corpus(
    works = tibble::tibble(work_id = sprintf("W%d", 1:4), title = "x",
                           year = 2020L, cited_by_count = 1L),
    authorships = tibble::tibble(
      work_id = c("W1", "W2", "W3", "W4", "W4"),
      author_id = sprintf("A%d", 1:5), position = c(1L, 1L, 1L, 1L, 2L),
      is_corresponding = TRUE,
      institution_id = c("I1", NA, "I7", NA, NA),
      institution_match = c(NA, "Unit North", NA, NA, NA),
      raw_affiliation = c(NA, "Unit North, Northtown", NA, "Somewhere", NA),
      country_code = "DE"
    ),
    institutions = tibble::tibble(institution_id = "I1",
                                  display_name = "Coastal Institute")
  )
  expect_warning(res <- sm_count(corpus),
                 class = "scimapR_count_raw_affiliation")
  res <- res[order(res$entity_id), ]
  # the id rows and the matched row both count; the authorship without any
  # label (A5) is left out
  expect_identical(res$entity_id, c("I1", "I7", "Somewhere", "Unit North"))
  expect_identical(res$entity_name,
                   c("Coastal Institute", "I7", "Somewhere", "Unit North"))
  expect_identical(res$n_works, rep(1L, 4))

  # without raw strings there is nothing to warn about
  corpus$authorships$raw_affiliation[4] <- NA_character_
  expect_no_warning(res <- sm_count(corpus))
  expect_setequal(res$entity_id, c("I1", "I7", "Unit North"))
})

test_that("sm_count is type-stable when level data is absent", {
  corpus <- sm_corpus(works = tibble::tibble(work_id = "W1", title = "x",
                                             year = 2020L))
  out <- sm_count(corpus, level = "author")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("entity_id", "entity_name", "n_works", "credit",
                      "weighted_citations"))
})

# ---- E1: sm_metric_summary --------------------------------------------------

test_that("sm_metric_summary robust reports median CI and pp_top10", {
  corpus <- sm_example_corpus(n_works = 100, seed = 1)
  s <- sm_metric_summary(corpus, metric = "citations", seed = 1, n_boot = 300)
  expect_named(s, c("metric", "n", "mean", "median", "median_ci_low",
                    "median_ci_high", "pp_top10", "n_boot"))
  expect_equal(s$n, 100L)
  expect_true(s$median_ci_low <= s$median)
  expect_true(s$median <= s$median_ci_high)
  expect_true(s$pp_top10 >= 0 && s$pp_top10 <= 1)
})

test_that("sm_metric_summary is reproducible with a seed", {
  corpus <- sm_example_corpus(n_works = 80, seed = 1)
  s1 <- sm_metric_summary(corpus, "citations", seed = 42, n_boot = 300)
  s2 <- sm_metric_summary(corpus, "citations", seed = 42, n_boot = 300)
  expect_equal(s1$median_ci_low, s2$median_ci_low)
  expect_equal(s1$median_ci_high, s2$median_ci_high)
})

test_that("sm_metric_summary seed does not disturb the global RNG", {
  corpus <- sm_example_corpus(n_works = 40, seed = 1)
  set.seed(123)
  before <- .Random.seed
  invisible(sm_metric_summary(corpus, "citations", seed = 7, n_boot = 100))
  expect_identical(.Random.seed, before)
})

test_that("sm_metric_summary non-robust omits CI columns", {
  corpus <- sm_example_corpus(n_works = 40, seed = 1)
  s <- sm_metric_summary(corpus, "citations", robust = FALSE)
  expect_named(s, c("metric", "n", "mean", "median"))
})

test_that("sm_metric_summary is type-stable on empty corpus", {
  corpus <- sm_corpus(works = .empty_works())
  s <- sm_metric_summary(corpus, "citations")
  expect_equal(s$n, 0L)
  expect_true(is.na(s$median))
})

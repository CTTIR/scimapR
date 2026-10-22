cd_corpus <- function(years = c(2000L, 2005L, 2010L, 2010L, 2001L)) {
  sm_corpus(
    tibble::tibble(work_id = paste0("W", 0:4), year = years),
    references = tibble::tibble(work_id = c("W1", "W2", "W3", "W4"),
                                cited_work_id = c("W0", "W1", "W0", "W0"))
  )
}

test_that("a simple citation chain attains a disruption score of one", {
  x <- cd_corpus()[1:3]
  out <- sm_metric_disruption(x)
  expect_equal(out$cd_index[out$work_id == "W1"], 1)
})

test_that("the CD denominator excludes the focal work and earlier works", {
  x <- cd_corpus()
  out <- sm_metric_disruption(x)
  expect_equal(out$cd_index[out$work_id == "W1"], 0.5)
  expect_true(is.na(out$cd_index[out$work_id == "W3"]))
  x$references <- dplyr::bind_rows(x$references, x$references[1, ],
                                   tibble::tibble(work_id = "W1",
                                                  cited_work_id = "W1"))
  expect_identical(sm_metric_disruption(x), out)
})

test_that("the CD year rule keeps same-year and undated reference citers", {
  for (year in c(2005L, NA_integer_)) {
    x <- cd_corpus(c(2000L, 2005L, 2010L, 2010L, year))
    out <- sm_metric_disruption(x)
    expect_equal(out$cd_index[out$work_id == "W1"], 0.333333)
  }
  x <- cd_corpus(c(2000L, NA_integer_, 2010L, 2010L, 2001L))
  out <- sm_metric_disruption(x)
  expect_equal(out$cd_index[out$work_id == "W1"], 0.333333)
})

test_that("reader-built internal citations give usable disruption scores", {
  x <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)
  expect_true(any(!is.na(sm_metric_disruption(x)$cd_index)))
})

test_that("unlinked CD warnings name the explicit linker", {
  x <- cd_corpus()
  x$references$cited_work_id <- NA_character_
  expect_warning(out <- sm_metric_disruption(x),
                 "none are linked.*sm_link_references",
                 class = "scimapR_references_unlinked")
  expect_true(all(is.na(out$cd_index)))
  x$references <- x$references[0, ]
  expect_warning(sm_metric_disruption(x),
                 "No reference network.*sm_link_references",
                 class = "scimapR_references_unlinked")
})

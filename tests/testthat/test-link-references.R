test_that("cited-reference DOI lists retain all normalised identifiers", {
  refs <- c("Roe A, DOI 10.9999/A.",
            "Roe A, DOI [10.9999/A, 10.9999/B].",
            "Roe A, doi [10.9999/A, DOI 10.9999/A., DOI 10.9999/C]",
            "No identifier", NA_character_)
  expected <- list("10.9999/a", c("10.9999/a", "10.9999/b"),
                   c("10.9999/a", "10.9999/c"), character(), character())
  expect_identical(.cr_dois(refs), expected)
  expect_identical(.cr_doi(refs), c(rep("10.9999/a", 3), NA, NA))
  twin <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)$references
  # Saved from the previous reader: plain DOI parsing remains unchanged.
  legacy <- jsonlite::read_json(test_path("fixtures", "realuse-wos-dois.json"),
                                simplifyVector = TRUE)
  expect_identical(.cr_doi(twin$cited_raw), legacy)
})

test_that("reference linking preserves existing links and counts ambiguity", {
  works <- tibble::tibble(
    work_id = c("A", "B", "C", "D"),
    doi = c("https://doi.org/10.9999/A", "10.9999/b", rep("10.9999/dup", 2)),
    openalex_id = c("https://openalex.org/W101", "W102", "W103", "W104")
  )
  refs <- tibble::tibble(
    work_id = rep("B", 9),
    cited_work_id = c(NA, NA, NA, "D", "missing", "external", NA, NA, NA),
    cited_doi = c("DOI: 10.9999/a", "10.9999/dup", "10.9999/b",
                  "10.9999/a", "10.9999/a", NA, NA, NA, NA),
    cited_raw = c(NA, NA, NA, NA, NA, NA, "W101",
                  " https://OPENALEX.org/w101 ",
                  "https://openalex.org/works/W101")
  )
  out <- .link_references(refs, works)
  expect_identical(out$cited_work_id,
                   c("A", NA, NA, "D", "A", "external", "A", "A", "A"))
  expect_identical(out$cited_doi, refs$cited_doi)
  expect_identical(out$cited_raw, refs$cited_raw)
  expect_identical(attr(out, "link_counts"),
                   c(n_references = 9L, n_linked = 6L, n_new = 5L,
                     n_ambiguous = 1L, n_self = 1L))
  blank <- .link_references(refs[0, c("work_id", "cited_doi")], works)
  expect_equal(nrow(blank), 0L)
  expect_identical(blank$cited_work_id, character())
})

test_that("reference linking follows identifier priority and checks all DOIs", {
  works <- tibble::tibble(work_id = c("A", "B", "C"),
                          doi = c("10.9999/a", "10.9999/b", "10.9999/c"),
                          openalex_id = c("W101", "W102", "W103"))
  refs <- tibble::tibble(
    work_id = "C", cited_work_id = NA_character_,
    cited_doi = c("10.9999/a", NA, NA),
    cited_raw = c("W102", "DOI [10.9999/unknown, DOI 10.9999/a]",
                  "DOI [10.9999/a, DOI 10.9999/b]")
  )
  expect_identical(.link_references(refs, works)$cited_work_id,
                   c("A", "A", NA))
  out <- .link_references(refs, works, by = c("openalex_id", "doi"))
  expect_identical(out$cited_work_id, c("B", "A", NA))
  expect_equal(attr(out, "link_counts")[["n_ambiguous"]], 1L)
  refs$cited_raw <- c("W101 extra", "prefix https://openalex.org/W101", "")
  expect_true(all(is.na(.link_references(refs, works,
                                         by = "openalex_id")$cited_work_id)))
})

test_that("explicit linking resolves the reader-shaped fixture by DOI", {
  x <- realuse_corpus()
  refs <- x$references
  doi <- .normalize_doi(refs$cited_doi)
  target <- x$works$work_id[match(doi, .normalize_doi(x$works$doi))]
  expected <- sum(!is.na(doi) & !is.na(target) & target != refs$work_id)
  expect_message(out <- sm_link_references(x),
                 class = "scimapR_references_linked")
  expect_equal(sum(out$references$cited_work_id %in% x$works$work_id), expected)
  expect_identical(out$provenance, x$provenance)
  expect_true(all(is.na(x$references$cited_work_id)))
  oa <- sm_link_references(x, by = "openalex_id", verbose = FALSE)
  expect_true(all(is.na(oa$references$cited_work_id)))
  expect_error(sm_link_references(x, by = "title"), class = "rlang_error")
})

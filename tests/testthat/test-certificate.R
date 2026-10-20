# Tests for R/certificate.R, R/hash.R, R/provenance.R

skip_if_not_installed("yaml")

# --- sm_hash_corpus -----------------------------------------------------

test_that("sm_hash_corpus rejects a non-corpus", {
  expect_error(sm_hash_corpus(list()), class = "rlang_error")
})

test_that("sm_hash_corpus is deterministic and content-addressable", {
  c1 <- sm_example_corpus(n_works = 30, n_authors = 10, seed = 1)
  c2 <- sm_example_corpus(n_works = 30, n_authors = 10, seed = 1)
  h1 <- sm_hash_corpus(c1)
  h2 <- sm_hash_corpus(c2)
  expect_type(h1, "character")
  expect_length(h1, 1L)
  expect_identical(h1, h2)
})

test_that("sm_hash_corpus ignores last_refreshed timestamps", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8, seed = 4)
  h_before <- sm_hash_corpus(corpus)
  corpus$works$last_refreshed <- Sys.time() + 1000
  expect_identical(sm_hash_corpus(corpus), h_before)
})

test_that("sm_hash_corpus of a corpus without yearly counts is unchanged", {
  # pinned on dev/0.5.0 before citations_by_year existed: corpora without
  # the element, or with an empty one, keep their hash
  corpus <- sm_corpus(
    works = tibble::tibble(
      work_id = c("W1", "W2"), doi = c("10.9999/hash.1", NA),
      title = c("Alpha", "Beta"), year = c(2020L, 2021L),
      cited_by_count = c(3L, 0L)
    ),
    authors = tibble::tibble(author_id = "A1", orcid = NA_character_,
                             display_name = "Ann Roe"),
    authorships = tibble::tibble(
      work_id = c("W1", "W2"), author_id = "A1", position = 1L,
      is_corresponding = NA, institution_id = NA_character_,
      raw_affiliation = "Univ A", country_code = "DE"
    )
  )
  pinned <- "cc28f4d904342c64bc186ad78c6ecb7e75d7173efd757d1f231296022efa000e"
  expect_identical(sm_hash_corpus(corpus), pinned)
  corpus$citations_by_year <- scimapR:::.empty_citations_by_year()
  expect_identical(sm_hash_corpus(corpus), pinned)

  corpus$citations_by_year <- tibble::tibble(work_id = "W1", year = 2021L,
                                             cited_by_count = 2L)
  with_counts <- sm_hash_corpus(corpus)
  expect_false(identical(with_counts, pinned))
  corpus$citations_by_year$cited_by_count <- 3L
  expect_false(identical(sm_hash_corpus(corpus), with_counts))
})

test_that("sm_hash_corpus changes when content changes", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8, seed = 4)
  h_before <- sm_hash_corpus(corpus)
  corpus$works$title[1] <- "A completely different title"
  expect_false(identical(sm_hash_corpus(corpus), h_before))
})

# --- sm_provenance ------------------------------------------------------

test_that("sm_provenance returns the provenance table", {
  corpus <- sm_example_corpus(n_works = 15, n_authors = 6, seed = 2)
  prov <- sm_provenance(corpus)
  expect_s3_class(prov, "tbl_df")
  expect_true(all(c("work_id", "source", "query", "engine",
                    "scimapR_version") %in% names(prov)))
  expect_equal(nrow(prov), 15L)
})

test_that("sm_provenance rejects a non-corpus", {
  expect_error(sm_provenance(42), class = "rlang_error")
})

# --- sm_certificate -----------------------------------------------------

test_that("sm_certificate rejects a non-corpus", {
  expect_error(sm_certificate(list()), class = "rlang_error")
})

test_that("sm_certificate creates a certificate capturing corpus shape", {
  corpus <- sm_example_corpus(n_works = 25, n_authors = 9,
                              with_screening = TRUE, seed = 6)
  cert <- suppressMessages(sm_certificate(corpus))

  expect_s3_class(cert, "sm_certificate")
  expect_equal(cert$certificate_version, "1.0")
  expect_equal(cert$n_works, 25L)
  expect_equal(cert$n_authors, 9L)
  expect_identical(cert$corpus_hash, sm_hash_corpus(corpus))
  expect_true(length(cert$queries) >= 1L)
  expect_true(length(cert$screening_summary) >= 1L)
  expect_equal(cert$embedding_info$n_dimensions, 64L)
})

test_that("sm_certificate records no embeddings for an embedding-free corpus", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  cert <- suppressMessages(sm_certificate(corpus))
  expect_equal(cert$embedding_info$method, "none")
  expect_equal(cert$embedding_info$n_dimensions, 0L)
  expect_identical(cert$embedding_info$model_id, "none")
})

test_that("embeddings without a record of their model are reported unknown", {
  # embeddings made before the record existed, or replaced by hand
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = TRUE, seed = 1)
  info <- suppressMessages(sm_certificate(corpus))$embedding_info
  expect_identical(info$method, "unknown")
  expect_identical(info$model_id, "unknown")
  expect_identical(info$n_works, 10L)

  corpus$metadata$embedding <- .new_embedding_record(
    "minilm-l6", "sentence-transformers/all-MiniLM-L6-v2",
    "sentence-transformers", n_works = 10, n_dimensions = 384
  )
  info <- suppressMessages(sm_certificate(corpus))$embedding_info
  expect_identical(info$model_id, "unknown")
})

test_that("sm_certificate reports the recorded embedding model", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = TRUE, seed = 2)
  corpus$metadata$embedding <- .new_embedding_record(
    "specter2", "allenai/specter2", "adapters", n_works = 10,
    n_dimensions = ncol(corpus$embeddings),
    base_model_id = "allenai/specter2_base", revision = "abc123",
    text = "title_abstract", prefix = "",
    versions = list(adapters = "1.2.0")
  )
  tmp <- withr::local_tempfile(fileext = ".yaml")
  cert <- suppressMessages(sm_certificate(corpus, path = tmp))
  info <- cert$embedding_info
  expect_identical(info$method, "adapters")
  expect_identical(info$model, "specter2")
  expect_identical(info$base_model_id, "allenai/specter2_base")
  expect_identical(info$revision, "abc123")
  expect_identical(info$models, "allenai/specter2")
  expect_match(info$created, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$")
  loaded <- yaml::read_yaml(tmp)$embedding_info
  expect_identical(loaded$model_id, "allenai/specter2")
  expect_identical(loaded$versions$adapters, "1.2.0")
  expect_identical(loaded$n_dimensions, ncol(corpus$embeddings))
})

test_that("sm_certificate writes a YAML file when given a path", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  tmp <- withr::local_tempfile(fileext = ".yaml")
  cert <- suppressMessages(sm_certificate(corpus, path = tmp))
  expect_true(file.exists(tmp))
  loaded <- yaml::read_yaml(tmp)
  expect_equal(loaded$n_works, 10L)
  expect_equal(loaded$corpus_hash, cert$corpus_hash)
})

# --- sm_verify_certificate ---------------------------------------------

test_that("sm_verify_certificate passes for a matching corpus", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8, seed = 3)
  cert <- suppressMessages(sm_certificate(corpus))
  v <- sm_verify_certificate(corpus, cert)

  expect_s3_class(v, "sm_cert_verification")
  expect_true(v$pass)
  expect_true(all(v$checks$pass))
  expect_identical(v$corpus_hash, v$cert_hash)
})

test_that("sm_verify_certificate fails when the corpus content is tampered", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8, seed = 3)
  cert <- suppressMessages(sm_certificate(corpus))

  tampered <- corpus
  tampered$works$title[1] <- "TAMPERED"
  v <- sm_verify_certificate(tampered, cert)

  expect_false(v$pass)
  # The hash check specifically should fail
  hash_check <- dplyr::filter(v$checks, .data$check == "corpus_hash")
  expect_false(hash_check$pass)
})

test_that("sm_verify_certificate fails when a count is tampered", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 8, seed = 3)
  cert <- suppressMessages(sm_certificate(corpus))
  cert$n_works <- 999L
  v <- sm_verify_certificate(corpus, cert)
  expect_false(v$pass)
  nw_check <- dplyr::filter(v$checks, .data$check == "n_works")
  expect_false(nw_check$pass)
})

test_that("sm_verify_certificate accepts a YAML file path", {
  corpus <- sm_example_corpus(n_works = 12, n_authors = 6,
                              with_embeddings = FALSE, seed = 5)
  tmp <- withr::local_tempfile(fileext = ".yaml")
  suppressMessages(sm_certificate(corpus, path = tmp))
  v <- sm_verify_certificate(corpus, tmp)
  expect_s3_class(v, "sm_cert_verification")
  expect_true(v$pass)
})

test_that("sm_verify_certificate rejects a non-certificate object", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  expect_error(
    sm_verify_certificate(corpus, list(foo = 1)),
    "sm_certificate"
  )
})

# --- sm_rebuild_from_cert ----------------------------------------------

test_that("sm_rebuild_from_cert rejects a non-certificate object", {
  expect_error(
    sm_rebuild_from_cert(list(foo = 1)),
    "sm_certificate"
  )
})

test_that("sm_rebuild_from_cert returns an empty corpus when queries are synthetic", {
  # Example corpus provenance source is 'synthetic', which is skipped on rebuild
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 2)
  cert <- suppressMessages(sm_certificate(corpus))
  rebuilt <- suppressMessages(sm_rebuild_from_cert(cert, verbose = FALSE))
  expect_s3_class(rebuilt, "sm_corpus")
  expect_equal(nrow(rebuilt$works), 0L)
})

test_that("sm_rebuild_from_cert returns an empty corpus when no queries recorded", {
  empty <- sm_corpus(works = scimapR:::.empty_works())
  cert <- suppressMessages(sm_certificate(empty))
  rebuilt <- suppressMessages(sm_rebuild_from_cert(cert, verbose = FALSE))
  expect_s3_class(rebuilt, "sm_corpus")
  expect_equal(nrow(rebuilt$works), 0L)
})

# --- print methods ------------------------------------------------------

test_that("print.sm_certificate runs and returns invisibly", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  cert <- suppressMessages(sm_certificate(corpus))
  full <- paste(cli::cli_fmt(print(cert)), collapse = "\n")
  expect_match(full, "sm_certificate")
  expect_invisible(print(cert))
})

test_that("a certificate prints the same UTC time after a YAML round trip", {
  withr::local_timezone("America/Los_Angeles")
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 13)
  tmp <- withr::local_tempfile(fileext = ".yaml")
  fresh <- suppressMessages(sm_certificate(corpus, path = tmp))
  back <- .list_to_cert(yaml::read_yaml(tmp))
  created_line <- function(cert) {
    grep("Created", cli::cli_fmt(print(cert)), value = TRUE)
  }
  expect_match(created_line(fresh),
               "^Created: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8} UTC$")
  expect_identical(created_line(back), created_line(fresh))

  # 08:14:31 in Los Angeles is 15:14:31 UTC, before and after the round trip
  fresh$created <- as.POSIXct("2026-10-18 08:14:31",
                              tz = "America/Los_Angeles")
  back <- .list_to_cert(yaml::yaml.load(yaml::as.yaml(.cert_to_list(fresh))))
  expect_identical(created_line(fresh), "Created: 2026-10-18 15:14:31 UTC")
  expect_identical(created_line(back), "Created: 2026-10-18 15:14:31 UTC")
})

test_that("print.sm_cert_verification shows PASS / FAIL", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  cert <- suppressMessages(sm_certificate(corpus))
  v_pass <- sm_verify_certificate(corpus, cert)
  expect_match(paste(cli::cli_fmt(print(v_pass)), collapse = "\n"), "PASS")

  cert$n_works <- 1L
  v_fail <- sm_verify_certificate(corpus, cert)
  expect_match(paste(cli::cli_fmt(print(v_fail)), collapse = "\n"), "FAIL")
  expect_invisible(print(v_fail))
})

# --- round-trip cert <-> list ------------------------------------------

test_that("sm_certificate accepts numeric, text, Date and POSIXct timestamps", {
  withr::local_timezone("America/Los_Angeles")
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 11)
  values <- list(
    1792237500,
    "2026-10-17T13:45:00+02:00",
    as.POSIXct("2026-10-17 04:45:00", tz = "America/Los_Angeles"),
    as.POSIXlt("2026-10-17 11:45:00", tz = "UTC")
  )
  for (value in values) {
    corpus$metadata$build_date <- value
    corpus$metadata$last_refresh <- value
    cert <- suppressMessages(sm_certificate(corpus))
    expect_identical(cert$metadata$build_date, "2026-10-17T11:45:00Z")
    expect_identical(cert$metadata$last_refresh, "2026-10-17T11:45:00Z")
  }
  corpus$metadata$last_refresh <- as.Date("2026-01-01")
  cert <- suppressMessages(sm_certificate(corpus))
  expect_identical(cert$metadata$last_refresh, "2026-01-01T00:00:00Z")
  corpus$metadata$build_date <- NA
  corpus$metadata$last_refresh <- NULL
  cert <- suppressMessages(sm_certificate(corpus))
  expect_identical(cert$metadata$build_date, NA_character_)
  expect_identical(cert$metadata$last_refresh, NA_character_)
})

test_that("a numeric build_date from a table no longer breaks sm_certificate", {
  works <- tibble::tibble(work_id = "W1", title = "Synthetic work",
                          year = 2020L)
  corpus <- sm_corpus_from_tables(list(works = works),
                                  metadata = list(build_date = 1792195200))
  cert <- suppressMessages(sm_certificate(corpus))
  expect_identical(cert$metadata$build_date, "2026-10-17T00:00:00Z")
  expect_identical(cert$metadata$last_refresh, NA_character_)
})

test_that("certificate timestamps survive a YAML round trip", {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 12)
  corpus$metadata$last_refresh <- 1792237500
  tmp <- withr::local_tempfile(fileext = ".yaml")
  cert <- suppressMessages(sm_certificate(corpus, path = tmp))
  loaded <- yaml::read_yaml(tmp)
  stamp <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
  expect_match(loaded$created, stamp)
  expect_match(loaded$metadata$build_date, stamp)
  expect_identical(.as_utc_time(loaded$metadata$last_refresh),
                   .POSIXct(1792237500, tz = "UTC"))
  back <- .list_to_cert(loaded)
  expect_s3_class(back$created, "POSIXct")
  expect_equal(as.numeric(back$created), floor(as.numeric(cert$created)))
  # certificates written before timestamps were UTC keep loading
  loaded$created <- "2026-10-17T13:45:00+0200"
  expect_identical(.list_to_cert(loaded)$created,
                   .POSIXct(1792237500, tz = "UTC"))
})

test_that("certificate survives YAML round-trip via internal converters", {
  corpus <- sm_example_corpus(n_works = 8, n_authors = 4,
                              with_embeddings = FALSE, seed = 7)
  cert <- suppressMessages(sm_certificate(corpus))
  as_list <- scimapR:::.cert_to_list(cert)
  back <- scimapR:::.list_to_cert(as_list)
  expect_s3_class(back, "sm_certificate")
  expect_identical(back$corpus_hash, cert$corpus_hash)
  expect_equal(back$n_works, cert$n_works)
})

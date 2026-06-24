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

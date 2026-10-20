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

hash_corpus_small <- function() {
  sm_corpus(
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
}

test_that("sm_hash_corpus of a corpus without yearly counts is unchanged", {
  # pinned on dev/0.5.0 before citations_by_year existed: corpora without
  # the element, or with an empty one, keep their hash. The value was
  # computed with the algorithm of scimapR 0.4.0, now version 1; version 2
  # (the default) sorts the columns first and gets its own pinned value.
  corpus <- hash_corpus_small()
  pinned <- "cc28f4d904342c64bc186ad78c6ecb7e75d7173efd757d1f231296022efa000e"
  pinned_v2 <- sm_hash_corpus(corpus)
  expect_identical(sm_hash_corpus(corpus, version = 1), pinned)
  expect_false(identical(pinned_v2, pinned))
  corpus$citations_by_year <- scimapR:::.empty_citations_by_year()
  expect_identical(sm_hash_corpus(corpus, version = 1), pinned)
  expect_identical(sm_hash_corpus(corpus), pinned_v2)

  corpus$citations_by_year <- tibble::tibble(work_id = "W1", year = 2021L,
                                             cited_by_count = 2L)
  with_counts <- sm_hash_corpus(corpus)
  expect_false(identical(with_counts, pinned_v2))
  corpus$citations_by_year$cited_by_count <- 3L
  expect_false(identical(sm_hash_corpus(corpus), with_counts))
})

test_that("the version 2 hash is pinned", {
  # sm_hash_corpus() as scimapR 0.5.0 computes it; other functions (locks,
  # snapshots, certificates) compare against stored values of it
  expect_identical(
    sm_hash_corpus(hash_corpus_small()),
    "dd5e167937eb0d758c67bb8d3a8ad56e9c612a958a2702f26eb08ac075d7d02a"
  )
})

test_that("sm_hash_corpus ignores the order of columns and embedding rows", {
  corpus <- sm_example_corpus(n_works = 12, n_authors = 6, seed = 8)
  reordered <- corpus
  reordered$works <- reordered$works[, rev(names(reordered$works))]
  reordered$authorships <-
    reordered$authorships[, rev(names(reordered$authorships))]
  reordered$embeddings <- reordered$embeddings[rev(seq_len(12)), ]
  expect_identical(sm_hash_corpus(reordered), sm_hash_corpus(corpus))
  # the algorithm of earlier versions depended on both
  expect_false(identical(sm_hash_corpus(reordered, version = 1),
                         sm_hash_corpus(corpus, version = 1)))

  # a data frame hashes as the tibble it holds
  reordered$works <- as.data.frame(corpus$works)
  expect_identical(sm_hash_corpus(reordered), sm_hash_corpus(corpus))
})

test_that("sm_hash_corpus leaves provenance and metadata out of the hash", {
  # provenance records fetch dates; local inputs are checked on their own
  corpus <- sm_example_corpus(n_works = 8, n_authors = 4, seed = 9)
  before <- sm_hash_corpus(corpus)
  corpus$provenance$query[1] <- "edited"
  corpus$provenance$fetch_date <- corpus$provenance$fetch_date + 3600
  corpus$metadata$local_inputs <- scimapR:::.empty_local_inputs()
  expect_identical(sm_hash_corpus(corpus), before)
})

test_that("sm_hash_corpus rejects an unknown version", {
  corpus <- hash_corpus_small()
  expect_error(sm_hash_corpus(corpus, version = 3), "must be 1 or 2")
  expect_error(sm_hash_corpus(corpus, version = "2"), "must be 1 or 2")
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

# --- hash versions in certificates ---------------------------------------

test_that("certificates record hash version 2; older ones verify with 1", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 14)
  tmp <- withr::local_tempfile(fileext = ".yaml")
  cert <- suppressMessages(sm_certificate(corpus, path = tmp))
  expect_identical(cert$hash_version, 2L)
  expect_identical(yaml::read_yaml(tmp)$hash_version, 2L)
  v <- sm_verify_certificate(corpus, tmp)
  expect_true(v$pass)
  expect_identical(v$hash_version, 2L)

  # a certificate written before hash versions holds a version 1 hash
  old <- cert
  old$hash_version <- NULL
  old$corpus_hash <- sm_hash_corpus(corpus, version = 1)
  v <- sm_verify_certificate(corpus, old)
  expect_true(v$pass)
  expect_identical(v$hash_version, 1L)
  expect_identical(v$corpus_hash, old$corpus_hash)
  # and is not read as version 2
  old$corpus_hash <- cert$corpus_hash
  expect_false(sm_verify_certificate(corpus, old)$pass)
})

# --- local inputs ----------------------------------------------------------

# A project folder with a data subfolder holding two input files of fixed
# content; the working directory is the project folder until the calling
# test ends.
local_input_project <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(root, "data"))
  writeLines(c("doi,unit", "10.9999/cert.1,Unit A", "10.9999/cert.2,Unit B"),
             file.path(root, "data", "tracker.csv"))
  writeLines(c("pattern,institution", "field hospital,Unit A"),
             file.path(root, "data", "dictionary.csv"))
  withr::local_dir(root, .local_envir = env)
  normalizePath(root, winslash = "/")
}

input_corpus <- function() {
  corpus <- sm_example_corpus(n_works = 6, n_authors = 3,
                              with_embeddings = FALSE, seed = 21)
  corpus <- sm_register_input(corpus, "data/tracker.csv",
                              role = "publication tracker",
                              builder = "R/01_import.R::read_tracker")
  sm_register_input(corpus, "data/dictionary.csv", role = "dictionary")
}

test_that("sm_register_input records a file with its SHA-256", {
  root <- local_input_project()
  corpus <- input_corpus()
  inputs <- corpus$metadata$local_inputs
  expect_s3_class(inputs, "tbl_df")
  expect_identical(names(inputs), names(scimapR:::.empty_local_inputs()))
  expect_identical(inputs$path, c("data/tracker.csv", "data/dictionary.csv"))
  expect_identical(inputs$basename, c("tracker.csv", "dictionary.csv"))
  expect_identical(inputs$root, rep(root, 2))
  expect_identical(inputs$path_abs, file.path(root, inputs$path))
  expect_identical(
    inputs$sha256[1],
    digest::digest("data/tracker.csv", algo = "sha256", file = TRUE)
  )
  expect_identical(inputs$bytes[1], as.numeric(file.size("data/tracker.csv")))
  expect_identical(inputs$role, c("publication tracker", "dictionary"))
  expect_identical(inputs$builder,
                   c("R/01_import.R::read_tracker", NA_character_))
  expect_s3_class(inputs$registered_at, "POSIXct")
  expect_identical(attr(inputs$registered_at, "tzone"), "UTC")
  expect_identical(as.numeric(inputs$registered_at),
                   floor(as.numeric(inputs$registered_at)))
})

test_that("registering a file again keeps one row", {
  root <- local_input_project()
  corpus <- input_corpus()
  cat("10.9999/cert.3,Unit C\n", file = "data/tracker.csv", append = TRUE)
  again <- sm_register_input(corpus, "./data/tracker.csv", role = "tracker")
  again <- sm_register_input(again, file.path(root, "data", "tracker.csv"),
                             role = "tracker v2")
  inputs <- again$metadata$local_inputs
  expect_identical(nrow(inputs), 2L)
  expect_identical(inputs$role, c("tracker v2", "dictionary"))
  expect_identical(
    inputs$sha256[1],
    digest::digest("data/tracker.csv", algo = "sha256", file = TRUE)
  )
})

test_that("a file outside the working directory keeps its path as given", {
  local_input_project()
  outside <- withr::local_tempfile(fileext = ".csv")
  writeLines("a,b", outside)
  corpus <- sm_register_input(sm_example_corpus(n_works = 3, seed = 1),
                              outside)
  expect_identical(corpus$metadata$local_inputs$path, outside)
  expect_identical(corpus$metadata$local_inputs$path_abs,
                   file.path(normalizePath(dirname(outside), winslash = "/"),
                             basename(outside)))
})

test_that("sm_register_input refuses locked corpora, folders and bad files", {
  local_input_project()
  corpus <- sm_example_corpus(n_works = 3, n_authors = 2, seed = 1)
  locked <- suppressMessages(sm_lock(corpus, reason = "archived"))
  expect_error(sm_register_input(locked, "data/tracker.csv"),
               "locked")
  expect_error(sm_register_input(corpus, "data"), "folder")
  expect_error(sm_register_input(corpus, "data/none.csv"), "No such file")
  expect_error(sm_register_input(corpus, c("a", "b")), "single string")
  expect_error(sm_register_input(corpus, "data/tracker.csv", role = 1),
               "single string")
  expect_error(sm_register_input(list(), "data/tracker.csv"), "sm_corpus")
})

test_that("verification passes, fails a changed and skips a missing input", {
  local_input_project()
  corpus <- input_corpus()
  cert <- suppressMessages(sm_certificate(corpus))
  expect_s3_class(cert$local_inputs, "tbl_df")
  expect_identical(nrow(cert$local_inputs), 2L)

  v <- sm_verify_certificate(corpus, cert)
  expect_true(v$pass)
  expect_identical(v$n_not_checked, 0L)
  rows <- v$checks[startsWith(v$checks$check, "input:"), ]
  expect_identical(rows$check, c("input:tracker.csv", "input:dictionary.csv"))
  expect_identical(rows$status, c("pass", "pass"))
  expect_identical(rows$location,
                   normalizePath(c("data/tracker.csv", "data/dictionary.csv"),
                                 winslash = "/"))
  expect_identical(rows$expected, substr(cert$local_inputs$sha256, 1, 16))

  # one changed byte fails that row only
  bytes <- readBin("data/tracker.csv", "raw", file.size("data/tracker.csv"))
  bytes[5] <- as.raw(bitwXor(as.integer(bytes[5]), 1L))
  writeBin(bytes, "data/tracker.csv")
  v <- sm_verify_certificate(corpus, cert)
  expect_false(v$pass)
  expect_identical(v$checks$status[v$checks$check == "input:tracker.csv"],
                   "fail")
  expect_identical(v$checks$pass[v$checks$check == "input:tracker.csv"],
                   FALSE)
  expect_identical(sum(v$checks$status == "fail"), 1L)

  # a missing file is not checked: overall PASS, with a warning naming it
  file.remove("data/tracker.csv")
  expect_warning(
    v <- sm_verify_certificate(corpus, cert),
    "data/tracker.csv",
    class = "scimapR_cert_inputs_missing"
  )
  expect_true(v$pass)
  expect_identical(v$n_not_checked, 1L)
  row <- v$checks[v$checks$check == "input:tracker.csv", ]
  expect_identical(row$status, "not checked")
  expect_identical(row$pass, NA)
  expect_identical(row$actual, "missing")
  expect_identical(row$location, NA_character_)
})

test_that("inputs resolve against the certificate's folder", {
  root <- local_input_project()
  corpus <- input_corpus()
  suppressMessages(sm_certificate(corpus, path = "cert.yaml"))
  # the project moves: its files sit next to the certificate in a new
  # folder, and verification runs from yet another folder
  moved <- withr::local_tempdir()
  dir.create(file.path(moved, "data"))
  file.copy(file.path(root, "cert.yaml"), moved)
  file.copy(file.path(root, "data", c("tracker.csv", "dictionary.csv")),
            file.path(moved, "data"))
  unlink(file.path(root, "data"), recursive = TRUE)
  withr::local_dir(withr::local_tempdir())

  v <- sm_verify_certificate(corpus, file.path(moved, "cert.yaml"))
  expect_true(v$pass)
  inputs <- v$checks[startsWith(v$checks$check, "input:"), ]
  expect_identical(inputs$status, c("pass", "pass"))
  expect_identical(
    inputs$location,
    file.path(normalizePath(moved, winslash = "/"), "data",
              c("tracker.csv", "dictionary.csv"))
  )
})

test_that("a certificate in a subfolder still finds inputs from the root", {
  # data/ registered from the project root, certificate in output/: the
  # certificate's folder holds no data/, the working directory does
  root <- local_input_project()
  corpus <- input_corpus()
  dir.create("output")
  suppressMessages(sm_certificate(corpus, path = "output/cert.yaml"))
  v <- sm_verify_certificate(corpus, "output/cert.yaml")
  expect_true(v$pass)
  expect_identical(v$n_not_checked, 0L)
  expect_identical(v$checks$location[v$checks$check == "input:tracker.csv"],
                   file.path(root, "data", "tracker.csv"))

  # from another folder the absolute path recorded at registration is used
  withr::local_dir(withr::local_tempdir())
  v <- sm_verify_certificate(corpus, file.path(root, "output", "cert.yaml"))
  expect_true(v$pass)
  expect_identical(v$n_not_checked, 0L)
})

test_that("base_dir names the folder the input paths are relative to", {
  root <- local_input_project()
  corpus <- input_corpus()
  cert <- suppressMessages(sm_certificate(corpus))
  copy <- withr::local_tempdir()
  dir.create(file.path(copy, "data"))
  file.copy(file.path(root, "data", c("tracker.csv", "dictionary.csv")),
            file.path(copy, "data"))
  unlink(file.path(root, "data"), recursive = TRUE)
  withr::local_dir(withr::local_tempdir())

  expect_warning(
    v <- sm_verify_certificate(corpus, cert),
    class = "scimapR_cert_inputs_missing"
  )
  expect_identical(v$n_not_checked, 2L)
  v <- sm_verify_certificate(corpus, cert, base_dir = copy)
  expect_true(v$pass)
  expect_identical(v$n_not_checked, 0L)
  expect_error(sm_verify_certificate(corpus, cert, base_dir = "no/such/dir"),
               "existing folder")
})

test_that("files that share a name get checks of their own", {
  local_input_project()
  dir.create("other")
  writeLines("other content", "other/tracker.csv")
  corpus <- sm_register_input(input_corpus(), "other/tracker.csv")
  v <- sm_verify_certificate(corpus, suppressMessages(sm_certificate(corpus)))
  expect_identical(
    v$checks$check[startsWith(v$checks$check, "input:")],
    c("input:data/tracker.csv", "input:dictionary.csv",
      "input:other/tracker.csv")
  )
  expect_true(v$pass)
})

test_that("a verification with a not-checked input prints", {
  local_input_project()
  corpus <- input_corpus()
  cert <- suppressMessages(sm_certificate(corpus))
  writeLines("changed", "data/dictionary.csv")
  file.remove("data/tracker.csv")
  expect_warning(v <- sm_verify_certificate(corpus, cert),
                 class = "scimapR_cert_inputs_missing")
  scrub <- function(x) gsub("[0-9a-f]{16}", "<hash>", x)
  expect_snapshot(print(v), transform = scrub)
  expect_invisible(suppressMessages(print(v)))
})

test_that("print.sm_certificate counts the local inputs", {
  local_input_project()
  shown <- function(cert) {
    grep("Local inputs", cli::cli_fmt(print(cert)), value = TRUE)
  }
  plain <- sm_example_corpus(n_works = 4, n_authors = 2,
                             with_embeddings = FALSE, seed = 3)
  expect_identical(shown(suppressMessages(sm_certificate(plain))),
                   "Local inputs: 0")
  expect_identical(shown(suppressMessages(sm_certificate(input_corpus()))),
                   "Local inputs: 2")
})

test_that("local inputs and timestamps survive a YAML round trip", {
  local_input_project()
  withr::local_timezone("America/Los_Angeles")
  for (n in 0:2) {
    corpus <- sm_example_corpus(n_works = 4, n_authors = 2,
                                with_embeddings = FALSE, seed = 4)
    files <- c("data/tracker.csv", "data/dictionary.csv")[seq_len(n)]
    for (f in files) corpus <- sm_register_input(corpus, f, role = "input")
    tmp <- withr::local_tempfile(fileext = ".yaml")
    cert <- suppressMessages(sm_certificate(corpus, path = tmp))
    raw <- yaml::read_yaml(tmp)
    expect_length(raw$local_inputs, n)
    stamp <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
    expect_match(raw$created, stamp)
    for (row in raw$local_inputs) {
      expect_match(row$registered_at, stamp)
      expect_type(row$bytes, "double")
    }

    back <- .list_to_cert(raw)
    expect_identical(back$local_inputs, cert$local_inputs)
    expect_identical(as.numeric(back$created), floor(as.numeric(cert$created)))
    expect_identical(sm_verify_certificate(corpus, back)$checks$status,
                     sm_verify_certificate(corpus, cert)$checks$status)
  }
  # the readers of the block take a tibble, rows and columns alike
  inputs <- cert$local_inputs
  rows <- .local_inputs_to_list(inputs)
  by_column <- inputs
  by_column$registered_at <- format(inputs$registered_at,
                                    "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  columns <- yaml::yaml.load(yaml::as.yaml(list(x = by_column)))$x
  expect_identical(.as_local_inputs_tbl(rows), inputs)
  expect_identical(.as_local_inputs_tbl(columns), inputs)
  expect_identical(.as_local_inputs_tbl(as.data.frame(inputs)), inputs)
  expect_identical(.as_local_inputs_tbl(NULL), .empty_local_inputs())
  expect_identical(.as_local_inputs_tbl(list()), .empty_local_inputs())
  one <- .as_local_inputs_tbl(list(list(path = "x.csv", sha256 = "ab")))
  expect_identical(one$path, "x.csv")
  expect_identical(one$bytes, NA_real_)
})

# --- certificate steps ----------------------------------------------------

test_that("certificates record file steps without absolute paths", {
  root <- local_input_project()
  prov <- tibble::tibble(
    work_id = c("W1", "W2", "W3"),
    source = c("wos", "openalex", "pubmed"),
    source_id_external = NA_character_,
    fetch_date = as.POSIXct("2026-10-01", tz = "UTC"),
    query = c(file.path(root, "data", "export.txt"), "/elsewhere/works.json",
              "enrich_concepts_mesh"),
    engine = "native", scimapR_version = "0.4.0", prompt_hash = NA_character_
  )
  corpus <- suppressMessages(sm_corpus_from_tables(list(
    works = tibble::tibble(work_id = c("W1", "W2", "W3"), title = "x"),
    provenance = prov
  )))
  queries <- suppressMessages(sm_certificate(corpus))$queries
  expect_identical(vapply(queries, `[[`, "", "kind"),
                   c("file", "file", "enrichment"))
  expect_identical(vapply(queries, `[[`, "", "query"),
                   c("data/export.txt", "works.json", "enrich_concepts_mesh"))
})

test_that("certificates record the filter and n_max of searches", {
  corpus <- sm_example_corpus(n_works = 4, n_authors = 2,
                              with_embeddings = FALSE, seed = 5)
  corpus$provenance$source <- "openalex"
  corpus$provenance$query <- "field surgery"
  corpus$provenance <- .record_request(
    list(provenance = corpus$provenance),
    filter = "type:article", n_max = 40L
  )$provenance
  queries <- suppressMessages(sm_certificate(corpus))$queries
  expect_length(queries, 1L)
  expect_identical(queries[[1]][c("kind", "filter", "n_max")],
                   list(kind = "api_query", filter = "type:article",
                        n_max = 40L))
})

# --- rebuilding -------------------------------------------------------------

# A certificate with the given steps (each a list) and, optionally, the
# local inputs of a corpus
step_cert <- function(queries, inputs = NULL, n_works = 25L) {
  structure(list(
    corpus_hash = strrep("ab", 32), n_works = n_works, queries = queries,
    local_inputs = .as_local_inputs_tbl(inputs)
  ), class = "sm_certificate")
}

# A fetched corpus of n works whose provenance records the request
fake_fetch <- function(source, n, query = "q", filter = NULL, n_max = n) {
  works <- tibble::tibble(
    work_id = sprintf("W%09d", seq_len(n)),
    doi = sprintf("10.9999/%s.%d", source, seq_len(n)),
    title = paste(source, seq_len(n))
  )
  corpus <- sm_corpus(
    works = works,
    provenance = tibble::tibble(
      work_id = works$work_id, source = source,
      source_id_external = NA_character_, fetch_date = Sys.time(),
      query = query, engine = "native", scimapR_version = "0.5.0",
      prompt_hash = NA_character_
    )
  )
  .record_request(corpus, filter = filter, n_max = n_max)
}

test_that("a certificate of local inputs only stops and names the builder", {
  local_input_project()
  corpus <- input_corpus()
  corpus$provenance$source <- "wos"
  corpus$provenance$query <- "data/export.txt"
  cert <- suppressMessages(sm_certificate(corpus))
  err <- expect_error(
    suppressMessages(sm_rebuild_from_cert(cert)),
    class = "scimapR_cert_not_replayable"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "\"wos\" (file) \"data/export.txt\"", fixed = TRUE)
  expect_match(msg, "\"tracker.csv\": publication tracker", fixed = TRUE)
  expect_match(msg, substr(cert$local_inputs$sha256[1], 1, 12), fixed = TRUE)
  expect_match(msg, "R/01_import.R::read_tracker", fixed = TRUE)
  expect_match(msg, "\"dictionary.csv\": dictionary", fixed = TRUE)
})

test_that("sm_rebuild_from_cert replays searches with their fetcher", {
  calls <- list()
  record <- function(fetcher) {
    function(query = NULL, filter = NULL, n_max = 200L, engine = "native",
             verbose = TRUE, call = NULL) {
      calls[[length(calls) + 1L]] <<- list(
        fetcher = fetcher, query = query, filter = filter, n_max = n_max,
        engine = engine
      )
      fake_fetch(fetcher, 3, query = query, filter = filter, n_max = n_max)
    }
  }
  local_mocked_bindings(
    sm_fetch_openalex = record("openalex"),
    sm_fetch_pubmed = function(query, n_max = 200L, engine = "native",
                               verbose = TRUE, call = NULL) {
      record("pubmed")(query = query, n_max = n_max, engine = engine)
    },
    sm_fetch_crossref = record("crossref")
  )
  inputs <- tibble::tibble(path = "data/db.sqlite", basename = "db.sqlite",
                           sha256 = strrep("0f", 32),
                           role = "source database")
  cert <- step_cert(list(
    list(source = "openalex", query = "field surgery", engine = "openalexR",
         kind = "api_query", filter = "type:article", n_max = 40L),
    list(source = "pubmed", query = "burns[tiab]", engine = "rentrez",
         kind = "api_query", n_max = 20L),
    list(source = "crossref", filter = "from-pub-date:2020", engine = "native",
         kind = "api_query", n_max = 10L),
    list(source = "wos", query = "data/export.txt", engine = "native",
         kind = "file"),
    list(source = "openalex_impact", query = "sm_enrich_openalex_impact()",
         engine = "native", kind = "enrichment"),
    list(source = "arxiv", query = "x", engine = "native",
         kind = "api_query")
  ), inputs = inputs)

  msgs <- testthat::capture_messages(
    rebuilt <- sm_rebuild_from_cert(cert, verbose = FALSE)
  )
  expect_identical(vapply(calls, `[[`, "", "fetcher"),
                   c("openalex", "pubmed", "crossref"))
  expect_identical(calls[[1]][c("query", "filter", "n_max", "engine")],
                   list(query = "field surgery", filter = "type:article",
                        n_max = 40L, engine = "openalexR"))
  expect_identical(calls[[2]][c("query", "n_max", "engine")],
                   list(query = "burns[tiab]", n_max = 20L,
                        engine = "rentrez"))
  expect_identical(calls[[3]][c("query", "filter", "n_max")],
                   list(query = NULL, filter = "from-pub-date:2020",
                        n_max = 10L))

  # works of the three searches, new ids, provenance that replays them
  expect_identical(nrow(rebuilt$works), 9L)
  expect_identical(rebuilt$works$work_id, sprintf("W%09d", 1:9))
  expect_identical(rebuilt$provenance$work_id, rebuilt$works$work_id)
  expect_identical(unique(rebuilt$provenance$n_max), c(40L, 20L, 10L))
  expect_true(rebuilt$metadata$rebuilt_from_cert)

  # the steps not replayed are named
  msg <- paste(msgs, collapse = "\n")
  expect_match(msg, "Not replayed: 3 steps and 1 local input", fixed = TRUE)
  expect_match(msg, "\"wos\" (file)", fixed = TRUE)
  expect_match(msg, "\"openalex_impact\" (enrichment)", fixed = TRUE)
  expect_match(msg, "\"arxiv\" (api_query)", fixed = TRUE)
  expect_match(msg, "\"db.sqlite\": source database", fixed = TRUE)
})

test_that("searches without a recorded n_max fetch the certified size", {
  seen <- NULL
  local_mocked_bindings(
    sm_fetch_openalex = function(query = NULL, filter = NULL, n_max = 200L,
                                 engine = "native", verbose = TRUE,
                                 call = NULL) {
      seen <<- n_max
      fake_fetch("openalex", 2, query = query)
    }
  )
  # a certificate of scimapR 0.4.0: no kind, no n_max
  cert <- step_cert(list(list(source = "openalex", query = "triage",
                              engine = "native")), n_works = 2417L)
  expect_message(
    rebuilt <- sm_rebuild_from_cert(cert, verbose = FALSE),
    "up to 2417 works"
  )
  expect_identical(seen, 2417L)
  expect_identical(nrow(rebuilt$works), 2L)
})

test_that("file paths and enrichment placeholders are never searched", {
  # certificates written before step kinds: file readers recorded the API
  # name with the file path, enrichers placeholder queries
  local_mocked_bindings(
    sm_fetch_openalex = function(...) stop("sent a search"),
    sm_fetch_pubmed = function(...) stop("sent a search"),
    sm_fetch_crossref = function(...) stop("sent a search")
  )
  cert <- step_cert(list(
    list(source = "openalex", query = "/Users/me/proj/export.json",
         engine = "native"),
    list(source = "pubmed", query = "pubmed_export.xml", engine = "native"),
    list(source = "openalex", query = "enrich_concepts_openalex",
         engine = "native"),
    list(source = "openalex_refresh", query = "sm_refresh(what=citations)",
         engine = "native")
  ))
  err <- expect_error(sm_rebuild_from_cert(cert, verbose = FALSE),
                      class = "scimapR_cert_not_replayable")
  msg <- conditionMessage(err)
  expect_match(msg, "Step 1, \"openalex\" (file)", fixed = TRUE)
  expect_match(msg, "Step 2, \"pubmed\" (file)", fixed = TRUE)
  expect_match(msg, "Step 3, \"openalex\" (enrichment)", fixed = TRUE)
  expect_match(msg, "Step 4, \"openalex_refresh\" (refresh)", fixed = TRUE)
  # no line for local inputs the certificate does not have
  expect_no_match(msg, "Local input", fixed = TRUE)
})

test_that("the realuse fixture's certificate cannot be replayed", {
  # its works come from a Web of Science export, a file
  fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
  cert <- suppressMessages(sm_certificate(fix))
  expect_identical(cert$queries[[1]]$kind, "file")
  expect_error(sm_rebuild_from_cert(cert, verbose = FALSE),
               class = "scimapR_cert_not_replayable")
})

test_that("a corpus read from a saved OpenAlex file is not searched again", {
  # the reader records the API name; its file step is never sent to the
  # API with the path as search text
  local_mocked_bindings(sm_fetch_openalex = function(...) stop("searched"))
  path <- withr::local_tempfile(fileext = ".json")
  writeLines('[{"id":"W1","title":"One","publication_year":2020}]', path)
  corpus <- sm_read_openalex_json(path, verbose = FALSE)
  cert <- suppressMessages(sm_certificate(corpus))
  expect_false(grepl(dirname(path), cert$queries[[1]]$query, fixed = TRUE))
  err <- expect_error(sm_rebuild_from_cert(cert, verbose = FALSE),
                      class = "scimapR_cert_not_replayable")
  expect_match(conditionMessage(err), "\"openalex\" (file)", fixed = TRUE)
})

test_that("certificates without file reads or local inputs rebuild empty", {
  # synthetic records, enrichments, refreshes and searches of other sources
  # cannot be replayed; without file reads or local inputs the rebuild
  # names them in a message and returns an empty corpus, as before
  local_mocked_bindings(
    sm_fetch_openalex = function(...) stop("sent a search"),
    sm_fetch_pubmed = function(...) stop("sent a search"),
    sm_fetch_crossref = function(...) stop("sent a search")
  )
  cert <- step_cert(list(
    list(source = "synthetic", query = "sm_example_corpus()",
         engine = "native", kind = "manual"),
    list(source = "openalex_impact", query = "sm_enrich_openalex_impact()",
         engine = "native", kind = "enrichment"),
    list(source = "openalex_refresh", query = "sm_refresh(what=citations)",
         engine = "native", kind = "refresh"),
    list(source = "arxiv", query = "x", engine = "native",
         kind = "api_query")
  ))
  expect_message(
    rebuilt <- sm_rebuild_from_cert(cert, verbose = FALSE),
    class = "scimapR_cert_not_replayed"
  )
  expect_s3_class(rebuilt, "sm_corpus")
  expect_identical(nrow(rebuilt$works), 0L)

  msg <- paste(testthat::capture_messages(
    sm_rebuild_from_cert(cert, verbose = FALSE)
  ), collapse = "\n")
  expect_match(msg, "the rebuilt corpus is empty", fixed = TRUE)
  expect_match(msg, "Step 1, \"synthetic\" (manual)", fixed = TRUE)
  expect_match(msg, "Step 2, \"openalex_impact\" (enrichment)", fixed = TRUE)
  expect_match(msg, "Step 3, \"openalex_refresh\" (refresh)", fixed = TRUE)
  expect_match(msg, "Step 4, \"arxiv\" (api_query)", fixed = TRUE)
  expect_no_match(msg, "Local input", fixed = TRUE)
})

test_that("rebuild messages leave out empty step and input lines", {
  local_input_project()
  # local inputs and no step at all, as from sm_corpus_from_tables()
  works <- tibble::tibble(work_id = "W1", title = "One", year = 2020L)
  corpus <- suppressMessages(sm_corpus_from_tables(
    list(works = works), inputs = c("source database" = "data/tracker.csv")
  ))
  cert <- suppressMessages(sm_certificate(corpus))
  expect_length(cert$queries, 0L)
  err <- expect_error(sm_rebuild_from_cert(cert, verbose = FALSE),
                      class = "scimapR_cert_not_replayable")
  msg <- conditionMessage(err)
  expect_match(msg, "Local input \"tracker.csv\": source database",
               fixed = TRUE)
  expect_no_match(msg, "Step ", fixed = TRUE)

  # a file step and no local input
  wos <- list(source = "wos", query = "data/export.txt", engine = "native",
              kind = "file")
  err <- expect_error(
    sm_rebuild_from_cert(step_cert(list(wos)), verbose = FALSE),
    class = "scimapR_cert_not_replayable"
  )
  expect_match(conditionMessage(err), "Step 1, \"wos\" (file)", fixed = TRUE)
  expect_no_match(conditionMessage(err), "Local input", fixed = TRUE)

  # a search next to the file step, without local inputs
  local_mocked_bindings(
    sm_fetch_openalex = function(query = NULL, filter = NULL, n_max = 200L,
                                 engine = "native", verbose = TRUE,
                                 call = NULL) {
      fake_fetch("openalex", 2, query = query, n_max = n_max)
    }
  )
  search <- list(source = "openalex", query = "triage", engine = "native",
                 kind = "api_query", n_max = 2L)
  msg <- paste(testthat::capture_messages(
    rebuilt <- sm_rebuild_from_cert(step_cert(list(search, wos)),
                                    verbose = FALSE)
  ), collapse = "\n")
  expect_identical(nrow(rebuilt$works), 2L)
  expect_match(msg, "Not replayed: 1 step and 0 local inputs", fixed = TRUE)
  expect_match(msg, "Step 2, \"wos\" (file)", fixed = TRUE)
  expect_no_match(msg, "Local input", fixed = TRUE)
})

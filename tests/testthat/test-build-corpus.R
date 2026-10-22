test_that("sm_build_corpus combines two corpora", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 1)
  c2 <- sm_example_corpus(n_works = 15, n_authors = 8,
                          with_embeddings = FALSE, seed = 2)

  combined <- sm_build_corpus(c1, c2, dedupe = FALSE, verbose = FALSE)

  expect_s3_class(combined, "sm_corpus")
  expect_equal(nrow(combined$works), 35L)
})

test_that("sm_build_corpus deduplicates by DOI when dedupe = TRUE", {
  c1 <- sm_example_corpus(n_works = 20, n_authors = 10,
                          with_embeddings = FALSE, seed = 1)
  # Create a second corpus with overlapping DOIs
  c2 <- c1[1:5]

  combined <- sm_build_corpus(c1, c2, dedupe = TRUE, verbose = FALSE)

  expect_s3_class(combined, "sm_corpus")
  # Should not have more than the original 20
  expect_lte(nrow(combined$works), 25L)
})

test_that("sm_bind_corpora row-binds two corpora", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 2)

  bound <- sm_bind_corpora(c1, c2)

  expect_s3_class(bound, "sm_corpus")
  expect_equal(nrow(bound$works), 20L)
})

test_that("sm_bind_corpora merges embeddings if dimensions match", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 2)

  bound <- sm_bind_corpora(c1, c2)
  expect_true(!is.null(bound$embeddings))
  expect_equal(nrow(bound$embeddings), 20L)
})

test_that("sm_bind_corpora warns when only one input has embeddings", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 2)

  expect_warning(bound <- sm_bind_corpora(c1, c2),
                 class = "scimapR_bind_embeddings_dropped")
  expect_null(bound$embeddings)
})

test_that("sm_bind_corpora rejects non-corpus input", {
  corpus <- sm_example_corpus(n_works = 5, n_authors = 3,
                              with_embeddings = FALSE, seed = 1)
  expect_error(sm_bind_corpora(corpus, "not_a_corpus"), "sm_corpus")
  expect_error(sm_bind_corpora("not_a_corpus", corpus), "sm_corpus")
})

test_that("sm_dedupe removes duplicate DOIs", {
  corpus <- sm_example_corpus(n_works = 20, n_authors = 10,
                              with_embeddings = FALSE, seed = 1)
  # Manually duplicate some works
  dup_works <- corpus$works[1:3, ]
  dup_works$work_id <- paste0("W99999000", 1:3)
  corpus$works <- dplyr::bind_rows(corpus$works, dup_works)

  deduped <- sm_dedupe(corpus, verbose = FALSE)

  expect_s3_class(deduped, "sm_corpus")
  expect_lte(nrow(deduped$works), nrow(corpus$works))
  # No duplicate DOIs among non-NA DOIs
  doi_present <- deduped$works$doi[!is.na(deduped$works$doi)]
  expect_false(any(duplicated(doi_present)))
})

test_that("sm_dedupe preserves works with NA DOI", {
  corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                              with_embeddings = FALSE, seed = 1)
  # Set some DOIs to NA

  corpus$works$doi[1:3] <- NA_character_

  deduped <- sm_dedupe(corpus, verbose = FALSE)
  na_count <- sum(is.na(deduped$works$doi))
  expect_gte(na_count, 3L)
})

test_that("binding and deduplicating keep the yearly citation counts", {
  yearly <- function(ids) {
    tibble::tibble(work_id = ids, year = 2022L, cited_by_count = 1L)
  }
  works <- function(ids, dois) tibble::tibble(work_id = ids, doi = dois)
  c1 <- sm_corpus(works(c("W1", "W2"), c("10.9999/a", "10.9999/b")),
                  citations_by_year = yearly(c("W1", "W2")))
  c2 <- sm_corpus(works(c("W3", "W4"), c("10.9999/c", "10.9999/a")),
                  citations_by_year = yearly(c("W3", "W4")))
  plain <- sm_corpus(tibble::tibble(work_id = "W5", doi = "10.9999/e"))

  bound <- sm_bind_corpora(c1, c2)
  expect_identical(bound$citations_by_year$work_id, c("W1", "W2", "W3", "W4"))
  expect_identical(sm_bind_corpora(plain, c2)$citations_by_year$work_id,
                   c("W3", "W4"))
  expect_false("citations_by_year" %in% names(sm_bind_corpora(plain, plain)))
  # Each input record retains its own yearly counts until deduplication.
  repeated <- sm_bind_corpora(c1, c1)
  expect_identical(nrow(repeated$citations_by_year), 4L)
  expect_identical(repeated$citations_by_year$work_id,
                   repeated$works$work_id)

  deduped <- sm_dedupe(bound, verbose = FALSE)
  expect_identical(sort(deduped$citations_by_year$work_id),
                   sort(deduped$works$work_id))
  expect_identical(nrow(deduped$citations_by_year), 3L)
})

test_that("sm_bind_corpora binds embeddings of one recorded model", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 2)
  record <- function(id, corpus) {
    .new_embedding_record(id, id, "sentence-transformers",
                          n_works = nrow(corpus$embeddings),
                          n_dimensions = ncol(corpus$embeddings))
  }
  c1$metadata$embedding <- record("mpnet", c1)
  c2$metadata$embedding <- record("mpnet", c2)
  bound <- sm_bind_corpora(c1, c2)
  expect_identical(nrow(bound$embeddings), 20L)
  expect_identical(bound$metadata$embedding$model_id, "mpnet")
  expect_identical(bound$metadata$embedding$n_works, 20L)

  # two models, or a recorded and an unrecorded one, are not bound
  c2$metadata$embedding <- record("scincl", c2)
  expect_error(sm_bind_corpora(c1, c2), "mix_models = TRUE",
               class = "scimapR_embedding_model_mismatch")
  plain <- c2
  plain$metadata$embedding <- NULL
  expect_error(sm_bind_corpora(c1, plain), "not recorded",
               class = "scimapR_embedding_model_mismatch")

  # unless asked: the bound rows are a recorded mix
  mixed <- sm_bind_corpora(c1, c2, mix_models = TRUE)
  expect_identical(nrow(mixed$embeddings), 20L)
  expect_identical(mixed$metadata$embedding$model_id, "mixed")
  expect_identical(mixed$metadata$embedding$models, c("mpnet", "scincl"))
  expect_error(sm_bind_corpora(c1, c2, mix_models = NA), "TRUE")
})

test_that("sm_bind_corpora keeps no record for embeddings it drops", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = FALSE, seed = 2)
  c1$metadata$embedding <- .new_embedding_record(
    "mpnet", "mpnet", "sentence-transformers",
    n_works = 10, n_dimensions = ncol(c1$embeddings)
  )
  expect_warning(bound <- sm_bind_corpora(c1, c2),
                 class = "scimapR_bind_embeddings_dropped")
  expect_null(bound$embeddings)
  expect_null(bound$metadata$embedding)
})

.split_identity_wos <- function(sizes, envir = parent.frame()) {
  path <- testthat::test_path("fixtures", "realuse-wos-sample.txt")
  lines <- readLines(path, warn = FALSE)
  ends <- which(lines == "ER")
  starts <- c(which(grepl("^PT ", lines))[1], head(ends, -1L) + 1L)
  records <- Map(function(a, b) lines[seq.int(a, b)], starts, ends)
  groups <- split(seq_along(records), rep(seq_along(sizes), sizes))
  vapply(groups, function(idx) {
    path <- withr::local_tempfile(fileext = ".txt", .local_envir = envir)
    writeLines(c(lines[seq_len(starts[1] - 1L)],
                 unlist(records[idx], use.names = FALSE), "EF"), path)
    path
  }, character(1))
}

test_that("split exports retain each work's authors and source", {
  paths <- .split_identity_wos(c(5L, 5L))
  parts <- lapply(paths, sm_read_wos, verbose = FALSE)
  whole <- sm_read_wos(realuse_wos_sample(), verbose = FALSE)
  expect_message(bound <- sm_build_corpus(parts[[1]], parts[[2]],
                                          dedupe = FALSE),
                 class = "scimapR_bind_rekeyed")
  expect_equal(length(unique(bound$works$work_id)), 10L)
  expect_equal(nrow(sm_validate(bound)), 0L)
  authors_for <- function(x, id) {
    ids <- x$authorships$author_id[x$authorships$work_id == id]
    sort(x$authors$display_name[match(unique(ids), x$authors$author_id)])
  }
  for (i in seq_len(nrow(whole$works))) {
    j <- match(whole$works$doi[i], bound$works$doi)
    expect_identical(authors_for(bound, bound$works$work_id[j]),
                     authors_for(whole, whole$works$work_id[i]))
    expect_identical(
      bound$sources$display_name[match(bound$works$source_id[j],
                                       bound$sources$source_id)],
      whole$sources$display_name[match(whole$works$source_id[i],
                                       whole$sources$source_id)]
    )
  }
  paths <- .split_identity_wos(c(4L, 3L, 3L))
  three <- sm_build_corpus(paths[1], paths[2], paths[3], verbose = FALSE)
  expect_equal(nrow(three$works), 10L)
  expect_equal(length(unique(three$works$work_id)), 10L)
})

test_that("binding rewrites all local links and reserves external IDs", {
  x <- sm_example_corpus(n_works = 3, n_authors = 2, seed = 1)
  y <- x
  y$authors$display_name[1] <- "Mira Example"
  y$sources$display_name[1] <- "Another Journal"
  y$institutions$display_name[1] <- "Example Institute"
  y$references <- tibble::tibble(
    work_id = y$works$work_id[1], ref_index = 1:2,
    cited_work_id = c(y$works$work_id[2], "W000000099")
  )
  y$citations_by_year <- tibble::tibble(
    work_id = y$works$work_id[1], year = 2024L, cited_by_count = 2L
  )
  bound <- sm_bind_corpora(x, y, verbose = FALSE)
  new_ids <- bound$works$work_id[4:6]
  expect_identical(new_ids, sprintf("W%09d", 100:102))
  expect_identical(tail(bound$references$cited_work_id, 2),
                   c(new_ids[2], "W000000099"))
  expect_identical(bound$citations_by_year$work_id, new_ids[1])
  expect_identical(rownames(bound$embeddings), bound$works$work_id)
  for (table in c("authorships", "concepts", "provenance", "screening")) {
    expect_true(all(bound[[table]]$work_id %in% bound$works$work_id))
  }
  new_author <- tail(bound$authorships$author_id, nrow(y$authorships))
  names_after <- bound$authors$display_name[
    match(new_author, bound$authors$author_id)
  ]
  names_before <- y$authors$display_name[
    match(y$authorships$author_id, y$authors$author_id)
  ]
  expect_identical(names_after, names_before)
  expect_false(anyDuplicated(bound$works$work_id) > 0L)
})

test_that("binding shares only identical lookup records", {
  x <- sm_example_corpus(n_works = 5, n_authors = 3,
                         with_embeddings = FALSE, seed = 1)
  y <- x
  x$authors$alternatives <- rep(list(c("A", "B")), nrow(x$authors))
  y$authors$alternatives <- x$authors$alternatives
  y$authors$alternatives[[1]] <- c("B", "A")
  y$authors$extra <- "right only"
  bound <- sm_bind_corpora(x, y, verbose = FALSE)
  expect_equal(nrow(bound$authors), nrow(x$authors) + 1L)
  expect_identical(bound$sources, x$sources)
  expect_identical(bound$institutions, x$institutions)
  y$authors <- y$authors[-1, ]
  orphan <- sm_bind_corpora(x, y, verbose = FALSE)
  right_ids <- tail(orphan$authorships$author_id, nrow(y$authorships))
  expect_false(x$authors$author_id[1] %in% right_ids)
})

test_that("binding re-keys institutions and orphan IDs without false links", {
  x <- sm_corpus(
    works = tibble::tibble(work_id = "W1", source_id = "S1"),
    authors = tibble::tibble(author_id = "A1", display_name = "Ada Example"),
    authorships = tibble::tibble(work_id = "W1", author_id = "A1",
                                 institution_id = "I1"),
    institutions = tibble::tibble(institution_id = "I1",
                                  display_name = "North"),
    sources = tibble::tibble(source_id = "S1", display_name = "Journal North")
  )
  y <- x
  y$institutions$display_name <- "South"
  y$sources <- y$sources[integer(), ]
  y$authorships <- dplyr::bind_rows(y$authorships, tibble::tibble(
    work_id = "W000000100", author_id = "A000000100", institution_id = "I2"
  ))
  y$screening <- tibble::tibble(work_id = "W1", decision = "include")
  out <- sm_bind_corpora(x, y, verbose = FALSE)
  expect_identical(out$works$work_id, c("W1", "W000000101"))
  expect_identical(out$institutions$institution_id, c("I1", "I000000003"))
  expect_identical(out$authorships$institution_id, c("I1", "I000000003", "I2"))
  expect_identical(out$screening$work_id, "W000000101")
  expect_false(out$works$source_id[2] %in% out$sources$source_id)
  expect_identical(out$authorships$work_id[3], "W000000100")
})

test_that("binding embeddings uses unique IDs and warns for different widths", {
  x <- sm_example_corpus(n_works = 10, n_authors = 5, seed = 1)
  y <- sm_example_corpus(n_works = 10, n_authors = 5, seed = 2)
  bound <- sm_bind_corpora(x, y, verbose = FALSE)
  expect_identical(rownames(bound$embeddings), bound$works$work_id)
  expect_equal(length(unique(rownames(bound$embeddings))), 20L)
  y$embeddings <- y$embeddings[, 1:3, drop = FALSE]
  expect_warning(bound <- sm_bind_corpora(x, y, verbose = FALSE),
                 "widths differ", class = "scimapR_bind_embeddings_dropped")
  expect_null(bound$embeddings)
})

test_that("ID helpers reserve both inputs and preserve missing values", {
  expect_identical(.next_ids("W", 2L, c("W9999999999", "other", NA)),
                   c("W10000000000", "W10000000001"))
  expect_identical(.next_ids("A", 0L, "A000000001"), character())
  map <- .rekey_map(c("W1", "W1", "W3", NA), c("W1", "W2"), "W")
  expect_identical(map, c(W1 = "W000000004"))
  expect_identical(.apply_id_map(c("W1", "W3", NA), map),
                   c("W000000004", "W3", NA))
  expect_identical(.rekey_map("A1", "A1", "A", keep = "A1"),
                   stats::setNames(character(), character()))
})

test_that("deduplication of bound copies keeps only the retained children", {
  x <- sm_example_corpus(n_works = 20, n_authors = 10,
                         with_embeddings = FALSE, seed = 1)
  out <- sm_build_corpus(x, x[1:5], verbose = FALSE)
  expect_identical(out$works$work_id, x$works$work_id)
  expect_identical(out$authorships, x$authorships)
  retained_authors <- x$authors$author_id %in% x$authorships$author_id
  expect_identical(out$authors, x$authors[retained_authors, ])
  expect_identical(out$sources,
                   x$sources[x$sources$source_id %in% x$works$source_id, ])
  inputs <- list(sm_read_bib(sm_example_files("example.bib"), verbose = FALSE),
                 sm_read_ris(sm_example_files("example.ris"), verbose = FALSE))
  built <- sm_build_corpus(inputs[[1]], inputs[[2]], verbose = FALSE)
  for (i in seq_len(nrow(built$works))) {
    row <- built$works[i, ]
    input <- if (row$work_id %in% inputs[[1]]$works$work_id) {
      inputs[[1]]
    } else {
      inputs[[2]]
    }
    id <- input$works$work_id[match(row$doi, input$works$doi)]
    for (table in c("authorships", "concepts", "provenance")) {
      expect_equal(sum(built[[table]]$work_id == row$work_id),
                   sum(input[[table]]$work_id == id))
    }
  }
})

test_that("deduplication normalises composite keys and preserves input order", {
  x <- sm_example_corpus(n_works = 6, n_authors = 4, seed = 1)
  x$works$doi <- c(NA, "10.9999/ABC", "https://doi.org/10.9999/abc", "", NA, "")
  x$works$abstract[2] <- NA_character_
  out <- sm_dedupe(x, verbose = FALSE)
  expect_identical(out$works$work_id, x$works$work_id[-2])
  expect_identical(.dedupe_works(x$works, "doi")$map,
                   stats::setNames(x$works$work_id[3], x$works$work_id[2]))
  for (table in c("authorships", "concepts", "provenance", "references")) {
    expect_false(x$works$work_id[2] %in% out[[table]]$work_id)
  }
  expect_identical(rownames(out$embeddings), out$works$work_id)
  x$works$doi <- NA_character_
  x$works$pmid <- c("1", "1", "", "", NA, NA)
  expect_identical(sm_dedupe(x, by = "pmid", verbose = FALSE)$works$work_id,
                   x$works$work_id[-2])
  x$works$title[1:2] <- c("A study", " a   STUDY ")
  x$works$year[1:2] <- 2020L
  out <- sm_dedupe(x, by = c("title", "year"), verbose = FALSE)
  expect_equal(nrow(out$works), 5L)
  expect_error(sm_dedupe(x, by = "absent"),
               class = "scimapR_dedupe_unknown_column")
  expect_error(sm_dedupe(x, by = character()), "non-empty")
})

test_that("deduplication keeps one embedding row per retained work", {
  x <- sm_example_corpus(n_works = 50, seed = 1)
  y <- sm_example_corpus(n_works = 50, seed = 2)
  out <- sm_build_corpus(x, y, verbose = FALSE)
  expect_equal(nrow(out$embeddings), 50L)
  expect_identical(rownames(out$embeddings), out$works$work_id)
  x$embeddings <- rbind(x$embeddings[1, , drop = FALSE], x$embeddings)
  expect_warning(out <- sm_dedupe(x, verbose = FALSE),
                 class = "scimapR_duplicate_embedding_rows")
  expect_identical(rownames(out$embeddings), x$works$work_id)
  expect_identical(out$embeddings[1, ], x$embeddings[1, ])
})

test_that("sm_build_corpus passes mix_models on to sm_bind_corpora", {
  c1 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 1)
  c2 <- sm_example_corpus(n_works = 10, n_authors = 5,
                          with_embeddings = TRUE, seed = 2)
  c1$metadata$embedding <- .new_embedding_record(
    "mpnet", "mpnet", "sentence-transformers",
    n_works = nrow(c1$embeddings), n_dimensions = ncol(c1$embeddings)
  )

  # a recorded and an unrecorded model stop the build, and the hint names
  # an argument that sm_build_corpus() has
  expect_error(sm_build_corpus(c1, c2, dedupe = FALSE, verbose = FALSE),
               "mix_models = TRUE",
               class = "scimapR_embedding_model_mismatch")
  built <- sm_build_corpus(c1, c2, dedupe = FALSE, mix_models = TRUE,
                           verbose = FALSE)
  expect_identical(nrow(built$embeddings), 20L)
  expect_identical(built$metadata$embedding$model_id, "mixed")
  expect_identical(built$metadata$embedding$models, c("mpnet", "unknown"))
  expect_error(sm_build_corpus(c1, c2, mix_models = NA, verbose = FALSE),
               "mix_models")
})

test_that("sm_bind_corpora keeps the local inputs of both corpora", {
  withr::local_dir(withr::local_tempdir())
  writeLines("a", "a.csv")
  writeLines("b", "b.csv")
  c1 <- sm_example_corpus(n_works = 3, n_authors = 2, seed = 1)
  c2 <- sm_example_corpus(n_works = 3, n_authors = 2, seed = 2)
  with_a <- sm_register_input(c1, "a.csv")
  with_ab <- sm_register_input(sm_register_input(c2, "a.csv"), "b.csv")

  bound <- sm_bind_corpora(with_a, with_ab)
  expect_identical(bound$metadata$local_inputs$path, c("a.csv", "b.csv"))
  expect_identical(sm_bind_corpora(c1, with_ab)$metadata$local_inputs$path,
                   c("a.csv", "b.csv"))
  expect_null(sm_bind_corpora(c1, c2)$metadata$local_inputs)

  # the same file with other content is a different input
  writeLines("a changed", "a.csv")
  changed <- sm_register_input(c2, "a.csv")
  bound <- sm_bind_corpora(with_a, changed)
  expect_identical(bound$metadata$local_inputs$path, c("a.csv", "a.csv"))
})

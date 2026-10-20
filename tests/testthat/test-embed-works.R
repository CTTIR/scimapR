# Offline tests mock reticulate, or the one Python step of the adapter
# path (.embed_specter2()), so no Python, model or network is touched. The
# live smoke tests at the end download models and run only when
# SCIMAPR_LIVE_PYTHON_TESTS is "true" (see tests/README.md).

# Mock a Python that has every module except `missing`; `st` stands for
# the sentence_transformers module (an R list with SentenceTransformer).
local_fake_python <- function(st = fake_st(), missing = character(),
                              env = parent.frame()) {
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(module) !module %in% missing,
    import = function(module, ...) st,
    py_to_r = function(x) x,
    .package = "reticulate", .env = env
  )
}

# A fake sentence_transformers module whose encoder returns `dims` columns
fake_st <- function(dims = 8L, version = NULL) {
  encoder <- list(
    encode = function(texts, batch_size, show_progress_bar,
                      convert_to_numpy) {
      matrix(seq_len(length(texts) * dims) / 100, nrow = length(texts),
             ncol = dims)
    }
  )
  st <- list(SentenceTransformer = function(model_name, cache_folder) encoder)
  if (!is.null(version)) st[["__version__"]] <- version
  st
}

test_that("sm_embed_works rejects non-corpus input", {
  expect_error(sm_embed_works(list(a = 1)), "sm_corpus")
})

test_that("sm_embed_works validates model, text, and batch_size", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 1)
  expect_error(sm_embed_works(corpus, model = "bogus"))
  expect_error(sm_embed_works(corpus, text = "bogus"))
  expect_error(sm_embed_works(corpus, batch_size = 0), "positive integer")
})

test_that("sm_embed_works returns NULL embeddings for empty corpus", {
  corpus <- make_empty_corpus()
  corpus$metadata$embedding <- list(model_id = "a stale record")
  out <- sm_embed_works(corpus)
  expect_s3_class(out, "sm_corpus")
  expect_null(out$embeddings)
  expect_null(out$metadata$embedding)
})

test_that("sm_embed_works errors when reticulate not installed", {
  corpus <- sm_example_corpus(n_works = 10, with_embeddings = FALSE, seed = 2)
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "reticulate") stop("reticulate not installed")
      invisible(NULL)
    },
    .package = "rlang"
  )
  expect_error(sm_embed_works(corpus), "reticulate")
})

test_that("sm_embed_works errors when Python is unavailable", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 3)
  testthat::local_mocked_bindings(
    py_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(sm_embed_works(corpus, verbose = FALSE), "Python is not available")
})

test_that("sm_embed_works errors when sentence-transformers missing", {
  skip_if_not_installed("reticulate")
  # model = "mpnet": the default specter2 needs adapters instead (below)
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(sm_embed_works(corpus, model = "mpnet", verbose = FALSE),
               "sentence-transformers")
})

test_that("sm_embed_works errors when adapters missing for specter2", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(sm_embed_works(corpus, verbose = FALSE), "adapters",
               class = "scimapR_embed_python_missing")
})

test_that("specter2 names the one module it misses", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(module) !identical(module, "torch"),
    import = function(module, ...) stop("unexpected import of ", module),
    .package = "reticulate"
  )
  err <- expect_error(
    sm_embed_works(corpus, model = "specter2", verbose = FALSE),
    class = "scimapR_embed_python_missing"
  )
  expect_match(conditionMessage(err), "Python package torch is not")
})

test_that("install_deps installs what the chosen model needs", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 4, with_embeddings = FALSE, seed = 4)
  installed <- list()
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_install = function(packages, ...) {
      installed[[length(installed) + 1L]] <<- packages
      invisible(NULL)
    },
    py_module_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(
    sm_embed_works(corpus, model = "specter2", install_deps = TRUE,
                   verbose = FALSE),
    class = "scimapR_embed_python_missing"
  )
  expect_error(
    sm_embed_works(corpus, model = "mpnet", install_deps = TRUE,
                   verbose = FALSE),
    class = "scimapR_embed_python_missing"
  )
  expect_identical(installed,
                   list(c("torch", "adapters"), "sentence-transformers"))
})

test_that("sm_embed_works computes embeddings via a mocked encoder", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 12, with_embeddings = FALSE, seed = 5)
  n <- nrow(corpus$works)
  fake_encoder <- list(
    encode = function(texts, batch_size, show_progress_bar, convert_to_numpy) {
      # deterministic fake embedding matrix (n x 8)
      matrix(seq_len(length(texts) * 8) / 100, nrow = length(texts), ncol = 8)
    }
  )
  fake_st <- list(
    SentenceTransformer = function(model_name, cache_folder) fake_encoder
  )
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(...) TRUE,
    import = function(...) fake_st,
    py_to_r = function(x) x,
    .package = "reticulate"
  )
  out <- sm_embed_works(corpus, model = "minilm-l6", verbose = FALSE,
                        cache_dir = withr::local_tempdir())
  expect_s3_class(out, "sm_corpus")
  expect_true(is.matrix(out$embeddings))
  expect_equal(nrow(out$embeddings), n)
  expect_equal(ncol(out$embeddings), 8L)
  expect_equal(rownames(out$embeddings), corpus$works$work_id)
})

test_that("sm_embed_works coerces a non-matrix encoder result", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 6, with_embeddings = FALSE, seed = 6)
  fake_encoder <- list(
    encode = function(texts, ...) {
      # return a data.frame to force as.matrix coercion
      as.data.frame(matrix(1, nrow = length(texts), ncol = 4))
    }
  )
  fake_st <- list(
    SentenceTransformer = function(model_name, cache_folder) fake_encoder
  )
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(...) TRUE,
    import = function(...) fake_st,
    py_to_r = function(x) x,
    .package = "reticulate"
  )
  # the sentence-transformers path (specter2 now loads with adapters)
  out <- sm_embed_works(corpus, model = "mpnet", verbose = FALSE,
                        cache_dir = withr::local_tempdir())
  expect_true(is.matrix(out$embeddings))
  expect_equal(nrow(out$embeddings), nrow(corpus$works))
})

test_that("sm_embed_works verbose = TRUE prints progress messages", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE, seed = 7)
  fake_encoder <- list(
    encode = function(texts, ...) matrix(0, nrow = length(texts), ncol = 3)
  )
  fake_st <- list(
    SentenceTransformer = function(model_name, cache_folder) fake_encoder
  )
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(...) TRUE,
    import = function(...) fake_st,
    py_to_r = function(x) x,
    .package = "reticulate"
  )
  expect_message(
    sm_embed_works(corpus, model = "mpnet", verbose = TRUE,
                   cache_dir = withr::local_tempdir()),
    "Computing embeddings"
  )
})

test_that(".embed_model_name maps all short names", {
  expect_identical(
    .embed_model_name("multilingual-mpnet"),
    "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
  )
  expect_identical(.embed_model_name("multilingual-e5"),
                   "intfloat/multilingual-e5-base")
  expect_equal(.embed_model_name("specter2"), "allenai/specter2")
  expect_equal(.embed_model_name("scincl"), "malteos/scincl")
  expect_equal(.embed_model_name("scibert"),
               "allenai/scibert_scivocab_uncased")
  expect_equal(.embed_model_name("minilm-l6"),
               "sentence-transformers/all-MiniLM-L6-v2")
  expect_equal(.embed_model_name("mpnet"),
               "sentence-transformers/all-mpnet-base-v2")
})

test_that(".embed_prepare_texts builds expected text fields", {
  works <- tibble::tibble(
    work_id = c("W1", "W2"),
    title = c("Title A", NA_character_),
    abstract = c("Abstract A", "Abstract B")
  )
  ta <- .embed_prepare_texts(works, "title_abstract")
  expect_equal(ta[1], "Title A Abstract A")
  expect_equal(ta[2], " Abstract B")

  ti <- .embed_prepare_texts(works, "title")
  expect_equal(ti, c("Title A", ""))

  ab <- .embed_prepare_texts(works, "abstract")
  expect_equal(ab, c("Abstract A", "Abstract B"))
})

test_that(".embed_prepare_texts adds the separator or prefix of a model", {
  works <- tibble::tibble(
    work_id = c("W1", "W2", "W3"),
    title = c("Title A", NA_character_, "Title C"),
    abstract = c("Abstract A", "Abstract B", NA_character_)
  )
  # specter2: title [SEP] abstract without spaces, as the model card does
  expect_identical(
    .embed_prepare_texts(works, "title_abstract", model = "specter2"),
    c("Title A[SEP]Abstract A", "[SEP]Abstract B", "Title C[SEP]")
  )
  expect_identical(.embed_prepare_texts(works, "title", model = "specter2"),
                   c("Title A", "", "Title C"))
  # e5: the "query: " prefix, whatever the text
  expect_identical(
    .embed_prepare_texts(works, "title_abstract", model = "multilingual-e5"),
    c("query: Title A Abstract A", "query:  Abstract B", "query: Title C ")
  )
  expect_identical(
    .embed_prepare_texts(works, "abstract", model = "multilingual-e5"),
    c("query: Abstract A", "query: Abstract B", "query: ")
  )
  # other models: as without a model
  expect_identical(
    .embed_prepare_texts(works, "title_abstract", model = "mpnet"),
    .embed_prepare_texts(works, "title_abstract")
  )
})

test_that("specter2 takes the adapters path, not sentence-transformers", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE, seed = 8)
  # Python has adapters but no sentence_transformers; nothing is imported
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(module) {
      !identical(module, "sentence_transformers")
    },
    import = function(module, ...) stop("unexpected import of ", module),
    .package = "reticulate"
  )
  seen <- new.env()
  testthat::local_mocked_bindings(
    .embed_specter2 = function(texts, batch_size, cache_dir, call) {
      seen$texts <- texts
      seen$batch_size <- batch_size
      list(embeddings = matrix(0.5, nrow = length(texts), ncol = 6),
           versions = list(adapters = "1.2.0", transformers = "4.51.3",
                           torch = "2.7.0"))
    }
  )
  out <- sm_embed_works(corpus, model = "specter2", batch_size = 4L,
                        verbose = FALSE, cache_dir = withr::local_tempdir())
  expect_identical(dim(out$embeddings), c(5L, 6L))
  expect_identical(rownames(out$embeddings), corpus$works$work_id)
  expect_true(all(grepl("[SEP]", seen$texts, fixed = TRUE)))
  expect_identical(seen$batch_size, 4L)
  rec <- out$metadata$embedding
  expect_identical(rec$model, "specter2")
  expect_identical(rec$model_id, "allenai/specter2")
  expect_identical(rec$base_model_id, "allenai/specter2_base")
  expect_identical(rec$backend, "adapters")
  expect_identical(rec$versions$adapters, "1.2.0")
  expect_identical(rec$prefix, "")
})

test_that("the language check fires for English-only models only", {
  works <- realuse_corpus()$works
  german <- sum(works$language == "German")
  check <- .embed_language_check(works$language, "mpnet")
  expect_type(check, "list")
  expect_identical(check$n_known, nrow(works))
  expect_identical(check$n_other, german)
  expect_identical(check$languages, "de")
  # the same corpus with ISO 639-1 codes, as OpenAlex writes them
  iso <- unname(c(English = "en", German = "de")[works$language])
  expect_identical(.embed_language_check(iso, "mpnet")$n_other, german)
  expect_type(.embed_language_check(works$language, "specter2"), "list")
  expect_null(.embed_language_check(works$language, "multilingual-mpnet"))
  expect_null(.embed_language_check(works$language, "multilingual-e5"))
  # at most 10% not in English, or no known language: no note
  expect_null(.embed_language_check(c(rep("English", 9), "German"), "mpnet"))
  expect_null(.embed_language_check(c(NA, "", "und"), "mpnet"))
  expect_null(.embed_language_check(NULL, "mpnet"))
  # ISO 639-2 codes, as PubMed writes them
  expect_identical(
    .embed_language_check(c(rep("eng", 8), "ger", "deu"), "mpnet")$n_other,
    2L
  )
})

test_that("sm_embed_works informs when a multilingual corpus meets mpnet", {
  skip_if_not_installed("reticulate")
  corpus <- realuse_corpus()
  local_fake_python()
  expect_message(
    out <- sm_embed_works(corpus, model = "mpnet", verbose = FALSE,
                          cache_dir = withr::local_tempdir()),
    class = "scimapR_embed_multilingual"
  )
  # a message only: every work is embedded as before
  expect_identical(rownames(out$embeddings), corpus$works$work_id)
  expect_no_message(
    sm_embed_works(corpus, model = "multilingual-mpnet", verbose = FALSE,
                   cache_dir = withr::local_tempdir()),
    class = "scimapR_embed_multilingual"
  )
})

test_that("works without text are left out of the embeddings", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 6, with_embeddings = FALSE, seed = 9)
  corpus$works$title[2] <- NA_character_
  corpus$works$abstract[2] <- "  "
  corpus$works$abstract[c(4, 5)] <- NA_character_
  ids <- corpus$works$work_id
  n_texts <- integer()
  st <- list(SentenceTransformer = function(model_name, cache_folder) {
    list(encode = function(texts, ...) {
      n_texts <<- c(n_texts, length(texts))
      matrix(1, nrow = length(texts), ncol = 3)
    })
  })
  local_fake_python(st)

  # title_abstract: one work has neither a title nor an abstract
  expect_warning(
    out <- sm_embed_works(corpus, model = "mpnet", verbose = FALSE,
                          cache_dir = withr::local_tempdir()),
    "^1 work without a title or an abstract is left out",
    class = "scimapR_embed_no_text"
  )
  expect_identical(rownames(out$embeddings), ids[-2])
  expect_identical(nrow(out$works), 6L)
  expect_identical(out$metadata$embedding$n_works, 5L)

  # abstract: three works have none (blank text counts as none)
  expect_warning(
    out <- sm_embed_works(corpus, model = "mpnet", text = "abstract",
                          verbose = FALSE,
                          cache_dir = withr::local_tempdir()),
    "^3 works without an abstract are left out",
    class = "scimapR_embed_no_text"
  )
  expect_identical(rownames(out$embeddings), ids[-c(2, 4, 5)])
  expect_identical(n_texts, c(5L, 3L))

  # no work has text: nothing to embed, and the corpus is left as it was
  corpus$works$abstract <- NA_character_
  expect_error(
    sm_embed_works(corpus, model = "mpnet", text = "abstract",
                   verbose = FALSE),
    class = "scimapR_embed_nothing"
  )
})

test_that("works without text get no cluster downstream", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 30, with_embeddings = FALSE,
                              seed = 13)
  corpus$works$title[1:3] <- NA_character_
  corpus$works$abstract[1:3] <- NA_character_
  st <- list(SentenceTransformer = function(model_name, cache_folder) {
    list(encode = function(texts, ...) {
      matrix(stats::rnorm(length(texts) * 4), nrow = length(texts))
    })
  })
  local_fake_python(st)
  set.seed(1)
  out <- suppressWarnings(
    sm_embed_works(corpus, model = "mpnet", verbose = FALSE,
                   cache_dir = withr::local_tempdir())
  )
  clustered <- suppressMessages(sm_cluster_kmeans(out, k = 2, reducer = "pca"))
  expect_identical(nrow(clustered$works), 30L)
  expect_true(all(is.na(clustered$works$cluster_id[1:3])))
  expect_false(anyNA(clustered$works$cluster_id[-(1:3)]))
})

test_that("a corpus with a single work gets a one-row matrix", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE,
                              seed = 10)[1]
  received <- NULL
  st <- list(SentenceTransformer = function(model_name, cache_folder) {
    list(encode = function(texts, batch_size, show_progress_bar,
                           convert_to_numpy) {
      received <<- texts
      # what encode() gives for a single string: a 1-D array
      seq_len(8) / 10
    })
  })
  local_fake_python(st)
  out <- sm_embed_works(corpus, model = "mpnet", verbose = FALSE,
                        cache_dir = withr::local_tempdir())
  # the text reaches Python as a list of one string, not as a string
  expect_type(received, "list")
  expect_length(received, 1L)
  expect_identical(dim(out$embeddings), c(1L, 8L))
  expect_identical(rownames(out$embeddings), corpus$works$work_id)
})

test_that(".embed_as_matrix gives one row per text", {
  expect_identical(dim(.embed_as_matrix(seq_len(4) / 2, 1L)), c(1L, 4L))
  expect_identical(dim(.embed_as_matrix(array(1:6), 1L)), c(1L, 6L))
  m <- .embed_as_matrix(as.data.frame(matrix(1L, nrow = 2, ncol = 3)), 2L)
  expect_true(is.matrix(m) && is.double(m))
  expect_error(.embed_as_matrix(matrix(1, nrow = 2, ncol = 3), 3L),
               "2 embeddings for 3 texts")
})

test_that("the record of the model reaches the certificate", {
  skip_if_not_installed("reticulate")
  skip_if_not_installed("yaml")
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE,
                              seed = 11)
  cache_dir <- withr::local_tempdir()
  # the local snapshot folder shows the revision of the model
  refs <- file.path(cache_dir, "models--intfloat--multilingual-e5-base",
                    "refs")
  dir.create(refs, recursive = TRUE)
  writeLines("0123abcd", file.path(refs, "main"))
  local_fake_python(fake_st(version = "3.4.1"))
  out <- sm_embed_works(corpus, model = "multilingual-e5", verbose = FALSE,
                        cache_dir = cache_dir)

  rec <- out$metadata$embedding
  expect_identical(rec$model, "multilingual-e5")
  expect_identical(rec$model_id, "intfloat/multilingual-e5-base")
  expect_identical(rec$revision, "0123abcd")
  expect_identical(rec$base_model_id, NA_character_)
  expect_identical(rec$backend, "sentence-transformers")
  expect_identical(rec$text, "title_abstract")
  expect_identical(rec$prefix, "query: ")
  expect_identical(rec$versions, list(sentence_transformers = "3.4.1"))
  expect_identical(c(rec$n_works, rec$n_dimensions), c(8L, 8L))
  expect_s3_class(rec$created, "POSIXct")
  expect_identical(attr(rec$created, "tzone"), "UTC")
  # metadata, not provenance: a rebuild never replays an embedding step
  expect_identical(out$provenance, corpus$provenance)

  cert <- suppressMessages(sm_certificate(out))
  info <- cert$embedding_info
  expect_identical(info$model_id, "intfloat/multilingual-e5-base")
  expect_identical(info$revision, "0123abcd")
  expect_identical(info$text, "title_abstract")
  expect_identical(info$method, "sentence-transformers")
  expect_identical(c(info$n_works, info$n_dimensions), c(8L, 8L))
  expect_match(paste(cli::cli_fmt(print(cert)), collapse = "\n"),
               "intfloat/multilingual-e5-base", fixed = TRUE)
})

test_that("a model that does not load stops with its id and the error", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 4, with_embeddings = FALSE,
                              seed = 12)
  st <- list(SentenceTransformer = function(model_name, cache_folder) {
    stop("TypeError: The config is missing required keys: {'peft_type'}")
  })
  local_fake_python(st)
  err <- expect_error(
    sm_embed_works(corpus, model = "scibert", verbose = FALSE,
                   cache_dir = withr::local_tempdir()),
    class = "scimapR_embed_model_load"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "allenai/scibert_scivocab_uncased", fixed = TRUE)
  expect_match(msg, "model = \"scibert\"", fixed = TRUE)
  expect_match(msg, "{'peft_type'}", fixed = TRUE)
  expect_null(corpus$embeddings)
})

test_that("sm_embed_works says when it replaces existing embeddings", {
  skip_if_not_installed("reticulate")
  corpus <- sm_example_corpus(n_works = 6, with_embeddings = TRUE, seed = 14)
  local_fake_python()
  msgs <- testthat::capture_messages(
    sm_embed_works(corpus, model = "mpnet", verbose = TRUE,
                   cache_dir = withr::local_tempdir())
  )
  expect_match(msgs, "Replacing the existing embeddings whose model is not",
               all = FALSE)
})

# --- live smoke tests: opt-in, they download models ----------------------

test_that("live: specter2 embeds three texts in 768 dimensions", {
  skip_if_not(identical(Sys.getenv("SCIMAPR_LIVE_PYTHON_TESTS"), "true"),
              "SCIMAPR_LIVE_PYTHON_TESTS is not \"true\"")
  skip_on_cran()
  skip_if_offline()
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::py_module_available("adapters"),
              "the Python package adapters is not installed")
  corpus <- sm_example_corpus(n_works = 3, with_embeddings = FALSE, seed = 1)
  out <- sm_embed_works(corpus, model = "specter2", verbose = FALSE)
  expect_identical(dim(out$embeddings), c(3L, 768L))
  expect_identical(out$metadata$embedding$backend, "adapters")
})

test_that("live: multilingual-mpnet embeds three texts in 768 dimensions", {
  skip_if_not(identical(Sys.getenv("SCIMAPR_LIVE_PYTHON_TESTS"), "true"),
              "SCIMAPR_LIVE_PYTHON_TESTS is not \"true\"")
  skip_on_cran()
  skip_if_offline()
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::py_module_available("sentence_transformers"),
              "the Python package sentence-transformers is not installed")
  corpus <- sm_example_corpus(n_works = 3, with_embeddings = FALSE, seed = 1)
  out <- sm_embed_works(corpus, model = "multilingual-mpnet",
                        verbose = FALSE)
  expect_identical(dim(out$embeddings), c(3L, 768L))
  expect_identical(out$metadata$embedding$model_id,
                   .embed_model_name("multilingual-mpnet"))
})

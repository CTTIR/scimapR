# All tests MOCK reticulate; no Python/model/network is ever touched.

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
  out <- sm_embed_works(corpus)
  expect_s3_class(out, "sm_corpus")
  expect_null(out$embeddings)
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
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 3)
  testthat::local_mocked_bindings(
    py_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(sm_embed_works(corpus, verbose = FALSE), "Python is not available")
})

test_that("sm_embed_works errors when sentence-transformers missing", {
  corpus <- sm_example_corpus(n_works = 8, with_embeddings = FALSE, seed = 4)
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(...) FALSE,
    .package = "reticulate"
  )
  expect_error(sm_embed_works(corpus, verbose = FALSE),
               "sentence-transformers")
})

test_that("sm_embed_works computes embeddings via a mocked encoder", {
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
  out <- sm_embed_works(corpus, model = "specter2", verbose = FALSE,
                        cache_dir = withr::local_tempdir())
  expect_true(is.matrix(out$embeddings))
  expect_equal(nrow(out$embeddings), nrow(corpus$works))
})

test_that("sm_embed_works verbose = TRUE prints progress messages", {
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

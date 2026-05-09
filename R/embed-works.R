#' Compute work embeddings using transformer models
#'
#' @description
#' Generates dense vector embeddings for works in an `sm_corpus` using
#' pretrained transformer models via Python's `sentence-transformers` library.
#' Requires \pkg{reticulate} and a working Python installation with
#' `sentence-transformers` installed.
#'
#' @param corpus An [sm_corpus] object.
#' @param model Character; the embedding model to use. One of `"specter2"`
#'   (default, optimised for scientific text), `"scincl"`, `"scibert"`,
#'   `"minilm-l6"`, or `"mpnet"`.
#' @param text Character; which text field(s) to embed. One of
#'   `"title_abstract"` (default, concatenates title and abstract),
#'   `"title"`, or `"abstract"`.
#' @param batch_size Integer; batch size for the transformer model. Defaults
#'   to `32L`.
#' @param cache_dir Character; directory to cache downloaded models. Defaults
#'   to the scimapR user cache directory.
#' @param python Character or `NULL`; path to the Python executable. If `NULL`,
#'   uses \pkg{reticulate}'s default Python.
#' @param install_deps Logical; if `TRUE`, attempt to install
#'   `sentence-transformers` into the Python environment. Defaults to `FALSE`.
#' @param verbose Logical; if `TRUE`, print progress messages.
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` with `corpus$embeddings` replaced by a numeric
#'   matrix of shape `(n_works, embedding_dim)`. Row names are set to
#'   `work_id`.
#'
#' @details
#' Model name mapping:
#' \itemize{
#'   \item `"specter2"` -> `"allenai/specter2"`
#'   \item `"scincl"` -> `"malteos/scincl"`
#'   \item `"scibert"` -> `"allenai/scibert_scivocab_uncased"`
#'   \item `"minilm-l6"` -> `"sentence-transformers/all-MiniLM-L6-v2"`
#'   \item `"mpnet"` -> `"sentence-transformers/all-mpnet-base-v2"`
#' }
#'
#' Python and `sentence-transformers` are soft dependencies (in Suggests).
#' If unavailable, the function aborts with an informative message.
#'
#' @family embedding
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus(with_embeddings = FALSE)
#' corpus <- sm_embed_works(corpus, model = "minilm-l6")
#' dim(corpus$embeddings)
#' }
sm_embed_works <- function(corpus,
                           model = c("specter2", "scincl", "scibert",
                                     "minilm-l6", "mpnet"),
                           text = c("title_abstract", "title", "abstract"),
                           batch_size = 32L,
                           cache_dir = tools::R_user_dir("scimapR", "cache"),
                           python = NULL,
                           install_deps = FALSE,
                           verbose = TRUE,
                           call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  model <- rlang::arg_match(model, error_call = call)
  text <- rlang::arg_match(text, error_call = call)
  batch_size <- .check_positive_int(batch_size, call = call)

  works <- corpus$works

  if (nrow(works) == 0L) {
    corpus$embeddings <- NULL
    return(corpus)
  }

  # --- check Python availability ---
  rlang::check_installed("reticulate",
    reason = "to compute embeddings with sentence-transformers",
    call = call
  )

  if (!is.null(python)) {
    reticulate::use_python(python, required = TRUE)
  }

  if (!reticulate::py_available(initialize = TRUE)) {
    cli::cli_abort(
      c("Python is not available.",
        "i" = "Install Python and the {.pkg sentence-transformers} package.",
        "i" = "Or set {.arg python} to the path of your Python executable."),
      call = call
    )
  }

  if (install_deps) {
    .sm_verbose("Installing sentence-transformers...", verbose)
    reticulate::py_install("sentence-transformers", pip = TRUE)
  }

  if (!reticulate::py_module_available("sentence_transformers")) {
    cli::cli_abort(
      c("Python package {.pkg sentence-transformers} is not installed.",
        "i" = "Run {.code sm_embed_works(corpus, install_deps = TRUE)} to install it.",
        "i" = "Or install manually: {.code pip install sentence-transformers}"),
      call = call
    )
  }

  # --- map model name ---
  model_name <- .embed_model_name(model)

  # --- prepare texts ---
  texts <- .embed_prepare_texts(works, text)

  # --- compute embeddings ---
  .sm_verbose(
    "Computing embeddings with {.val {model}} for {nrow(works)} works...",
    verbose
  )

  st <- reticulate::import("sentence_transformers")

  fs::dir_create(cache_dir)
  encoder <- st$SentenceTransformer(model_name, cache_folder = cache_dir)

  emb_py <- encoder$encode(
    texts,
    batch_size = as.integer(batch_size),
    show_progress_bar = verbose,
    convert_to_numpy = TRUE
  )

  emb <- reticulate::py_to_r(emb_py)
  if (!is.matrix(emb)) {
    emb <- as.matrix(emb)
  }
  rownames(emb) <- works$work_id

  corpus$embeddings <- emb

  .sm_verbose(
    "Embeddings computed: {nrow(emb)} x {ncol(emb)} dimensions.",
    verbose
  )

  corpus
}


#' Map short model name to HuggingFace identifier
#' @noRd
.embed_model_name <- function(model) {
  switch(model,
    specter2  = "allenai/specter2",
    scincl    = "malteos/scincl",
    scibert   = "allenai/scibert_scivocab_uncased",
    `minilm-l6` = "sentence-transformers/all-MiniLM-L6-v2",
    mpnet     = "sentence-transformers/all-mpnet-base-v2"
  )
}


#' Prepare text strings for embedding
#' @noRd
.embed_prepare_texts <- function(works, text) {
  switch(text,
    title_abstract = {
      title <- works$title %||% rep(NA_character_, nrow(works))
      abstract <- works$abstract %||% rep(NA_character_, nrow(works))
      title <- ifelse(is.na(title), "", title)
      abstract <- ifelse(is.na(abstract), "", abstract)
      paste(title, abstract, sep = " ")
    },
    title = {
      title <- works$title %||% rep(NA_character_, nrow(works))
      ifelse(is.na(title), "", title)
    },
    abstract = {
      abstract <- works$abstract %||% rep(NA_character_, nrow(works))
      ifelse(is.na(abstract), "", abstract)
    }
  )
}

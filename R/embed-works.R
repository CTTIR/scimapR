#' Compute work embeddings using transformer models
#'
#' @description
#' Generates dense vector embeddings for works in an `sm_corpus` using
#' pretrained transformer models in Python. The default model, `specter2`,
#' loads the SPECTER2 adapter with the Python package `adapters`; the other
#' models load with `sentence-transformers`. Requires \pkg{reticulate} and
#' a Python installation with the packages the chosen model needs.
#'
#' @param corpus An [sm_corpus] object.
#' @param model Character; the embedding model to use. One of
#'   `"specter2"` (default, optimised for scientific text), `"scincl"`,
#'   `"scibert"`, `"minilm-l6"` and `"mpnet"`, which are trained on English
#'   text, or `"multilingual-mpnet"` and `"multilingual-e5"`, which place
#'   works of many languages in one space. See Details.
#' @param text Character; which text field(s) to embed. One of
#'   `"title_abstract"` (default, title and abstract together), `"title"`,
#'   or `"abstract"`.
#' @param batch_size Integer; batch size for the transformer model. Defaults
#'   to `32L`.
#' @param cache_dir Character; directory to cache downloaded models. Defaults
#'   to the scimapR user cache directory.
#' @param python Character or `NULL`; path to the Python executable. If `NULL`,
#'   uses \pkg{reticulate}'s default Python.
#' @param install_deps Logical; if `TRUE`, install the Python packages the
#'   chosen model needs with pip first: `torch` and `adapters` (which brings
#'   `transformers`) for `"specter2"`, `sentence-transformers` for the other
#'   models. Defaults to `FALSE`.
#' @param verbose Logical; if `TRUE`, print progress messages.
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` with `corpus$embeddings` replaced by a numeric
#'   matrix with one row per embedded work and one column per dimension, and
#'   with `corpus$metadata$embedding` recording the model. Row names are the
#'   `work_id`s of the embedded works: every work that has text to embed
#'   (see Details).
#'
#' @details
#' Models and their Hugging Face models:
#' * `"specter2"`: `allenai/specter2`, an adapter on `allenai/specter2_base`;
#' * `"scincl"`: `malteos/scincl`;
#' * `"scibert"`: `allenai/scibert_scivocab_uncased`;
#' * `"minilm-l6"`: `sentence-transformers/all-MiniLM-L6-v2`;
#' * `"mpnet"`: `sentence-transformers/all-mpnet-base-v2`;
#' * `"multilingual-mpnet"`:
#'   `sentence-transformers/paraphrase-multilingual-mpnet-base-v2`, trained
#'   on more than 50 languages;
#' * `"multilingual-e5"`: `intfloat/multilingual-e5-base`, trained on about
#'   100 languages.
#'
#' The first five are trained on English text. `"specter2"` loads with the
#' Python package `adapters`, the others with `sentence-transformers`.
#'
#' `"specter2"` follows its model card: the base model with the proximity
#' adapter, title and abstract joined by the separator token `[SEP]`
#' without spaces, at most 512 tokens, and the first token of the last
#' layer as the embedding. It needs the Python packages `torch`,
#' `transformers` and `adapters`; the other models need
#' `sentence-transformers`. A missing package stops the function with an
#' error naming it, and so does a model that does not load; it never falls
#' back to another model.
#'
#' The other models join title and abstract with a space. For
#' `"multilingual-e5"` every text starts with `"query: "`, the prefix its
#' model card gives for clustering and for using the embeddings as
#' features; its embeddings have unit length. `"multilingual-mpnet"` reads
#' at most 128 tokens, so it sees the title and the start of a long
#' abstract only. `"scibert"` has no sentence-transformers configuration,
#' so sentence-transformers averages its token vectors, with a warning.
#'
#' When more than 10% of the works with a known language
#' (`works$language`: names such as `"German"`, ISO 639-1 codes such as
#' `"de"` or ISO 639-2 codes such as `"ger"`) are not in English and an
#' English-only model is chosen, a message (class
#' `scimapR_embed_multilingual`) suggests a multilingual model; it changes
#' nothing else.
#'
#' Works without text to embed (with `"title_abstract"` neither a title
#' nor an abstract, with `"title"` or `"abstract"` no such field; blank
#' text counts as none) would all get the same vector and become each
#' other's nearest neighbours. They are left out, with one warning (class
#' `scimapR_embed_no_text`) giving their number: they get no row in
#' `corpus$embeddings`, so the clustering functions give them no cluster
#' (`NA`), and [sm_network_semantic()] and [sm_plot_landscape()] leave
#' them out, as they do for works missing from a cache loaded with
#' [sm_embed_load()].
#'
#' `corpus$metadata$embedding` records what produced the embeddings: the
#' model, its Hugging Face id and, when the local model snapshot in
#' `cache_dir` shows it, its revision, the text used, the input prefix and
#' the versions of the Python packages (see [sm_corpus()]).
#' [sm_certificate()] reports it in `embedding_info`.
#'
#' Python and its packages are soft dependencies (\pkg{reticulate} is in
#' Suggests). If they are unavailable, the function aborts with an
#' informative message.
#'
#' @family embedding
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus(with_embeddings = FALSE)
#' corpus <- sm_embed_works(corpus, model = "minilm-l6")
#' dim(corpus$embeddings)
#' corpus$metadata$embedding$model_id
#'
#' # a corpus with works in several languages
#' corpus <- sm_embed_works(corpus, model = "multilingual-mpnet")
#' }
sm_embed_works <- function(corpus,
                           model = c("specter2", "scincl", "scibert",
                                     "minilm-l6", "mpnet",
                                     "multilingual-mpnet", "multilingual-e5"),
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
    corpus$metadata$embedding <- NULL
    return(corpus)
  }

  # --- checks that need no Python ---
  .embed_inform_language(works[["language"]], model)
  has_text <- .embed_has_text(works, text)
  .embed_warn_no_text(has_text, text, call = call)

  # --- check Python availability ---
  rlang::check_installed("reticulate",
    reason = "to compute embeddings in Python",
    call = call
  )

  if (!is.null(python)) {
    reticulate::use_python(python, required = TRUE)
  }

  if (!reticulate::py_available(initialize = TRUE)) {
    cli::cli_abort(
      c("Python is not available.",
        "i" = "Install Python and the
               {.pkg {unique(.embed_modules(model))}} package{?s}.",
        "i" = "Or set {.arg python} to the path of your Python executable."),
      call = call
    )
  }
  .embed_check_modules(model, install_deps = install_deps,
                       verbose = verbose, call = call)

  # --- prepare texts ---
  texts <- .embed_prepare_texts(works[has_text, , drop = FALSE], text,
                                model = model)

  # --- compute embeddings ---
  if (!is.null(corpus$embeddings) && nrow(corpus$embeddings) > 0L) {
    .sm_verbose(
      "Replacing the existing
       {(.embedding_describe(.embedding_record(corpus)))}
       ({nrow(corpus$embeddings)} x {ncol(corpus$embeddings)}).",
      verbose
    )
  }
  .sm_verbose(
    "Computing embeddings with {.val {model}} for {length(texts)} works...",
    verbose
  )

  fs::dir_create(cache_dir)
  result <- if (.embed_backend(model) == "adapters") {
    .embed_specter2(texts, batch_size = batch_size, cache_dir = cache_dir,
                    call = call)
  } else {
    .embed_sentence_transformers(model, texts, batch_size = batch_size,
                                 cache_dir = cache_dir, verbose = verbose,
                                 call = call)
  }

  emb <- .embed_as_matrix(result$embeddings, length(texts), call = call)
  rownames(emb) <- works$work_id[has_text]

  corpus$embeddings <- emb
  corpus$metadata$embedding <- .embed_works_record(
    model, text, cache_dir = cache_dir, versions = result$versions,
    emb = emb
  )

  .sm_verbose(
    "Embeddings computed: {nrow(emb)} x {ncol(emb)} dimensions.",
    verbose
  )

  corpus
}


#' Hugging Face id of the SPECTER2 base model, on which the adapter loads
#' @noRd
.specter2_base_id <- "allenai/specter2_base"

#' Separator between title and abstract for SPECTER2
#'
#' The `sep_token` of the `allenai/specter2_base` tokenizer
#' (tokenizer_config.json); a constant, so that the texts can be prepared
#' without Python.
#' @noRd
.specter2_sep <- "[SEP]"

#' Input prefix of the e5 models for clustering and features (model card)
#' @noRd
.e5_prefix <- "query: "

#' Models trained on more than English text
#' @noRd
.embed_multilingual_models <- c("multilingual-mpnet", "multilingual-e5")


#' Map short model name to HuggingFace identifier
#'
#' For `"specter2"` the id of the adapter; its base model is
#' `.specter2_base_id`.
#' @noRd
.embed_model_name <- function(model) {
  switch(model,
    specter2  = "allenai/specter2",
    scincl    = "malteos/scincl",
    scibert   = "allenai/scibert_scivocab_uncased",
    `minilm-l6` = "sentence-transformers/all-MiniLM-L6-v2",
    mpnet     = "sentence-transformers/all-mpnet-base-v2",
    `multilingual-mpnet` =
      "sentence-transformers/paraphrase-multilingual-mpnet-base-v2",
    `multilingual-e5` = "intfloat/multilingual-e5-base"
  )
}

#' The Python package that loads a model
#' @noRd
.embed_backend <- function(model) {
  if (identical(model, "specter2")) "adapters" else "sentence-transformers"
}

#' The Python modules a model needs, named by module, valued by pip package
#' @noRd
.embed_modules <- function(model) {
  if (.embed_backend(model) == "adapters") {
    c(torch = "torch", transformers = "transformers", adapters = "adapters")
  } else {
    c(sentence_transformers = "sentence-transformers")
  }
}

#' The input prefix of a model (`""` for none)
#' @noRd
.embed_prefix <- function(model) {
  if (identical(model, "multilingual-e5")) .e5_prefix else ""
}


#' Prepare text strings for embedding
#'
#' Missing titles and abstracts count as `""`. With `text =
#' "title_abstract"`, `"specter2"` joins them with `.specter2_sep` and no
#' spaces, as its model card does, and every other model (or `model =
#' NULL`) with a space. `"multilingual-e5"` puts `.e5_prefix` before every
#' text, whatever `text` is.
#' @noRd
.embed_prepare_texts <- function(works, text, model = NULL) {
  title <- .embed_field(works, "title")
  abstract <- .embed_field(works, "abstract")
  texts <- switch(text,
    title_abstract = if (identical(model, "specter2")) {
      paste0(title, .specter2_sep, abstract)
    } else {
      paste(title, abstract, sep = " ")
    },
    title = title,
    abstract = abstract
  )
  if (is.null(model)) texts else paste0(.embed_prefix(model), texts)
}

#' One text column of `works`, with `""` for missing values
#' @noRd
.embed_field <- function(works, col) {
  x <- works[[col]] %||% rep(NA_character_, nrow(works))
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

#' Which works have text to embed
#'
#' Read from the raw fields before any separator or prefix is added: a
#' work has text when the field (either field for `"title_abstract"`) has
#' something other than white space.
#' @noRd
.embed_has_text <- function(works, text) {
  filled <- function(col) {
    nzchar(trimws(.embed_field(works, col), whitespace = "[\\h\\v]"))
  }
  switch(text,
    title_abstract = filled("title") | filled("abstract"),
    title = filled("title"),
    abstract = filled("abstract")
  )
}

#' What a work lacks when it has no text, for messages
#' @noRd
.embed_text_missing <- function(text) {
  switch(text,
    title_abstract = "a title or an abstract",
    title = "a title",
    abstract = "an abstract"
  )
}

#' Warn once about the works without text; stop when no work has any
#' @noRd
.embed_warn_no_text <- function(has_text, text, call = rlang::caller_env()) {
  n_none <- sum(!has_text)
  if (n_none == 0L) return(invisible(has_text))
  if (n_none == length(has_text)) {
    cli::cli_abort(
      c("No work has {(.embed_text_missing(text))} to embed.",
        "i" = "Choose another {.arg text}, or add titles or abstracts."),
      class = "scimapR_embed_nothing", call = call
    )
  }
  cli::cli_warn(
    c("{n_none} work{?s} without {(.embed_text_missing(text))}
       {cli::qty(n_none)}{?is/are} left out of the embeddings.",
      "i" = "{cli::qty(n_none)}{?It gets/They get} no row in
             {.field embeddings} and no cluster ({.code NA}) from the
             clustering functions."),
    class = "scimapR_embed_no_text", call = call
  )
  invisible(has_text)
}


#' Decide whether to suggest a multilingual model
#'
#' @param language The `works$language` values (`NULL` when the column is
#'   missing), read with `.normalize_language()`.
#' @param model Short model name.
#' @param threshold Largest share of non-English works, among the works
#'   with a known language, that passes without a note.
#' @return `NULL` when no note is needed (a multilingual model, no known
#'   language, or at most `threshold` of the known languages not English),
#'   else a list: `n_known` (works with a known language), `n_other` (of
#'   them, not English), `share` and `languages` (the other languages, most
#'   frequent first).
#' @noRd
.embed_language_check <- function(language, model, threshold = 0.1) {
  if (is.null(language) || model %in% .embed_multilingual_models) {
    return(NULL)
  }
  lang <- .normalize_language(language)
  known <- !is.na(lang)
  other <- known & lang != "en"
  n_known <- sum(known)
  n_other <- sum(other)
  if (n_known == 0L || n_other / n_known <= threshold) return(NULL)
  counts <- sort(table(lang[other]), decreasing = TRUE)
  list(n_known = n_known, n_other = n_other, share = n_other / n_known,
       languages = names(counts))
}

#' Suggest a multilingual model for a multilingual corpus (a message)
#' @noRd
.embed_inform_language <- function(language, model) {
  check <- .embed_language_check(language, model)
  if (is.null(check)) return(invisible(NULL))
  cli::cli_inform(
    c("i" = "{check$n_other} of {check$n_known} works with a known
             language ({round(100 * check$share)}%)
             {cli::qty(check$n_other)}{?is/are} not in English (mostly
             {.val {utils::head(check$languages, 3L)}}), but {.val {model}}
             is trained on English text.",
      "i" = "A multilingual model, {.val multilingual-mpnet} or
             {.val multilingual-e5}, places works of different languages
             in one space."),
    class = "scimapR_embed_multilingual"
  )
  invisible(check)
}


#' Which of these Python modules are missing
#'
#' A wrapper around `reticulate::py_module_available()`, which imports
#' each module and is `FALSE` for any import error, so a module whose own
#' dependency is missing counts as missing too.
#' @noRd
.py_modules_missing <- function(modules) {
  available <- vapply(modules, function(module) {
    isTRUE(reticulate::py_module_available(module))
  }, logical(1))
  modules[!available]
}

#' Check (and with `install_deps`, first install) the modules of a model
#' @noRd
.embed_check_modules <- function(model, install_deps = FALSE, verbose = TRUE,
                                 call = rlang::caller_env()) {
  modules <- .embed_modules(model)
  adapters <- .embed_backend(model) == "adapters"
  if (install_deps) {
    pkgs <- if (adapters) c("torch", "adapters") else "sentence-transformers"
    .sm_verbose("Installing {.pkg {pkgs}}...", verbose)
    reticulate::py_install(pkgs, pip = TRUE)
  }

  missing <- .py_modules_missing(names(modules))
  if (length(missing) == 0L) return(invisible(TRUE))
  pkgs <- unname(modules[missing])
  cli::cli_abort(
    c("Python package{?s} {.pkg {pkgs}} {?is/are} not installed.",
      if (adapters) {
        c("i" = "{.val specter2} loads the SPECTER2 adapter with
                 {.pkg adapters}, which needs {.pkg torch} and
                 {.pkg transformers}.")
      },
      "i" = "Run {.code sm_embed_works(corpus, model = \"{model}\",
             install_deps = TRUE)} to install what {.val {model}} needs.",
      "i" = "Or install manually:
             {.code pip install {paste(pkgs, collapse = ' ')}}"),
    class = "scimapR_embed_python_missing", call = call
  )
}

#' Stop because a model did not load
#'
#' The Python error text goes in through a glue variable, never into the
#' template, because it can hold braces (such as `{'peft_type'}`).
#' @noRd
.embed_abort_load <- function(model, model_id, err,
                              call = rlang::caller_env()) {
  cli::cli_abort(
    c("Could not load the embedding model {.val {model_id}}
       ({.code model = \"{model}\"}).",
      "x" = "{(.sm_first_line(conditionMessage(err)))}"),
    class = "scimapR_embed_model_load", parent = err, call = call
  )
}

#' The first line of a message that has text
#' @noRd
.sm_first_line <- function(msg) {
  lines <- strsplit(msg, "\n", fixed = TRUE)[[1]]
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) > 0L) lines[[1]] else "unknown error"
}

#' Version of a Python module, `NA` when it does not say
#' @noRd
.py_module_version <- function(module) {
  v <- tryCatch(module[["__version__"]], error = function(e) NULL)
  if (inherits(v, "python.builtin.object")) {
    v <- tryCatch(reticulate::py_to_r(v), error = function(e) NULL)
  }
  if (is.character(v) && length(v) == 1L && !is.na(v)) v else NA_character_
}

#' Embed texts with a sentence-transformers model
#'
#' The texts go to `encode()` as a list, so that a single text is a list
#' of one string in Python, not a string (which gives a 1-D result).
#' @return A list: `embeddings` (as `encode()` returns them) and
#'   `versions`.
#' @noRd
.embed_sentence_transformers <- function(model, texts, batch_size, cache_dir,
                                         verbose = TRUE,
                                         call = rlang::caller_env()) {
  model_id <- .embed_model_name(model)
  st <- reticulate::import("sentence_transformers")
  encoder <- tryCatch(
    st$SentenceTransformer(model_id, cache_folder = cache_dir),
    error = function(e) .embed_abort_load(model, model_id, e, call = call)
  )
  emb_py <- encoder$encode(
    as.list(texts),
    batch_size = as.integer(batch_size),
    show_progress_bar = verbose,
    convert_to_numpy = TRUE
  )
  list(
    embeddings = reticulate::py_to_r(emb_py),
    versions = list(sentence_transformers = .py_module_version(st))
  )
}

#' Python code that encodes texts with SPECTER2, batch by batch
#'
#' As the model card does: padding, truncation to 512 tokens, no token
#' type ids, and the first token of the last hidden state, all under
#' `torch.no_grad()`. Imports sit inside the function, which runs in a
#' namespace of its own.
#' @noRd
.specter2_python <- paste(
  "def encode(tokenizer, model, texts, batch_size):",
  "    import numpy",
  "    import torch",
  "    model.eval()",
  "    parts = []",
  "    with torch.no_grad():",
  "        for start in range(0, len(texts), batch_size):",
  "            inputs = tokenizer(",
  "                texts[start:start + batch_size], padding=True,",
  "                truncation=True, max_length=512, return_tensors='pt',",
  "                return_token_type_ids=False)",
  "            output = model(**inputs)",
  "            first = output.last_hidden_state[:, 0, :]",
  "            parts.append(first.detach().cpu().numpy())",
  "    return numpy.concatenate(parts, axis=0)",
  sep = "\n"
)

#' Embed texts with SPECTER2 (the only Python step of the adapter path)
#'
#' Loads the tokenizer and the base model `.specter2_base_id`, loads the
#' adapter `allenai/specter2` on it and encodes the texts in batches of
#' `batch_size`. `cache_dir` reaches both downloads and the adapter. Load
#' errors stop with `.embed_abort_load()`.
#' @return A list: `embeddings` (a matrix, one row per text) and
#'   `versions` (adapters, transformers and torch).
#' @noRd
.embed_specter2 <- function(texts, batch_size, cache_dir,
                            call = rlang::caller_env()) {
  adapter_id <- .embed_model_name("specter2")
  torch <- reticulate::import("torch")
  transformers <- reticulate::import("transformers")
  adapters <- reticulate::import("adapters")
  loaded <- tryCatch({
    tokenizer <- transformers$AutoTokenizer$from_pretrained(
      .specter2_base_id, cache_dir = cache_dir
    )
    model <- adapters$AutoAdapterModel$from_pretrained(
      .specter2_base_id, cache_dir = cache_dir
    )
    model$load_adapter(adapter_id, source = "hf", load_as = "specter2",
                       set_active = TRUE, cache_dir = cache_dir)
    list(tokenizer = tokenizer, model = model)
  }, error = function(e) {
    .embed_abort_load("specter2", adapter_id, e, call = call)
  })
  py <- reticulate::py_run_string(.specter2_python, local = TRUE)
  emb <- py[["encode"]](loaded$tokenizer, loaded$model, as.list(texts),
                        as.integer(batch_size))
  list(
    embeddings = emb,
    versions = list(
      adapters = .py_module_version(adapters),
      transformers = .py_module_version(transformers),
      torch = .py_module_version(torch)
    )
  )
}

#' The embeddings as a numeric matrix with one row per text
#'
#' A data frame becomes a matrix, and a result without dimensions or with
#' one (a single text that reached Python as a string) becomes one row per
#' text.
#' @noRd
.embed_as_matrix <- function(emb, n, call = rlang::caller_env()) {
  if (is.data.frame(emb)) emb <- as.matrix(emb)
  dims <- dim(emb)
  if (is.null(dims) || length(dims) == 1L) {
    emb <- matrix(as.numeric(emb), nrow = n, byrow = TRUE)
  } else if (!is.matrix(emb)) {
    emb <- as.matrix(emb)
  }
  if (nrow(emb) != n) {
    cli::cli_abort(
      "The model returned {nrow(emb)} embedding{?s} for {n} text{?s}.",
      call = call
    )
  }
  storage.mode(emb) <- "double"
  emb
}

#' Snapshot revision of a model in a Hugging Face cache folder
#'
#' The Hugging Face hub keeps the commit of each downloaded model in
#' `<cache_dir>/models--<org>--<name>/refs/main`.
#' @return The commit, or `NA` when the folder does not show it.
#' @noRd
.embed_snapshot_revision <- function(cache_dir, model_id) {
  path <- file.path(cache_dir, paste0("models--", gsub("/", "--", model_id)),
                    "refs", "main")
  if (!file.exists(path)) return(NA_character_)
  rev <- tryCatch(readLines(path, n = 1L, warn = FALSE),
                  error = function(e) character())
  rev <- trimws(rev)
  if (length(rev) == 1L && nzchar(rev)) rev else NA_character_
}

#' The embedding record that sm_embed_works() writes
#' @noRd
.embed_works_record <- function(model, text, cache_dir, versions, emb) {
  model_id <- .embed_model_name(model)
  specter2 <- identical(model, "specter2")
  .new_embedding_record(
    model = model,
    model_id = model_id,
    backend = .embed_backend(model),
    n_works = nrow(emb),
    n_dimensions = ncol(emb),
    base_model_id = if (specter2) .specter2_base_id else NA_character_,
    revision = .embed_snapshot_revision(cache_dir, model_id),
    base_revision = if (specter2) {
      .embed_snapshot_revision(cache_dir, .specter2_base_id)
    } else {
      NA_character_
    },
    text = text,
    prefix = .embed_prefix(model),
    versions = versions %||% list()
  )
}

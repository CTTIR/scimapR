#' Save embeddings to disk
#'
#' @description
#' Saves the embeddings matrix from an `sm_corpus` to an RDS file on disk.
#' This allows caching expensive embedding computations for later reuse
#' with [sm_embed_load()].
#'
#' @param corpus An [sm_corpus] object with a non-`NULL` `embeddings` matrix.
#' @param path Character; file path to write the embeddings to. Should end in
#'   `.rds`.
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` (invisibly).
#'
#' @family embedding
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus(with_embeddings = TRUE)
#' sm_embed_save(corpus, "my_embeddings.rds")
#' }
sm_embed_save <- function(corpus, path, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(path, call = call)

  emb <- corpus$embeddings
  if (is.null(emb)) {
    cli::cli_abort(
      c("No embeddings to save.",
        "i" = "Compute embeddings first with {.fun sm_embed_works}."),
      call = call
    )
  }

  # Ensure parent directory exists
  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    fs::dir_create(parent_dir, recurse = TRUE)
  }

  # Save as RDS with work_id mapping
  cache_data <- list(
    embeddings = emb,
    work_ids   = rownames(emb),
    timestamp  = Sys.time(),
    n_works    = nrow(emb),
    n_dims     = ncol(emb)
  )

  saveRDS(cache_data, file = path)
  cli::cli_inform(c(
    "v" = "Embeddings saved to {.path {path}}.",
    "i" = "{nrow(emb)} works x {ncol(emb)} dimensions."
  ))

  invisible(corpus)
}


#' Load embeddings from disk
#'
#' @description
#' Loads a previously saved embeddings matrix from an RDS file and attaches
#' it to the corpus. Only embeddings for works present in the corpus are
#' loaded; mismatches are reported.
#'
#' @param corpus An [sm_corpus] object.
#' @param path Character; file path to read embeddings from (an `.rds` file
#'   created by [sm_embed_save()]).
#' @param call Caller environment for error reporting.
#'
#' @return The input `corpus` with `corpus$embeddings` updated.
#'
#' @family embedding
#' @export
#' @examples
#' \dontrun{
#' corpus <- sm_example_corpus(with_embeddings = FALSE)
#' corpus <- sm_embed_load(corpus, "my_embeddings.rds")
#' dim(corpus$embeddings)
#' }
sm_embed_load <- function(corpus, path, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_string(path, call = call)
  .check_file_exists(path, call = call)

  cache_data <- readRDS(path)

  # Support both raw matrix and list format

  if (is.list(cache_data) && "embeddings" %in% names(cache_data)) {
    emb <- cache_data$embeddings
  } else if (is.matrix(cache_data)) {
    emb <- cache_data
  } else {
    cli::cli_abort(
      "File {.path {path}} does not contain a valid embeddings cache.",
      call = call
    )
  }

  if (!is.matrix(emb) || !is.numeric(emb)) {
    cli::cli_abort(
      "Cached embeddings are not a numeric matrix.",
      call = call
    )
  }

  # Match to current corpus works
  cached_ids <- rownames(emb)
  corpus_ids <- corpus$works$work_id

  if (is.null(cached_ids)) {
    # If no row names, assume same order and length
    if (nrow(emb) != length(corpus_ids)) {
      cli::cli_abort(
        c("Cached embeddings have {nrow(emb)} rows but corpus has {length(corpus_ids)} works.",
          "i" = "Row names are missing from the cached matrix; cannot match."),
        call = call
      )
    }
    rownames(emb) <- corpus_ids
  } else {
    # Subset to works in current corpus
    matched <- intersect(cached_ids, corpus_ids)
    missing <- setdiff(corpus_ids, cached_ids)

    if (length(matched) == 0L) {
      cli::cli_abort(
        "No overlap between cached embeddings and corpus work IDs.",
        call = call
      )
    }

    if (length(missing) > 0L) {
      cli::cli_inform(c(
        "!" = "{length(missing)} work{?s} in the corpus lack cached embeddings.",
        "i" = "Use {.fun sm_embed_works} to compute embeddings for all works."
      ))
    }

    emb <- emb[matched, , drop = FALSE]
  }

  corpus$embeddings <- emb

  cli::cli_inform(c(
    "v" = "Embeddings loaded: {nrow(emb)} works x {ncol(emb)} dimensions."
  ))

  corpus
}

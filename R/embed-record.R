# The record of the model behind corpus$embeddings, kept in
# corpus$metadata$embedding (see ?sm_corpus). sm_embed_works(),
# sm_embed_load(), sm_enrich_specter(), sm_fetch_semantic_scholar() and
# sm_bind_corpora() write it, the functions that combine embeddings check
# it, and sm_certificate() reports it.

#' Build an embedding record
#'
#' One place for the entries of `corpus$metadata$embedding`, so that every
#' writer gives the same list. `models` lists the model ids behind the
#' rows: the model itself, or several for a mix.
#' @noRd
.new_embedding_record <- function(model, model_id, backend, n_works,
                                  n_dimensions,
                                  base_model_id = NA_character_,
                                  revision = NA_character_,
                                  base_revision = NA_character_,
                                  text = NA_character_,
                                  prefix = NA_character_,
                                  versions = list(),
                                  models = model_id) {
  list(
    model = model,
    model_id = model_id,
    base_model_id = base_model_id,
    revision = revision,
    base_revision = base_revision,
    backend = backend,
    text = text,
    prefix = prefix,
    versions = versions,
    models = models,
    n_works = as.integer(n_works),
    n_dimensions = as.integer(n_dimensions),
    created = .as_utc_time(Sys.time())
  )
}

#' The embedding record of a corpus, when it describes its embeddings
#'
#' `NULL` when the corpus has no embeddings, records no model, or records
#' one that no longer fits the matrix: another width, or more rows than
#' were recorded (rows are only removed by subsetting and deduplication, so
#' more rows mean that the matrix was changed without its record).
#' @noRd
.embedding_record <- function(corpus) {
  emb <- corpus$embeddings
  rec <- corpus$metadata$embedding
  if (is.null(emb) || nrow(emb) == 0L) return(NULL)
  .embedding_record_fits(rec, emb)
}

#' `rec` when it is a record that fits the matrix `emb`, else `NULL`
#' @noRd
.embedding_record_fits <- function(rec, emb) {
  named <- is.list(rec) && rlang::is_string(rec$model_id)
  if (!named || is.na(rec$model_id)) return(NULL)
  count <- function(x) {
    if (is.numeric(x) && length(x) == 1L && !is.na(x)) x else NA_real_
  }
  dims <- count(rec$n_dimensions)
  rows <- count(rec$n_works)
  if (is.na(dims) || dims != ncol(emb)) return(NULL)
  if (!is.na(rows) && nrow(emb) > rows) return(NULL)
  rec
}

#' Do two records name the same single model?
#' @noRd
.embedding_same_model <- function(rec1, rec2) {
  !is.null(rec1) && !is.null(rec2) &&
    identical(rec1$model_id, rec2$model_id) &&
    !identical(rec1$model_id, "mixed")
}

#' The record of a matrix whose rows come from several models
#'
#' @param records Records of the parts (`NULL` for a part whose model is
#'   not recorded, which counts as `"unknown"`).
#' @noRd
.embedding_mixed_record <- function(records, n_works, n_dimensions) {
  ids <- unlist(lapply(records, function(rec) {
    if (is.null(rec)) "unknown" else rec$models %||% rec$model_id
  }))
  .new_embedding_record(
    model = "mixed", model_id = "mixed", backend = "mixed",
    n_works = n_works, n_dimensions = n_dimensions,
    models = unique(ids)
  )
}

#' Describe embeddings by their record, for messages
#'
#' `"embeddings of "<model id>""`, `"embeddings of several models (...)"`
#' or, without a record, `"embeddings whose model is not recorded"`. The
#' model ids go in through glue variables, so the result can be pasted
#' into a cli template as a variable.
#' @noRd
.embedding_describe <- function(rec) {
  if (is.null(rec)) return("embeddings whose model is not recorded")
  if (identical(rec$model_id, "mixed")) {
    return(cli::format_inline(
      "embeddings of several models ({.val {rec$models}})"
    ))
  }
  cli::format_inline("embeddings of {.val {rec$model_id}}")
}

#' Stop because two sets of embeddings come from different models
#'
#' @param what The first line, a cli template that can use `{first}` and
#'   `{second}`, the descriptions (`.embedding_describe()`) of `rec1` and
#'   `rec2`.
#' @param hint Lines on how to go on.
#' @noRd
.embedding_abort_mismatch <- function(what, rec1, rec2, hint,
                                      call = rlang::caller_env()) {
  described <- list(first = .embedding_describe(rec1),
                    second = .embedding_describe(rec2))
  cli::cli_abort(
    c(what,
      "i" = "Similarities between embeddings of different models mean
             nothing, so they are not combined.",
      hint),
    class = "scimapR_embedding_model_mismatch", call = call,
    .envir = list2env(described, parent = environment())
  )
}

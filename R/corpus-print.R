#' @rdname sm_corpus
#' @param x,object An `sm_corpus` object.
#' @param ... Ignored.
#' @return
#'   - `print()`: `x` invisibly.
#'   - `format()`: A single character string.
#'   - `summary()`: A named list of summary statistics.
#'   - `str()`: `object` invisibly.
#' @export
print.sm_corpus <- function(x, ...) {
  n_w <- nrow(x$works)
  n_a <- nrow(x$authors)
  n_i <- nrow(x$institutions)

  cli::cli_h1("<sm_corpus>")

  yr_range <- if (n_w > 0 && any(!is.na(x$works$year))) {
    rng <- range(x$works$year, na.rm = TRUE)
    paste0(rng[1], " - ", rng[2])
  } else {
    "none"
  }

  cli::cli_text("{.strong Works:} {n_w} | {.strong Authors:} {n_a} | {.strong Institutions:} {n_i}")
  cli::cli_text("{.strong Years:} {yr_range}")

  n_src <- nrow(x$sources)
  cli::cli_text("{.strong Sources (journals):} {n_src}")

  has_emb <- !is.null(x$embeddings) && nrow(x$embeddings) > 0
  emb_txt <- if (has_emb) {
    paste0(nrow(x$embeddings), " x ", ncol(x$embeddings))
  } else {
    "none"
  }
  cli::cli_text("{.strong Embeddings:} {emb_txt}")

  if (nrow(x$provenance) > 0) {
    src_counts <- sort(table(x$provenance$source), decreasing = TRUE)
    top <- utils::head(src_counts, 3)
    top_txt <- paste0(names(top), " (", top, ")", collapse = ", ")
    cli::cli_text("{.strong Provenance:} {top_txt}")
  }

  locked <- isTRUE(x$metadata$is_locked)
  if (locked) {
    cli::cli_text("{.strong Status:} Locked")
  } else {
    lr <- x$metadata$last_refresh
    lr_txt <- if (is.null(lr) || is.na(lr)) "never" else format(lr)
    cli::cli_text("{.strong Status:} Unlocked (last refreshed: {lr_txt})")
  }

  if (nrow(x$screening) > 0) {
    scr <- table(x$screening$stage, x$screening$decision)
    cli::cli_text("{.strong Screening:} {nrow(x$screening)} decisions across {length(unique(x$screening$stage))} stage(s)")
  }

  invisible(x)
}

#' @rdname sm_corpus
#' @param x,object An `sm_corpus` object.
#' @param ... Ignored.
#' @export
format.sm_corpus <- function(x, ...) {
  paste0("<sm_corpus> ", nrow(x$works), " works, ", nrow(x$authors), " authors")
}

#' @rdname sm_corpus
#' @export
summary.sm_corpus <- function(object, ...) {
  list(
    n_works = nrow(object$works),
    n_authors = nrow(object$authors),
    n_institutions = nrow(object$institutions),
    n_sources = nrow(object$sources),
    n_references = nrow(object$references),
    n_concepts = nrow(object$concepts),
    has_embeddings = !is.null(object$embeddings),
    n_provenance = nrow(object$provenance),
    n_screening = nrow(object$screening),
    year_range = if (nrow(object$works) > 0 && any(!is.na(object$works$year))) {
      range(object$works$year, na.rm = TRUE)
    } else {
      c(NA_integer_, NA_integer_)
    },
    is_locked = isTRUE(object$metadata$is_locked)
  )
}

#' @rdname sm_corpus
#' @export
str.sm_corpus <- function(object, ...) {
  emb_txt <- if (is.null(object$embeddings)) "NULL" else
    paste0(nrow(object$embeddings), "x", ncol(object$embeddings), " matrix")
  cli::cli_text(format(object))
  cli::cli_text("  works:        {nrow(object$works)} x {ncol(object$works)} tibble")
  cli::cli_text("  authors:      {nrow(object$authors)} x {ncol(object$authors)} tibble")
  cli::cli_text("  authorships:  {nrow(object$authorships)} x {ncol(object$authorships)} tibble")
  cli::cli_text("  institutions: {nrow(object$institutions)} x {ncol(object$institutions)} tibble")
  cli::cli_text("  sources:      {nrow(object$sources)} x {ncol(object$sources)} tibble")
  cli::cli_text("  references:   {nrow(object$references)} x {ncol(object$references)} tibble")
  cli::cli_text("  concepts:     {nrow(object$concepts)} x {ncol(object$concepts)} tibble")
  cli::cli_text("  embeddings:   {emb_txt}")
  cli::cli_text("  provenance:   {nrow(object$provenance)} x {ncol(object$provenance)} tibble")
  cli::cli_text("  screening:    {nrow(object$screening)} x {ncol(object$screening)} tibble")
  invisible(object)
}

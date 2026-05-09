#' Coerce objects to sm_corpus
#'
#' @description
#' Generic function to convert various data types to an `sm_corpus` object.
#'
#' @param x An object to coerce.
#' @param ... Additional arguments passed to methods.
#'
#' @return An `sm_corpus` object.
#'
#' @family corpus
#' @export
as_sm_corpus <- function(x, ...) {
  UseMethod("as_sm_corpus")
}

#' @rdname as_sm_corpus
#' @export
as_sm_corpus.sm_corpus <- function(x, ...) {
 x
}

#' @rdname as_sm_corpus
#' @param source_label Label for provenance tracking.
#' @export
as_sm_corpus.data.frame <- function(x, source_label = "data.frame", ...) {
  x <- tibble::as_tibble(x)
  works <- .ensure_works_schema(x)
  sm_corpus(works = works)
}

#' @rdname as_sm_corpus
#' @export
as_sm_corpus.list <- function(x, ...) {
  if ("works" %in% names(x)) {
    do.call(sm_corpus, x)
  } else {
    cli::cli_abort(
      "Cannot coerce list to {.cls sm_corpus}: no {.field works} element found."
    )
  }
}

#' @rdname sm_corpus
#' @param x,object An `sm_corpus` object.
#' @param ... Ignored.
#' @return
#'   - `as_tibble()`: The works tibble.
#'   - `as.data.frame()`: The works table as a data frame.
#' @export
as_tibble.sm_corpus <- function(x, ...) {
  x$works
}

#' @rdname sm_corpus
#' @export
as.data.frame.sm_corpus <- function(x, ...) {
  as.data.frame(x$works, ...)
}

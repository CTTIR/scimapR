#' Register a local input file of a corpus
#'
#' @description
#' Record a local file that a corpus was built from, such as a database
#' snapshot, an institutional export, a publication tracker or an
#' affiliation dictionary, together with its SHA-256 hash. [sm_certificate()]
#' lists the registered files in its `local_inputs` block, and
#' [sm_verify_certificate()] checks that each of them still has the hash
#' recorded here. [sm_corpus_from_tables()] registers the files given as its
#' `inputs`.
#'
#' @details
#' The file is hashed as a stream (`digest::digest(path, algo = "sha256",
#' file = TRUE)`), so large snapshots are not read into memory. The function
#' adds one row to `corpus$metadata$local_inputs`, a tibble with these
#' columns:
#'
#' | Column | Type | Content |
#' | --- | --- | --- |
#' | `path` | character | The path, relative or as given (see below) |
#' | `path_abs` | character | The absolute path of the file |
#' | `root` | character | The working directory at registration |
#' | `basename` | character | The file name |
#' | `sha256` | character | SHA-256 hash of the content |
#' | `bytes` | double | Size in bytes |
#' | `role` | character | What the file is, such as `"dictionary"` |
#' | `builder` | character | The code that read it |
#' | `registered_at` | POSIXct | When it was registered (UTC, whole seconds) |
#'
#' `path` is relative to the working directory when the file lies below
#' it, and as given otherwise. `role` names the file's part in the corpus,
#' such as `"source database"` or `"publication tracker"`, and `builder`
#' the code that read it, such as `"R/02_corpus.R::build_corpus"`.
#'
#' Registering the same file again replaces its row; paths are compared
#' after they are made absolute, so `"data/x.csv"` and `"./data/x.csv"` name
#' the same file. A corpus without registered files has no such element;
#' [sm_certificate()] then writes an empty block.
#'
#' Local inputs are metadata: they do not enter the corpus hash
#' ([sm_hash_corpus()]), and [sm_rebuild_from_cert()] cannot replay them. A
#' certificate records `path_abs` and `root` as well as `path`, so that
#' [sm_verify_certificate()] finds the files on the same computer from any
#' folder; these absolute paths show the folder names of that computer.
#'
#' @param corpus An `sm_corpus` object. A locked corpus ([sm_lock()]) cannot
#'   be changed.
#' @param path Path of the file.
#' @param role `NULL` or a string: what the file is.
#' @param builder `NULL` or a string: the code that read the file.
#' @param call Caller environment for error reporting.
#'
#' @return The corpus with the file recorded in
#'   `corpus$metadata$local_inputs`.
#'
#' @family reproducibility
#' @seealso [sm_certificate()], [sm_verify_certificate()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 10)
#' tracker <- tempfile(fileext = ".csv")
#' writeLines(c("doi,unit", "10.9999/example.1,Unit A"), tracker)
#' corpus <- sm_register_input(corpus, tracker,
#'                             role = "publication tracker",
#'                             builder = "R/01_import.R::read_tracker")
#' corpus$metadata$local_inputs
sm_register_input <- function(corpus,
                              path,
                              role = NULL,
                              builder = NULL,
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_corpus_unlocked(corpus, call = call)
  .check_string(path, call = call)
  .check_string(role, allow_null = TRUE, call = call)
  .check_string(builder, allow_null = TRUE, call = call)

  row <- .local_input_row(path, role = role, builder = builder, call = call)
  inputs <- .as_local_inputs_tbl(corpus$metadata$local_inputs)
  corpus$metadata$local_inputs <- .add_local_input(inputs, row)
  corpus
}

#' The registration row of one local input file
#' @noRd
.local_input_row <- function(path, role = NULL, builder = NULL,
                             call = rlang::caller_env()) {
  full <- path.expand(path)
  if (!file.exists(full) || dir.exists(full)) {
    cli::cli_abort(
      c("Cannot register {.path {path}} as a local input.",
        "x" = if (dir.exists(full)) "It is a folder, not a file." else
          "No such file."),
      call = call
    )
  }
  abs <- .normalize_file_path(full)
  root <- .normalize_path(getwd())
  tibble::tibble(
    path = .path_below(abs, root) %||% path,
    path_abs = abs,
    root = root,
    basename = basename(full),
    sha256 = digest::digest(full, algo = "sha256", file = TRUE),
    bytes = as.numeric(file.size(full)),
    role = role %||% NA_character_,
    builder = builder %||% NA_character_,
    registered_at = .POSIXct(floor(as.numeric(Sys.time())), tz = "UTC")
  )
}

#' Add a registration row, replacing the row of the same file
#' @noRd
.add_local_input <- function(inputs, row) {
  hit <- which(.local_input_key(inputs) == .local_input_key(row))
  if (length(hit) == 0L) return(dplyr::bind_rows(inputs, row))
  inputs[hit[1], ] <- row
  if (length(hit) > 1L) inputs <- inputs[-hit[-1], ]
  inputs
}

#' The file a registration row names: its absolute path, else its path
#' @noRd
.local_input_key <- function(inputs) {
  ifelse(is.na(inputs$path_abs), inputs$path, inputs$path_abs)
}

#' Local inputs as one tibble, whatever form they were stored in
#'
#' Accepts `NULL`, an empty list, a data frame (such as the tibble of
#' [sm_register_input()]), a list of rows (each a named list, as a
#' certificate writes them to YAML) and a named list of columns (as YAML
#' gives back a data frame written column by column). Columns missing from
#' the input are `NA`; other columns are dropped; `registered_at` text is
#' read as UTC.
#' @return A tibble with the columns of `.empty_local_inputs()`.
#' @noRd
.as_local_inputs_tbl <- function(x) {
  template <- .empty_local_inputs()
  cols <- names(template)
  if (is.null(x) || length(x) == 0L) return(template)

  data <- if (is.data.frame(x)) {
    as.list(x)
  } else if (is.list(x) && is.null(names(x))) {
    # one named list per input
    stats::setNames(lapply(cols, function(col) {
      unlist(lapply(x, function(row) {
        value <- row[[col]]
        if (is.null(value) || length(value) == 0L) NA else value[[1]]
      }))
    }), cols)
  } else if (is.list(x)) {
    lapply(x, function(value) if (is.list(value)) unlist(value) else value)
  } else {
    return(template)
  }

  n <- max(c(0L, lengths(data[intersect(cols, names(data))])))
  if (n == 0L) return(template)
  out <- lapply(cols, function(col) {
    value <- data[[col]]
    if (is.null(value) || length(value) == 0L) value <- rep(NA, n)
    if (length(value) != n) value <- rep_len(value, n)
    switch(col,
      bytes = suppressWarnings(as.numeric(value)),
      registered_at = .as_utc_times(value, what = "local_inputs$registered_at"),
      as.character(value)
    )
  })
  tibble::as_tibble(stats::setNames(out, cols))
}

#' Read several stored timestamps, one UTC date-time each
#' @noRd
.as_utc_times <- function(x, what = "timestamp") {
  if (inherits(x, "POSIXt")) return(.POSIXct(as.numeric(as.POSIXct(x)),
                                             tz = "UTC"))
  secs <- vapply(seq_along(x), function(i) {
    as.numeric(.as_utc_time(x[i], what = what))
  }, numeric(1))
  .POSIXct(secs, tz = "UTC")
}

#' Local inputs as a list of rows, as a certificate writes them to YAML
#' @noRd
.local_inputs_to_list <- function(inputs) {
  inputs <- .as_local_inputs_tbl(inputs)
  lapply(seq_len(nrow(inputs)), function(i) {
    row <- as.list(inputs[i, ])
    row$registered_at <- .format_utc_time(
      inputs$registered_at[i], what = "local_inputs$registered_at"
    )
    row
  })
}

#' The local inputs of two corpora, each file and content once
#' @noRd
.bind_local_inputs <- function(inputs1, inputs2) {
  if (is.null(inputs1) && is.null(inputs2)) return(NULL)
  both <- dplyr::bind_rows(.as_local_inputs_tbl(inputs1),
                           .as_local_inputs_tbl(inputs2))
  both[!duplicated(paste(.local_input_key(both), both$sha256)), ]
}

#' Register the `inputs` of sm_corpus_from_tables()
#'
#' `inputs` is a character vector of paths (its names, where given, become
#' `role`) or a data frame with a `path` column and optional `role` and
#' `builder` columns. Inputs already in `corpus$metadata$local_inputs` are
#' kept as one tibble.
#' @noRd
.register_inputs <- function(corpus, inputs, call = rlang::caller_env()) {
  if (!is.null(corpus$metadata$local_inputs)) {
    corpus$metadata$local_inputs <-
      .as_local_inputs_tbl(corpus$metadata$local_inputs)
  }
  if (is.null(inputs)) return(corpus)

  spec <- .input_spec(inputs, call = call)
  for (i in seq_len(nrow(spec))) {
    corpus <- sm_register_input(
      corpus, spec$path[i],
      role = if (is.na(spec$role[i])) NULL else spec$role[i],
      builder = if (is.na(spec$builder[i])) NULL else spec$builder[i],
      call = call
    )
  }
  corpus
}

#' The paths, roles and builders given as `inputs`
#' @noRd
.input_spec <- function(inputs, call = rlang::caller_env()) {
  if (is.character(inputs)) {
    role <- names(inputs) %||% rep(NA_character_, length(inputs))
    role[!nzchar(role)] <- NA_character_
    spec <- tibble::tibble(path = unname(inputs), role = role,
                           builder = NA_character_)
  } else if (is.data.frame(inputs) && "path" %in% names(inputs)) {
    n <- nrow(inputs)
    pick <- function(col) {
      if (col %in% names(inputs)) as.character(inputs[[col]]) else
        rep(NA_character_, n)
    }
    spec <- tibble::tibble(path = pick("path"), role = pick("role"),
                           builder = pick("builder"))
  } else {
    cli::cli_abort(
      c("{.arg inputs} must be a character vector of file paths or a data
         frame with a {.field path} column.",
        "i" = "Names of a character vector, or the columns {.field role}
               and {.field builder}, describe each file."),
      call = call
    )
  }
  if (anyNA(spec$path) || any(!nzchar(spec$path))) {
    cli::cli_abort("{.arg inputs} has a missing or empty path.", call = call)
  }
  spec
}

# ---- paths -------------------------------------------------------------------

#' An absolute path with forward slashes and resolved links
#' @noRd
.normalize_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

#' A file's absolute path: its folder resolved, its name as given
#'
#' Resolving the folder turns macOS's `/var/...` into `/private/var/...`, as
#' `getwd()` reports it; the name stays, so a file that is a link keeps the
#' name it was registered under.
#' @noRd
.normalize_file_path <- function(path) {
  file.path(.normalize_path(dirname(path)), basename(path))
}

#' The part of `path` below the folder `dir`, or NULL when it is not below
#' @noRd
.path_below <- function(path, dir) {
  prefix <- paste0(sub("/+$", "", dir), "/")
  below <- if (.Platform$OS.type == "windows") {
    startsWith(tolower(path), tolower(prefix))
  } else {
    startsWith(path, prefix)
  }
  if (isTRUE(below)) substring(path, nchar(prefix) + 1L) else NULL
}

#' The path a file step records: relative to the working directory when the
#' file lies below it, else the file name; relative paths stay as they are
#' @noRd
.file_step_path <- function(path) {
  path <- as.character(path)
  absolute <- !is.na(path) & fs::is_absolute_path(path)
  if (!any(absolute)) return(path)
  wd <- .normalize_path(getwd())
  path[absolute] <- vapply(path[absolute], function(p) {
    .path_below(.normalize_file_path(path.expand(p)), wd) %||% basename(p)
  }, character(1), USE.NAMES = FALSE)
  path
}

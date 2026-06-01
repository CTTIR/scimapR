# Part F1: figure caption / alt-text manifest.

#' Build a figure caption and alt-text manifest
#'
#' @description
#' Scans a directory of figures and produces a tidy manifest of captions,
#' alt-text, and (where readable) pixel dimensions and DPI. This replaces the
#' hand-maintained `figure_captions.R` scripts that accompany many manuscripts.
#'
#' Captions and alt-text are pulled from a sidecar file if one is present
#' (`captions.csv`, `captions.yml`, or `captions.yaml` in `dir`), otherwise the
#' columns are left empty for the user to fill in.
#'
#' @param dir Directory to scan.
#' @param pattern Optional regular expression to filter file names. Defaults to
#'   common figure extensions (`png`, `pdf`, `svg`, `tif`, `tiff`, `jpg`,
#'   `jpeg`, `eps`).
#' @param output Optional path to write the manifest to. A `.csv` extension
#'   writes CSV; `.yml`/`.yaml` writes YAML (requires the optional \pkg{yaml}
#'   package).
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row per figure file and columns `file`, `caption`,
#'   `alt_text`, `width`, `height`, `dpi`. Pixel dimensions / DPI are read from
#'   the image where feasible (using the optional \pkg{magick} or \pkg{png}
#'   packages) and are `NA` otherwise. Type-stable: a missing or empty directory
#'   returns a 0-row tibble (with a `cli` warning), never an error.
#'
#' @family reporting
#' @export
#' @examples
#' \donttest{
#' d <- withr::local_tempdir()
#' ggplot2::ggsave(file.path(d, "fig1.png"),
#'                 ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
#'                   ggplot2::geom_point(),
#'                 width = 4, height = 3, dpi = 150)
#' sm_figure_manifest(d)
#' }
sm_figure_manifest <- function(dir,
                               pattern = NULL,
                               output = NULL,
                               call = rlang::caller_env()) {
  empty <- tibble::tibble(
    file = character(), caption = character(), alt_text = character(),
    width = integer(), height = integer(), dpi = double()
  )

  if (length(dir) != 1L || !is.character(dir) || !fs::dir_exists(dir)) {
    cli::cli_warn(c(
      "!" = "Directory {.path {dir}} does not exist.",
      "i" = "Returning an empty figure manifest."
    ))
    return(empty)
  }

  pattern <- pattern %||%
    "\\.(png|pdf|svg|tif|tiff|jpg|jpeg|eps)$"
  files <- list.files(dir, pattern = pattern, ignore.case = TRUE,
                      full.names = TRUE)
  files <- files[!grepl("^captions\\.", basename(files), ignore.case = TRUE)]

  if (length(files) == 0L) {
    cli::cli_warn(c(
      "!" = "No figure files matched in {.path {dir}}.",
      "i" = "Returning an empty figure manifest."
    ))
    return(empty)
  }

  sidecar <- .read_caption_sidecar(dir)

  dims <- lapply(files, .figure_dimensions)
  manifest <- tibble::tibble(
    file = basename(files),
    caption = vapply(basename(files), function(f) {
      sidecar$caption[[f]] %||% ""
    }, character(1), USE.NAMES = FALSE),
    alt_text = vapply(basename(files), function(f) {
      sidecar$alt_text[[f]] %||% ""
    }, character(1), USE.NAMES = FALSE),
    width = vapply(dims, function(d) d$width, integer(1)),
    height = vapply(dims, function(d) d$height, integer(1)),
    dpi = vapply(dims, function(d) d$dpi, double(1))
  )

  if (!is.null(output)) {
    .write_manifest(manifest, output, call = call)
  }

  manifest
}

#' Read a caption/alt-text sidecar file if present
#' @noRd
.read_caption_sidecar <- function(dir) {
  empty <- list(caption = list(), alt_text = list())
  csv <- file.path(dir, "captions.csv")
  yml <- c(file.path(dir, "captions.yml"), file.path(dir, "captions.yaml"))
  yml <- yml[file.exists(yml)]

  if (file.exists(csv)) {
    df <- tryCatch(
      utils::read.csv(csv, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
    if (is.null(df) || !"file" %in% names(df)) return(empty)
    cap <- if ("caption" %in% names(df)) {
      stats::setNames(as.list(as.character(df$caption)), df$file)
    } else {
      list()
    }
    alt <- if ("alt_text" %in% names(df)) {
      stats::setNames(as.list(as.character(df$alt_text)), df$file)
    } else {
      list()
    }
    return(list(caption = cap, alt_text = alt))
  }

  if (length(yml) > 0L && rlang::is_installed("yaml")) {
    y <- tryCatch(yaml::read_yaml(yml[1]), error = function(e) NULL)
    if (is.null(y)) return(empty)
    cap <- lapply(y, function(e) e$caption %||% NULL)
    alt <- lapply(y, function(e) e$alt_text %||% NULL)
    return(list(caption = cap, alt_text = alt))
  }

  empty
}

#' Read pixel dimensions / DPI from an image file
#' @noRd
.figure_dimensions <- function(path) {
  na_dims <- list(width = NA_integer_, height = NA_integer_, dpi = NA_real_)
  ext <- tolower(tools::file_ext(path))

  if (rlang::is_installed("magick") &&
      ext %in% c("png", "jpg", "jpeg", "tif", "tiff")) {
    info <- tryCatch(magick::image_info(magick::image_read(path)),
                     error = function(e) NULL)
    if (!is.null(info) && nrow(info) > 0L) {
      dens <- suppressWarnings(as.numeric(sub("x.*$", "", info$density[1])))
      return(list(
        width = as.integer(info$width[1]),
        height = as.integer(info$height[1]),
        dpi = if (length(dens) && !is.na(dens) && dens > 0) dens else NA_real_
      ))
    }
  }

  if (ext == "png" && rlang::is_installed("png")) {
    img <- tryCatch(png::readPNG(path, info = TRUE), error = function(e) NULL)
    if (!is.null(img)) {
      d <- dim(img)
      dpi <- attr(img, "dpi")
      return(list(
        width = as.integer(d[2]),
        height = as.integer(d[1]),
        dpi = if (!is.null(dpi)) as.double(dpi[1]) else NA_real_
      ))
    }
  }

  na_dims
}

#' Write a figure manifest to CSV or YAML
#' @noRd
.write_manifest <- function(manifest, output, call = rlang::caller_env()) {
  ext <- tolower(tools::file_ext(output))
  if (ext == "csv") {
    utils::write.csv(manifest, output, row.names = FALSE)
  } else if (ext %in% c("yml", "yaml")) {
    rlang::check_installed("yaml", reason = "to write a YAML manifest.",
                           call = call)
    rows <- stats::setNames(
      lapply(seq_len(nrow(manifest)), function(i) {
        list(caption = manifest$caption[i], alt_text = manifest$alt_text[i],
             width = manifest$width[i], height = manifest$height[i],
             dpi = manifest$dpi[i])
      }),
      manifest$file
    )
    writeLines(yaml::as.yaml(rows), output)
  } else {
    cli::cli_abort(c(
      "Unsupported manifest extension {.val {ext}}.",
      "i" = "Use a {.file .csv}, {.file .yml}, or {.file .yaml} path."
    ), call = call)
  }
  cli::cli_inform(c("v" = "Wrote figure manifest to {.path {output}}."))
}

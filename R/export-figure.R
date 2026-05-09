#' Export a plot as a publication-ready figure
#'
#' @description
#' Save a ggplot to disk in multiple formats and resolutions.
#' By default, raster formats are saved at both 300 and 600 dpi.
#'
#' @param plot A `ggplot` object.
#' @param path Output file path (extension determines format if `format`
#'   not specified).
#' @param format Output format.
#' @param dpi Resolution for raster formats.
#' @param width Plot width.
#' @param height Plot height.
#' @param units Size units.
#' @param background Background colour.
#' @param multi_dpi Logical; write both 300 and 600 dpi versions for
#'   raster formats?
#'
#' @return Character vector of paths actually written, invisibly.
#'
#' @family export
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 20)
#' p <- sm_plot_production(corpus)
#' path <- tempfile(fileext = ".png")
#' sm_export_figure(p, path, multi_dpi = FALSE)
sm_export_figure <- function(plot,
                             path,
                             format = c("png", "pdf", "svg", "tiff", "eps"),
                             dpi = c(300, 600),
                             width = 7,
                             height = 5,
                             units = c("in", "cm", "mm"),
                             background = c("white", "transparent"),
                             multi_dpi = TRUE) {
  format <- match.arg(format)
  units <- match.arg(units)
  background <- match.arg(background)

  is_vector <- format %in% c("pdf", "svg", "eps")
  paths_written <- character()

  if (is_vector) {
    ggplot2::ggsave(
      filename = path,
      plot = plot,
      device = format,
      width = width,
      height = height,
      units = units,
      bg = background
    )
    paths_written <- path
  } else {
    resolutions <- if (multi_dpi) c(300, 600) else dpi[1]
    base <- tools::file_path_sans_ext(path)
    ext <- tools::file_ext(path)

    for (res in resolutions) {
      out_path <- if (multi_dpi && length(resolutions) > 1) {
        paste0(base, "_", res, "dpi.", ext)
      } else {
        path
      }

      device <- NULL
      if (format == "png" && requireNamespace("ragg", quietly = TRUE)) {
        device <- ragg::agg_png
      }

      if (format == "tiff") {
        ggplot2::ggsave(
          filename = out_path,
          plot = plot,
          device = "tiff",
          width = width,
          height = height,
          units = units,
          dpi = res,
          compression = "lzw",
          bg = background
        )
      } else {
        ggplot2::ggsave(
          filename = out_path,
          plot = plot,
          device = device,
          width = width,
          height = height,
          units = units,
          dpi = res,
          bg = background
        )
      }

      paths_written <- c(paths_written, out_path)
    }
  }

  .sm_done("Saved figure to: {.path {paths_written}}")
  invisible(paths_written)
}

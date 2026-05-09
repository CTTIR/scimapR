#' scimapR plot theme
#'
#' @description
#' A restrained, publication-ready ggplot2 theme with viridis defaults.
#'
#' @param base_size Base font size in points.
#' @param base_family Base font family.
#' @param dark Logical; use dark mode?
#' @param ... Additional arguments passed to [ggplot2::theme()].
#'
#' @return A `ggplot2::theme` object.
#'
#' @family plots
#' @export
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) + geom_point() + sm_theme()
sm_theme <- function(base_size = 11, base_family = "", dark = FALSE, ...) {
  if (dark) {
    bg <- "#0e0e0e"
    fg <- "#e8e8e8"
    grid_col <- "#2a2a2a"
    border_col <- "#555555"
  } else {
    bg <- "#ffffff"
    fg <- "#1a1a1a"
    grid_col <- "#e5e5e5"
    border_col <- "#cccccc"
  }

  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = bg, colour = NA),
      panel.background = ggplot2::element_rect(fill = bg, colour = NA),
      panel.grid.major = ggplot2::element_line(colour = grid_col, linewidth = 0.3),
      panel.grid.minor = ggplot2::element_blank(),
      panel.border = ggplot2::element_rect(colour = border_col,
                                            fill = NA, linewidth = 0.5),
      axis.text = ggplot2::element_text(colour = fg),
      axis.title = ggplot2::element_text(colour = fg),
      plot.title = ggplot2::element_text(colour = fg, face = "bold",
                                          size = base_size * 1.2),
      plot.subtitle = ggplot2::element_text(colour = fg),
      plot.caption = ggplot2::element_text(colour = fg, face = "italic",
                                            size = base_size * 0.8),
      legend.background = ggplot2::element_rect(fill = bg, colour = NA),
      legend.text = ggplot2::element_text(colour = fg),
      legend.title = ggplot2::element_text(colour = fg),
      strip.background = ggplot2::element_rect(fill = NA, colour = NA),
      strip.text = ggplot2::element_text(colour = fg, face = "bold"),
      ...
    )
}

#' Viridis colour scale for scimapR
#'
#' @description
#' Wraps viridis with sensible defaults for scimapR plots.
#'
#' @param option Viridis palette option. One of `"viridis"`, `"magma"`,
#'   `"plasma"`, `"cividis"`, `"inferno"`, `"mako"`, `"rocket"`, `"turbo"`.
#' @param discrete Logical; discrete or continuous scale?
#' @param ... Additional arguments passed to the viridis scale function.
#'
#' @return A ggplot2 scale object.
#'
#' @family plots
#' @export
sm_scale_color <- function(option = "viridis", discrete = TRUE, ...) {
  opt <- substr(option, 1, 1)
  opt <- switch(tolower(option),
    viridis = "D", magma = "A", inferno = "B", plasma = "C",
    cividis = "E", mako = "G", rocket = "F", turbo = "H",
    toupper(substr(option, 1, 1))
  )

  if (discrete) {
    ggplot2::scale_colour_viridis_d(option = opt, end = 0.9, ...)
  } else {
    ggplot2::scale_colour_viridis_c(option = opt, end = 0.9, ...)
  }
}

#' @rdname sm_scale_color
#' @export
sm_scale_fill <- function(option = "viridis", discrete = TRUE, ...) {
  opt <- switch(tolower(option),
    viridis = "D", magma = "A", inferno = "B", plasma = "C",
    cividis = "E", mako = "G", rocket = "F", turbo = "H",
    toupper(substr(option, 1, 1))
  )

  if (discrete) {
    ggplot2::scale_fill_viridis_d(option = opt, end = 0.9, ...)
  } else {
    ggplot2::scale_fill_viridis_c(option = opt, end = 0.9, ...)
  }
}

#' Qualitative viridis palette
#'
#' @param n Number of colours.
#' @param option Viridis palette option.
#'
#' @return A character vector of hex colours.
#'
#' @family plots
#' @export
sm_palette_qualitative <- function(n, option = "D") {
  viridisLite::viridis(n, option = option, end = 0.9)
}

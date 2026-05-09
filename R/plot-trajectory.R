#' Plot author trajectory
#'
#' @description
#' Multi-panel visualization of an author's career trajectory.
#'
#' @param traj An `sm_trajectory` object.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object composed via patchwork.
#'
#' @family trajectory
#' @export
sm_plot_trajectory <- function(traj, dark = FALSE, ...) {
  if (!inherits(traj, "sm_trajectory")) {
    cli::cli_abort("{.arg traj} must be an {.cls sm_trajectory} object.")
  }
  rlang::check_installed("patchwork",
    reason = "to compose multi-panel trajectory plots.")

  p_h <- .plot_h_curve(traj, dark)
  p_prod <- .plot_prod_curve(traj, dark)
  p_collab <- sm_plot_collab_turnover(traj, dark = dark)

  patchwork::wrap_plots(p_prod, p_h, p_collab, ncol = 2) +
    patchwork::plot_annotation(
      title = paste("Trajectory:", traj$author_name),
      theme = sm_theme(dark = dark)
    )
}

.plot_h_curve <- function(traj, dark = FALSE) {
  dat <- traj$h_index_curve
  if (is.null(dat) || nrow(dat) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "h-index"))
  }

  ggplot2::ggplot(dat, ggplot2::aes(x = .data$year, y = .data$h_index)) +
    ggplot2::geom_line(colour = viridisLite::viridis(1), linewidth = 1) +
    ggplot2::geom_point(colour = viridisLite::viridis(1)) +
    sm_theme(dark = dark) +
    ggplot2::labs(title = "h-index Over Time", x = "Year", y = "h-index")
}

.plot_prod_curve <- function(traj, dark = FALSE) {
  dat <- traj$career_stages
  if (is.null(dat) || nrow(dat) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "Productivity"))
  }

  ggplot2::ggplot(dat, ggplot2::aes(x = .data$period, y = .data$n_works)) +
    ggplot2::geom_col(fill = viridisLite::viridis(1)) +
    sm_theme(dark = dark) +
    ggplot2::labs(title = "Productivity by Period",
                   x = "Period", y = "Works")
}

#' Plot topic pivots
#'
#' @description
#' Vertical timeline showing when an author's research focus shifted.
#'
#' @param traj An `sm_trajectory` object.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family trajectory
#' @export
sm_plot_topic_pivots <- function(traj, dark = FALSE, ...) {
  if (!inherits(traj, "sm_trajectory")) {
    cli::cli_abort("{.arg traj} must be an {.cls sm_trajectory} object.")
  }

  pivots <- traj$topic_pivots
  if (is.null(pivots) || nrow(pivots) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No topic pivots detected"))
  }

  ggplot2::ggplot(pivots, ggplot2::aes(
    x = 0, y = .data$year, colour = .data$pivot_score
  )) +
    ggplot2::geom_point(size = 4) +
    ggplot2::geom_segment(ggplot2::aes(
      x = -0.3, xend = 0.3, yend = .data$year
    )) +
    sm_scale_color(discrete = FALSE, option = "plasma") +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Topic Pivots",
      x = NULL, y = "Year", colour = "Pivot Strength"
    ) +
    ggplot2::theme(axis.text.x = ggplot2::element_blank())
}

#' Plot collaborator turnover
#'
#' @description
#' Visualise collaborator retention and turnover across career periods.
#'
#' @param traj An `sm_trajectory` object.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family trajectory
#' @export
sm_plot_collab_turnover <- function(traj, dark = FALSE, ...) {
  if (!inherits(traj, "sm_trajectory")) {
    cli::cli_abort("{.arg traj} must be an {.cls sm_trajectory} object.")
  }

  dat <- traj$collaborator_turnover
  if (is.null(dat) || nrow(dat) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No collaborator data"))
  }

  long <- tidyr::pivot_longer(dat,
    cols = c("n_new", "n_kept", "n_lost"),
    names_to = "type", values_to = "count"
  )

  ggplot2::ggplot(long, ggplot2::aes(
    x = .data$period, y = .data$count, fill = .data$type
  )) +
    ggplot2::geom_area(alpha = 0.8, position = "stack") +
    sm_scale_fill(discrete = TRUE) +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Collaborator Turnover",
      x = "Period", y = "Collaborators", fill = "Status"
    )
}

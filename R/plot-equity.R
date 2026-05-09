#' Plot equity dashboard
#'
#' @description
#' Four-panel visualization: geographic distribution, gender mix, funding
#' sources, and OA evolution. Uses viridis throughout.
#'
#' @param corpus An `sm_corpus`.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object composed via patchwork.
#'
#' @family plots
#' @export
#' @examplesIf requireNamespace("patchwork", quietly = TRUE)
#' corpus <- sm_example_corpus()
#' sm_plot_equity_dashboard(corpus)
sm_plot_equity_dashboard <- function(corpus, dark = FALSE, ...) {
  .check_sm_corpus(corpus)
  rlang::check_installed("patchwork",
    reason = "to compose multi-panel dashboards.")

  p_geo <- .plot_equity_geographic(corpus, dark = dark)
  p_oa <- .plot_equity_oa(corpus, dark = dark)
  p_type <- .plot_equity_type(corpus, dark = dark)
  p_prod <- .plot_equity_productivity(corpus, dark = dark)

  patchwork::wrap_plots(p_geo, p_oa, p_type, p_prod, ncol = 2) +
    patchwork::plot_annotation(
      title = "Equity & Representation Dashboard",
      theme = sm_theme(dark = dark)
    )
}

.plot_equity_geographic <- function(corpus, dark = FALSE) {
  countries <- corpus$authorships %>%
    dplyr::filter(!is.na(.data$country_code)) %>%
    dplyr::distinct(.data$work_id, .data$country_code) %>%
    dplyr::count(.data$country_code, name = "n", sort = TRUE) %>%
    utils::head(15)

  if (nrow(countries) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "Geographic Distribution",
                            subtitle = "No country data"))
  }

  countries$country_code <- factor(countries$country_code,
                                    levels = rev(countries$country_code))

  ggplot2::ggplot(countries,
    ggplot2::aes(x = .data$n, y = .data$country_code)
  ) +
    ggplot2::geom_col(fill = viridisLite::viridis(1)) +
    sm_theme(dark = dark) +
    ggplot2::labs(title = "Geographic Distribution",
                   x = "Works", y = NULL)
}

.plot_equity_oa <- function(corpus, dark = FALSE) {
  oa <- corpus$works %>%
    dplyr::filter(!is.na(.data$oa_status)) %>%
    dplyr::count(.data$oa_status, name = "n")

  if (nrow(oa) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "OA Status", subtitle = "No data"))
  }

  ggplot2::ggplot(oa, ggplot2::aes(x = .data$oa_status, y = .data$n,
                                    fill = .data$oa_status)) +
    ggplot2::geom_col() +
    sm_scale_fill(discrete = TRUE) +
    sm_theme(dark = dark) +
    ggplot2::labs(title = "Open Access Status", x = NULL, y = "Works") +
    ggplot2::theme(legend.position = "none")
}

.plot_equity_type <- function(corpus, dark = FALSE) {
  types <- corpus$works %>%
    dplyr::filter(!is.na(.data$type)) %>%
    dplyr::count(.data$type, name = "n", sort = TRUE)

  if (nrow(types) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "Document Types", subtitle = "No data"))
  }

  ggplot2::ggplot(types, ggplot2::aes(x = .data$n, y = stats::reorder(.data$type, .data$n),
                                       fill = .data$type)) +
    ggplot2::geom_col() +
    sm_scale_fill(discrete = TRUE) +
    sm_theme(dark = dark) +
    ggplot2::labs(title = "Document Types", x = "Count", y = NULL) +
    ggplot2::theme(legend.position = "none")
}

.plot_equity_productivity <- function(corpus, dark = FALSE) {
  yearly <- corpus$works %>%
    dplyr::filter(!is.na(.data$year)) %>%
    dplyr::count(.data$year, name = "n")

  if (nrow(yearly) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "Production Trend", subtitle = "No data"))
  }

  ggplot2::ggplot(yearly, ggplot2::aes(x = .data$year, y = .data$n)) +
    ggplot2::geom_line(colour = viridisLite::viridis(1), linewidth = 1) +
    ggplot2::geom_point(colour = viridisLite::viridis(1), size = 2) +
    sm_theme(dark = dark) +
    ggplot2::labs(title = "Annual Production", x = "Year", y = "Works")
}

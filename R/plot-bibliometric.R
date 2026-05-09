#' Plot annual scientific production
#'
#' @description
#' Bar chart of publication counts over time.
#'
#' @param corpus An `sm_corpus` object.
#' @param by Time unit: `"year"` or `"month"`.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments (currently unused).
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_plot_production(corpus)
sm_plot_production <- function(corpus, by = c("year", "month"),
                               dark = FALSE, ...) {
  .check_sm_corpus(corpus)
  by <- match.arg(by)

  works <- corpus$works
  if (nrow(works) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No works to plot"))
  }

  counts <- works %>%
    dplyr::filter(!is.na(.data$year)) %>%
    dplyr::count(.data$year, name = "n")

  ggplot2::ggplot(counts, ggplot2::aes(x = .data$year, y = .data$n)) +
    ggplot2::geom_col(fill = viridisLite::viridis(1, option = "D")) +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Annual Scientific Production",
      x = "Year", y = "Number of Publications"
    )
}

#' Plot Lotka's law
#'
#' @description
#' Frequency distribution of author productivity compared to Lotka's law.
#'
#' @param corpus An `sm_corpus`.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
sm_plot_lotka <- function(corpus, dark = FALSE, ...) {
  .check_sm_corpus(corpus)

  prod <- corpus$authorships %>%
    dplyr::distinct(.data$work_id, .data$author_id) %>%
    dplyr::count(.data$author_id, name = "n_works") %>%
    dplyr::count(.data$n_works, name = "n_authors")

  if (nrow(prod) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No data for Lotka's law"))
  }

  prod <- dplyr::mutate(prod,
    proportion = .data$n_authors / sum(.data$n_authors)
  )

  ggplot2::ggplot(prod, ggplot2::aes(x = .data$n_works,
                                      y = .data$proportion)) +
    ggplot2::geom_point(colour = viridisLite::viridis(1)) +
    ggplot2::geom_line(colour = viridisLite::viridis(1)) +
    ggplot2::scale_x_log10() +
    ggplot2::scale_y_log10() +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Lotka's Law",
      x = "Number of Publications (log)",
      y = "Proportion of Authors (log)"
    )
}

#' Plot Bradford's law
#'
#' @description
#' Source productivity distribution following Bradford's law of scattering.
#'
#' @param corpus An `sm_corpus`.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
sm_plot_bradford <- function(corpus, dark = FALSE, ...) {
  .check_sm_corpus(corpus)

  src_counts <- corpus$works %>%
    dplyr::filter(!is.na(.data$source_id)) %>%
    dplyr::count(.data$source_id, name = "n") %>%
    dplyr::arrange(dplyr::desc(.data$n)) %>%
    dplyr::mutate(
      rank = dplyr::row_number(),
      cumulative = cumsum(.data$n)
    )

  if (nrow(src_counts) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No source data for Bradford's law"))
  }

  ggplot2::ggplot(src_counts, ggplot2::aes(x = log(.data$rank),
                                            y = .data$cumulative)) +
    ggplot2::geom_line(colour = viridisLite::viridis(1)) +
    ggplot2::geom_point(colour = viridisLite::viridis(1), size = 1) +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Bradford's Law",
      x = "log(Source Rank)", y = "Cumulative Articles"
    )
}

#' Plot top entities
#'
#' @description
#' Horizontal bar chart of top authors, sources, institutions, or countries.
#'
#' @param corpus An `sm_corpus`.
#' @param level Entity level.
#' @param n Number of top entities to show.
#' @param metric Ranking metric.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' sm_plot_top(corpus, level = "authors", n = 10)
sm_plot_top <- function(corpus,
                        level = c("authors", "sources", "institutions",
                                  "countries"),
                        n = 20L,
                        metric = c("count", "citations"),
                        dark = FALSE, ...) {
  .check_sm_corpus(corpus)
  level <- match.arg(level)
  metric <- match.arg(metric)

  dat <- switch(level,
    authors = {
      corpus$authorships %>%
        dplyr::distinct(.data$work_id, .data$author_id) %>%
        dplyr::left_join(
          dplyr::select(corpus$authors, "author_id", name = "display_name"),
          by = "author_id"
        ) %>%
        dplyr::count(.data$name, name = "count", sort = TRUE) %>%
        utils::head(n)
    },
    sources = {
      corpus$works %>%
        dplyr::filter(!is.na(.data$source_id)) %>%
        dplyr::left_join(
          dplyr::select(corpus$sources, "source_id", name = "display_name"),
          by = "source_id"
        ) %>%
        dplyr::count(.data$name, name = "count", sort = TRUE) %>%
        utils::head(n)
    },
    institutions = {
      corpus$authorships %>%
        dplyr::filter(!is.na(.data$institution_id)) %>%
        dplyr::distinct(.data$work_id, .data$institution_id) %>%
        dplyr::left_join(
          dplyr::select(corpus$institutions, "institution_id",
                         name = "display_name"),
          by = "institution_id"
        ) %>%
        dplyr::count(.data$name, name = "count", sort = TRUE) %>%
        utils::head(n)
    },
    countries = {
      corpus$authorships %>%
        dplyr::filter(!is.na(.data$country_code)) %>%
        dplyr::distinct(.data$work_id, .data$country_code) %>%
        dplyr::count(.data$country_code, name = "count", sort = TRUE) %>%
        dplyr::rename(name = "country_code") %>%
        utils::head(n)
    }
  )

  if (nrow(dat) == 0 || all(is.na(dat$name))) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = paste("No", level, "data")))
  }

  dat <- dplyr::filter(dat, !is.na(.data$name))
  dat$name <- factor(dat$name, levels = rev(dat$name))

  ggplot2::ggplot(dat, ggplot2::aes(x = .data$count, y = .data$name)) +
    ggplot2::geom_col(fill = viridisLite::viridis(1)) +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = paste("Top", n, tools::toTitleCase(level)),
      x = tools::toTitleCase(metric), y = NULL
    )
}

#' Plot Heaps' law
#'
#' @description
#' Vocabulary growth curve over accumulated documents.
#'
#' @param corpus An `sm_corpus`.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
sm_plot_heaps <- function(corpus, dark = FALSE, ...) {
  .check_sm_corpus(corpus)

  words <- corpus$works %>%
    dplyr::filter(!is.na(.data$title)) %>%
    dplyr::arrange(.data$year) %>%
    dplyr::pull(.data$title) %>%
    paste(collapse = " ") %>%
    tolower() %>%
    strsplit("\\s+") %>%
    unlist()

  if (length(words) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No text for Heaps' law"))
  }

  steps <- unique(c(
    seq(1, length(words), by = max(1, length(words) %/% 200)),
    length(words)
  ))

  vocab <- vapply(steps, function(i) {
    length(unique(words[seq_len(i)]))
  }, integer(1))

  dat <- tibble::tibble(n_words = steps, vocab_size = vocab)

  ggplot2::ggplot(dat, ggplot2::aes(x = .data$n_words,
                                     y = .data$vocab_size)) +
    ggplot2::geom_line(colour = viridisLite::viridis(1)) +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Heaps' Law (Vocabulary Growth)",
      x = "Total Words", y = "Unique Words"
    )
}

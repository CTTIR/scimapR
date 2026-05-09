#' Plot thematic map (Callon centrality-density)
#'
#' @description
#' Strategic diagram plotting clusters by centrality (external links) and
#' density (internal links), following Callon et al.
#'
#' @param corpus An `sm_corpus` with clusters.
#' @param by Grouping variable. Default `"cluster_id"`.
#' @param dark Logical; dark mode?
#' @param ... Additional arguments.
#'
#' @return A `ggplot` object.
#'
#' @family plots
#' @export
sm_plot_thematic_map <- function(corpus, by = "cluster_id",
                                  dark = FALSE, ...) {
  .check_sm_corpus(corpus)
  rlang::check_installed("ggrepel",
    reason = "to label clusters in thematic maps.")

  if (!by %in% names(corpus$works)) {
    cli::cli_abort("Column {.field {by}} not found in works. Run clustering first.")
  }

  works_cl <- corpus$works %>%
    dplyr::filter(!is.na(.data[[by]]))

  if (nrow(works_cl) == 0) {
    return(ggplot2::ggplot() + sm_theme(dark = dark) +
             ggplot2::labs(title = "No cluster data"))
  }

  cluster_stats <- works_cl %>%
    dplyr::group_by(.data[[by]]) %>%
    dplyr::summarise(
      n_works = dplyr::n(),
      mean_citations = mean(.data$cited_by_count, na.rm = TRUE),
      .groups = "drop"
    )

  callon <- .callon_from_concepts(works_cl, corpus$concepts, by)
  if (!is.null(callon)) {
    cluster_stats <- dplyr::left_join(cluster_stats, callon, by = by)
  } else {
    max_cit <- max(cluster_stats$mean_citations, na.rm = TRUE)
    max_n <- max(cluster_stats$n_works)
    cluster_stats$centrality <- if (max_cit > 0) {
      cluster_stats$mean_citations / max_cit
    } else {
      0.5
    }
    cluster_stats$density <- if (max_n > 0) {
      cluster_stats$n_works / max_n
    } else {
      0.5
    }
  }

  med_c <- stats::median(cluster_stats$centrality)
  med_d <- stats::median(cluster_stats$density)

  ggplot2::ggplot(cluster_stats,
    ggplot2::aes(x = .data$centrality, y = .data$density,
                 size = .data$n_works)
  ) +
    ggplot2::geom_point(colour = viridisLite::viridis(1), alpha = 0.7) +
    ggplot2::geom_vline(xintercept = med_c, linetype = "dashed",
                         colour = "grey50") +
    ggplot2::geom_hline(yintercept = med_d, linetype = "dashed",
                         colour = "grey50") +
    ggrepel::geom_text_repel(
      ggplot2::aes(label = .data[[by]]),
      size = 3, max.overlaps = 20
    ) +
    sm_theme(dark = dark) +
    ggplot2::labs(
      title = "Thematic Map (Strategic Diagram)",
      x = "Centrality (relevance)", y = "Density (development)",
      size = "Works"
    )
}

#' Compute Callon centrality and density from concept overlap
#' @noRd
.callon_from_concepts <- function(works_cl, concepts, by) {
  cc <- concepts %>%
    dplyr::inner_join(
      works_cl %>% dplyr::select("work_id", dplyr::all_of(by)),
      by = "work_id"
    )
  if (nrow(cc) == 0) return(NULL)

  cluster_concepts <- cc %>%
    dplyr::distinct(.data[[by]], .data$concept_name)

  clusters <- unique(cluster_concepts[[by]])
  if (length(clusters) < 2L) return(NULL)

  callon <- purrr::map_dfr(clusters, function(cl) {
    my <- unique(cluster_concepts$concept_name[cluster_concepts[[by]] == cl])
    others <- unique(cluster_concepts$concept_name[cluster_concepts[[by]] != cl])
    n_mine <- length(my)
    n_shared <- length(intersect(my, others))
    n_wk <- sum(works_cl[[by]] == cl)
    tibble::tibble(
      .cluster = cl,
      centrality = if (n_mine > 0) n_shared / n_mine else 0,
      density = n_mine / max(n_wk, 1L)
    )
  })
  names(callon)[1L] <- by
  callon
}

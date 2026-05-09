#' @rdname sm_author_trajectory
#' @param x An `sm_trajectory` object.
#' @param ... Ignored.
#' @return
#'   - `print()`: `x` invisibly.
#'   - `format()`: A single character string.
#' @export
print.sm_trajectory <- function(x, ...) {
  cli::cli_h1("<sm_trajectory>")

  cli::cli_text("{.strong Author:} {x$author_name}")
  cli::cli_text("{.strong Author ID:} {x$author_id}")
  if (!is.na(x$orcid)) {
    cli::cli_text("{.strong ORCID:} {x$orcid}")
  }
  cli::cli_text("{.strong Periods:} {x$n_periods}")
  cli::cli_text("")

  # Career stages
  if (nrow(x$career_stages) > 0L) {
    cli::cli_h3("Career stages")
    for (i in seq_len(nrow(x$career_stages))) {
      row <- x$career_stages[i, ]
      topics <- unlist(row$dominant_topics)
      topic_txt <- if (length(topics) > 0L) {
        paste(topics, collapse = ", ")
      } else {
        "(no topics)"
      }
      cli::cli_text(
        "  Period {row$period} ({row$year_range}): {row$n_works} works, h={row$h_index} | {topic_txt}"
      )
    }
    cli::cli_text("")
  }

  # Topic pivots
  if (nrow(x$topic_pivots) > 0L) {
    cli::cli_h3("Topic pivots")
    for (i in seq_len(nrow(x$topic_pivots))) {
      row <- x$topic_pivots[i, ]
      pivot_txt <- if (!is.na(row$from_topic) && !is.na(row$to_topic)) {
        paste0(row$from_topic, " -> ", row$to_topic)
      } else {
        "(stable)"
      }
      cli::cli_text(
        "  Period {row$period}: score={row$pivot_score} {pivot_txt}"
      )
    }
    cli::cli_text("")
  }

  # Collaborator turnover
  if (nrow(x$collaborator_turnover) > 0L) {
    cli::cli_h3("Collaborator turnover")
    for (i in seq_len(nrow(x$collaborator_turnover))) {
      row <- x$collaborator_turnover[i, ]
      cli::cli_text(
        "  Period {row$period}: Jaccard={row$jaccard_to_prev} (new={row$n_new}, kept={row$n_kept}, lost={row$n_lost})"
      )
    }
    cli::cli_text("")
  }

  # Emerging collaborators
  if (nrow(x$emerging_collaborators) > 0L) {
    n_em <- nrow(x$emerging_collaborators)
    cli::cli_h3("Emerging collaborators ({n_em})")
    shown <- utils::head(x$emerging_collaborators, 5L)
    for (i in seq_len(nrow(shown))) {
      cli::cli_text(
        "  {shown$display_name[i]} (since {shown$first_year[i]})"
      )
    }
    if (n_em > 5L) {
      cli::cli_text("  ... and {n_em - 5L} more")
    }
    cli::cli_text("")
  }

  # H-index curve
  if (nrow(x$h_index_curve) > 0L) {
    cli::cli_h3("H-index curve")
    h_vals <- paste0(
      x$h_index_curve$year_range, ":", x$h_index_curve$h_index
    )
    cli::cli_text("  {paste(h_vals, collapse = ' -> ')}")
    cli::cli_text("")
  }

  # Citation acceleration
  if (nrow(x$citation_acceleration) > 0L) {
    cli::cli_h3("Citation acceleration")
    for (i in seq_len(nrow(x$citation_acceleration))) {
      row <- x$citation_acceleration[i, ]
      delta_sign <- if (!is.na(row$delta_vs_field) && row$delta_vs_field >= 0) "+" else ""
      cli::cli_text(
        "  {row$year_range}: mean={row$mean_citations} ({delta_sign}{row$delta_vs_field} vs field)"
      )
    }
  }

  invisible(x)
}

#' @rdname sm_author_trajectory
#' @export
format.sm_trajectory <- function(x, ...) {
  paste0(
    "<sm_trajectory> ", x$author_name,
    " (", x$n_periods, " periods, ",
    sum(x$career_stages$n_works, na.rm = TRUE), " works)"
  )
}

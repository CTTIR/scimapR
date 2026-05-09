#' Generate PRISMA flow diagram
#'
#' @description
#' Create a PRISMA 2020-compatible flow diagram from corpus screening data.
#'
#' @param corpus An `sm_corpus` with screening decisions.
#' @param decisions Optional external decisions tibble.
#' @param stages Stage names for the flow.
#'
#' @return A list with `$counts` (tibble) and `$plot` (ggplot).
#'
#' @family screening
#' @export
#' @examples
#' corpus <- sm_example_corpus(with_screening = TRUE)
#' prisma <- sm_screen_prisma(corpus)
#' prisma$counts
sm_screen_prisma <- function(corpus,
                             decisions = NULL,
                             stages = c("identification", "screening",
                                        "eligibility", "inclusion")) {
  .check_sm_corpus(corpus)

  scr <- corpus$screening
  if (!is.null(decisions)) {
    scr <- dplyr::bind_rows(scr, decisions)
  }

  n_total <- nrow(corpus$works)

  counts <- tibble::tibble(
    stage = stages,
    n_entering = NA_integer_,
    n_excluded = NA_integer_,
    n_remaining = NA_integer_
  )

  counts$n_entering[1] <- n_total
  remaining <- n_total

  for (i in seq_along(stages)) {
    stage_decisions <- dplyr::filter(scr, .data$stage == stages[i])
    n_excluded <- sum(stage_decisions$decision == "exclude", na.rm = TRUE)
    counts$n_entering[i] <- remaining
    counts$n_excluded[i] <- as.integer(n_excluded)
    remaining <- remaining - n_excluded
    counts$n_remaining[i] <- as.integer(remaining)
  }

  p <- ggplot2::ggplot(counts,
    ggplot2::aes(x = factor(.data$stage, levels = stages),
                 y = .data$n_remaining)
  ) +
    ggplot2::geom_col(fill = viridisLite::viridis(1)) +
    ggplot2::geom_text(ggplot2::aes(label = .data$n_remaining),
                        vjust = -0.5, size = 3) +
    sm_theme() +
    ggplot2::labs(
      title = "PRISMA Flow",
      x = "Stage", y = "Records Remaining"
    )

  list(counts = counts, plot = p)
}

#' Export corpus for Rayyan
#'
#' @description
#' Write corpus works in RIS format for import into Rayyan.
#'
#' @param corpus An `sm_corpus`.
#' @param path Output file path.
#'
#' @return `path` invisibly.
#'
#' @family screening
#' @export
sm_export_rayyan <- function(corpus, path) {
  .check_sm_corpus(corpus)

  lines <- character()
  for (i in seq_len(nrow(corpus$works))) {
    w <- corpus$works[i, ]
    lines <- c(lines,
      "TY  - JOUR",
      paste0("TI  - ", w$title %||% ""),
      paste0("PY  - ", w$year %||% ""),
      paste0("DO  - ", w$doi %||% ""),
      paste0("AB  - ", w$abstract %||% ""),
      "ER  - ",
      ""
    )
  }

  writeLines(lines, path)
  .sm_done("Exported {nrow(corpus$works)} works to {.path {path}}")
  invisible(path)
}

#' Import screening decisions from Rayyan
#'
#' @description
#' Read Rayyan CSV export and parse screening decisions.
#'
#' @param path Path to Rayyan CSV export.
#'
#' @return A tibble of screening decisions.
#'
#' @family screening
#' @export
sm_import_rayyan <- function(path) {
  .check_file_exists(path)

  dat <- readr::read_csv(path, show_col_types = FALSE)

  tibble::tibble(
    work_id = NA_character_,
    stage = "title-abstract",
    decision = if ("decision" %in% names(dat)) dat$decision else NA_character_,
    reason = if ("reason" %in% names(dat)) dat$reason else NA_character_,
    confidence = NA_real_,
    source = "rayyan",
    decided_at = Sys.time()
  )
}

#' Export corpus for Covidence
#'
#' @description
#' Write corpus works in RIS format for Covidence import.
#'
#' @param corpus An `sm_corpus`.
#' @param path Output file path.
#'
#' @return `path` invisibly.
#'
#' @family screening
#' @export
sm_export_covidence <- function(corpus, path) {
  sm_export_rayyan(corpus, path)
}

#' Merge external screening decisions into corpus
#'
#' @description
#' Add external screening decisions (from Rayyan, Covidence, or manual
#' spreadsheet) into the corpus screening table.
#'
#' @param corpus An `sm_corpus`.
#' @param decisions A tibble with screening decisions.
#'
#' @return An `sm_corpus` with updated screening.
#'
#' @family screening
#' @export
sm_merge_screening_decisions <- function(corpus, decisions) {
  .check_sm_corpus(corpus)

  corpus$screening <- dplyr::bind_rows(corpus$screening, decisions)
  corpus
}

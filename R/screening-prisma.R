#' Generate PRISMA flow diagram
#'
#' @description
#' Create a PRISMA 2020-compatible flow diagram from corpus screening data.
#'
#' @param corpus An `sm_corpus` with screening decisions.
#' @param decisions Optional external decisions tibble.
#' @param stages Stage names in flow order. Defaults to identification,
#'   title-abstract, full-text and inclusion. Only current works still in the
#'   flow count; each stage uses the latest decision per work.
#' @param n_identified Whole count before deduplication and other removals,
#'   at least the corpus size. Defaults to `metadata$n_identified` when set,
#'   otherwise the corpus size. Ignored without an identification stage.
#'
#' @return A list with `$counts` (tibble) and `$plot` (ggplot).
#'
#' @family screening
#' @export
#' @examples
#' corpus <- sm_example_corpus(with_screening = TRUE)
#' prisma <- sm_screen_prisma(corpus)
#' prisma$counts
sm_screen_prisma <- function(corpus, decisions = NULL,
                             stages = c("identification", "title-abstract",
                                        "full-text", "inclusion"),
                             n_identified = NULL) {
  .check_sm_corpus(corpus)
  scr <- dplyr::bind_rows(corpus$screening, decisions)
  unknown <- !scr$work_id %in% corpus$works$work_id
  n <- sum(unknown)
  if (n > 0L) {
    cli::cli_warn("Dropped {n} screening row{?s} for works outside the corpus.",
                  class = "scimapR_prisma_unknown_works")
    scr <- scr[!unknown, ]
  }
  omitted <- setdiff(unique(scr$stage), stages)
  if (length(omitted) || (nrow(scr) && !any(scr$stage %in% stages))) {
    lines <- c("Screening stages left out of the flow: {.val {omitted}}.")
    if (!any(scr$stage %in% stages)) {
      lines <- c(lines, "i" = "No rows match requested stages {.val {stages}}.")
    }
    if ("regex" %in% omitted) {
      hint <- paste0("For regex decisions use {.code stages = ",
                     "c(\"identification\", \"regex\", \"inclusion\")}.")
      lines <- c(lines, "i" = hint)
    }
    cli::cli_warn(lines, class = "scimapR_prisma_unmatched_stages")
  }
  n_total <- nrow(corpus$works)
  loss <- 0L
  if ("identification" %in% stages) {
    identified <- n_identified %||% corpus$metadata$n_identified %||% n_total
    valid <- is.numeric(identified) && length(identified) == 1L &&
      is.finite(identified) && identified == floor(identified) &&
      identified >= n_total && identified <= .Machine$integer.max
    if (!valid) {
      cli::cli_abort(
        "{.arg n_identified} must be a whole count at least {n_total}.",
        class = "scimapR_invalid_n_identified"
      )
    }
    loss <- as.integer(identified) - n_total
  }
  counts <- tibble::tibble(
    stage = stages, n_entering = rep(NA_integer_, length(stages)),
    n_excluded = NA_integer_, n_remaining = NA_integer_
  )
  flow <- unique(corpus$works$work_id)
  for (i in seq_along(stages)) {
    stage <- stages[i]
    latest <- .screening_latest(scr, stage)
    excluded <- intersect(flow, latest$work_id[
      latest$decision %in% "exclude" &
        !latest$source %in% .screening_failed_sources
    ])
    removed <- if (stage == "identification") loss else 0L
    counts$n_entering[i] <- as.integer(length(flow) + removed)
    counts$n_excluded[i] <- as.integer(length(excluded) + removed)
    flow <- setdiff(flow, excluded)
    counts$n_remaining[i] <- as.integer(length(flow))
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
#' Write corpus works in RIS format for import into Rayyan. Work IDs appear
#' in the RIS ID field and a note; missing fields are omitted.
#'
#' @param corpus An `sm_corpus`.
#' @param path Output file path.
#'
#' @return `path` invisibly.
#' @details Keep the ID or the scimapR work_id note when exporting decisions.
#' @examples
#' path <- tempfile(fileext = ".ris")
#' sm_export_rayyan(sm_example_corpus(n_works = 2), path)
#' readLines(path, n = 3)
#' unlink(path)
#'
#' @family screening
#' @export
sm_export_rayyan <- function(corpus, path) {
  .check_sm_corpus(corpus)

  lines <- character()
  for (i in seq_len(nrow(corpus$works))) {
    w <- corpus$works[i, ]
    lines <- c(lines, "TY  - JOUR", paste0("ID  - ", w$work_id))
    fields <- c(TI = "title", PY = "year", DO = "doi", AB = "abstract")
    for (tag in names(fields)) {
      value <- w[[fields[[tag]]]]
      if (length(value) == 1L && !is.na(value) && nzchar(as.character(value))) {
        lines <- c(lines, paste0(tag, "  - ", value))
      }
    }
    lines <- c(lines, paste0("N1  - scimapR work_id: ", w$work_id),
               "ER  - ", "")
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
#' @param corpus Optional corpus for DOI matching and ID validation.
#' @param id_col Optional name of the CSV column containing work IDs.
#'
#' @return One screening row per CSV record. Unmatched work IDs remain
#'   missing and warn. Decisions use include, exclude and uncertain.
#' @details IDs come from the named column, otherwise from the scimapR
#'   work_id note, or from unique matching corpus DOIs. Decisions and reasons
#'   come from their columns or Rayyan inclusion and exclusion notes.
#'   Disagreeing reviewers give an uncertain decision.
#' @examples
#' path <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(id = "paper-a", decision = "Included"),
#'                  path, row.names = FALSE)
#' sm_import_rayyan(path, id_col = "id")
#' unlink(path)
#'
#' @family screening
#' @export
sm_import_rayyan <- function(path, corpus = NULL, id_col = NULL) {
  .check_file_exists(path)
  if (!is.null(corpus)) .check_sm_corpus(corpus)
  dat <- readr::read_csv(
    path, show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
  n <- nrow(dat)
  column <- function(name) {
    hit <- match(tolower(name), tolower(names(dat)))
    if (is.na(hit)) rep(NA_character_, n) else dat[[hit]]
  }
  texts <- vapply(seq_len(n), function(i) {
    paste(vapply(dat, function(x) x[i] %||% "", character(1)), collapse = " | ")
  }, character(1))
  if (!is.null(id_col)) {
    if (length(id_col) != 1L || !id_col %in% names(dat)) {
      cli::cli_abort("{.arg id_col} must name a column in the CSV.",
                     class = "scimapR_rayyan_id_column")
    }
    ids <- dat[[id_col]]
  } else {
    ids <- .rayyan_note_field(texts, "scimapR work_id: (\\S+)")
    if (!is.null(corpus)) {
      doi <- .normalize_doi(column("doi"))
      known <- .normalize_doi(corpus$works$doi)
      ambiguous <- duplicated(known) | duplicated(known, fromLast = TRUE)
      known[ambiguous | is.na(known)] <- NA_character_
      hit <- match(doi, known)
      use <- is.na(ids) & !is.na(doi) & !is.na(hit)
      ids[use] <- corpus$works$work_id[hit[use]]
    }
  }
  ids <- trimws(ids)
  ids[!is.na(ids) & !nzchar(ids)] <- NA_character_
  if (!is.null(corpus)) ids[!ids %in% corpus$works$work_id] <- NA_character_
  unmatched <- sum(is.na(ids))
  if (unmatched) {
    cli::cli_warn("Could not match {unmatched} Rayyan record{?s} to works.",
                  class = "scimapR_rayyan_unmatched")
  }
  decision <- if ("decision" %in% tolower(names(dat))) {
    .normalize_screening_decision(column("decision"))
  } else {
    vapply(texts, .rayyan_note_decision, character(1), USE.NAMES = FALSE)
  }
  reason <- if ("reason" %in% tolower(names(dat))) {
    column("reason")
  } else {
    .rayyan_note_field(texts, "RAYYAN-EXCLUSION-REASONS:\\s*([^|]*)")
  }
  out <- .empty_screening()
  if (!n) return(out)
  tibble::tibble(work_id = ids, stage = "title-abstract", decision = decision,
                 reason = reason, confidence = NA_real_, source = "rayyan",
                 decided_at = Sys.time())
}

.rayyan_note_field <- function(text, pattern) {
  matches <- regexec(pattern, text, perl = TRUE)
  vapply(regmatches(text, matches), function(x) {
    if (length(x) > 1L) trimws(x[2]) else NA_character_
  }, character(1))
}

.rayyan_note_decision <- function(text) {
  block <- .rayyan_note_field(text, "RAYYAN-INCLUSION:\\s*(\\{[^}]*\\})")
  if (is.na(block)) return(NA_character_)
  matches <- regmatches(block, gregexpr("=>\\s*[\"'][^\"']+[\"']", block,
                                        perl = TRUE))[[1]]
  if (!length(matches)) return(NA_character_)
  labels <- sub("^=>\\s*[\"'](.*)[\"']$", "\\1", matches, perl = TRUE)
  decisions <- unique(.normalize_screening_decision(labels))
  if (length(decisions) == 1L) decisions else "uncertain"
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
  .check_corpus_unlocked(corpus)

  normal <- .normalize_screening_decision(decisions$decision)
  unknown <- !is.na(decisions$decision) & is.na(normal)
  if (any(unknown)) {
    labels <- unique(decisions$decision[unknown])
    cli::cli_warn(
      "Unknown screening decisions: {.val {labels}}.",
      class = "scimapR_screening_unknown_decisions", labels = labels
    )
    normal[unknown] <- as.character(decisions$decision[unknown])
  }
  decisions$decision <- normal
  corpus$screening <- dplyr::bind_rows(corpus$screening, decisions)
  corpus
}

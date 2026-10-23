# Screening decision helpers (internal)

.valid_screening_stages <- c("identification", "title-abstract",
                              "full-text", "inclusion")

.valid_screening_decisions <- c("include", "exclude", "uncertain")

.validate_screening <- function(screening) {
  if (!tibble::is_tibble(screening)) {
    cli::cli_abort("{.arg screening} must be a tibble.")
  }

  required <- c("work_id", "stage", "decision")
  missing <- setdiff(required, names(screening))
  if (length(missing) > 0) {
    cli::cli_abort("Screening tibble missing columns: {.field {missing}}")
  }

  invisible(screening)
}


.screening_failed_sources <- c("llm_error", "llm_parse_error",
                               "llm_incomplete", "llm_misaligned")

.normalize_screening_decision <- function(x) {
  x <- tolower(trimws(as.character(x)))
  out <- rep(NA_character_, length(x))
  out[x %in% c("include", "included", "yes")] <- "include"
  out[x %in% c("exclude", "excluded", "no")] <- "exclude"
  out[x %in% c("uncertain", "unclear", "maybe", "undecided")] <- "uncertain"
  out
}

.screening_latest <- function(screening, stage) {
  out <- screening[screening$stage %in% stage, ]
  out$decision <- .normalize_screening_decision(out$decision)
  time <- out[["decided_at"]] %||% rep(NA_real_, nrow(out))
  out <- out[order(time, seq_len(nrow(out)), na.last = FALSE), ]
  out[!duplicated(out$work_id, fromLast = TRUE), ]
}

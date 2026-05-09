# Screening decision helpers (internal)

.valid_screening_stages <- c("identification", "title-abstract",
                              "full-text", "inclusion")

.valid_screening_decisions <- c("include", "exclude", "unclear")

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

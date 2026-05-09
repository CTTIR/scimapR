# Internal CLI message helpers

.sm_info <- function(..., .envir = rlang::caller_env()) {
  cli::cli_inform(c("i" = paste0(...)), .envir = .envir)
}

.sm_done <- function(..., .envir = rlang::caller_env()) {
  cli::cli_inform(c("v" = paste0(...)), .envir = .envir)
}

.sm_warn <- function(..., .envir = rlang::caller_env()) {
  cli::cli_warn(paste0(...), .envir = .envir)
}

.sm_verbose <- function(msg, verbose = TRUE, .envir = rlang::caller_env()) {
  if (isTRUE(verbose)) {
    cli::cli_inform(c("i" = msg), .envir = .envir)
  }
}

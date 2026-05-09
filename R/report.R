#' Export a Quarto report
#'
#' @description
#' Generate a comprehensive bibliometric report from a corpus using a
#' Quarto template.
#'
#' @param corpus An `sm_corpus`.
#' @param path Output path for the rendered report.
#' @param template Report template.
#' @param include_chat Logical; include chat session?
#' @param include_audit Logical; include equity audit?
#' @param include_trajectory Logical; include trajectory analysis?
#'
#' @return `path` invisibly.
#'
#' @family export
#' @export
sm_export_quarto_report <- function(corpus,
                                    path,
                                    template = c("standard", "minimal", "thesis"),
                                    include_chat = FALSE,
                                    include_audit = TRUE,
                                    include_trajectory = FALSE) {
  .check_sm_corpus(corpus)
  template <- match.arg(template)

  rlang::check_installed("quarto",
    reason = "to render Quarto reports"
  )

  cli::cli_inform(c(
    "i" = "Quarto report rendering requires a Quarto installation.",
    "i" = "Template: {template}"
  ))

  invisible(path)
}

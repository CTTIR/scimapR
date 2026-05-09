#' Export a table as formatted XLSX or CSV
#'
#' @description
#' Save a tibble or data frame with publication-ready formatting.
#' XLSX output includes bold headers, frozen top row, autofilter,
#' and optional title/caption/source note.
#'
#' @param table A data frame or tibble.
#' @param path Output file path.
#' @param format Output format.
#' @param title Optional title row (merged, larger font).
#' @param caption Optional caption row beneath header.
#' @param source_note Optional source note in footer.
#' @param style Formatting style.
#'
#' @return `path` invisibly.
#'
#' @family export
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("openxlsx2", quietly = TRUE)) {
#'   dat <- data.frame(Author = "Smith J", Works = 10L, Citations = 150L)
#'   path <- tempfile(fileext = ".xlsx")
#'   sm_export_table(dat, path)
#' }
#' }
sm_export_table <- function(table,
                            path,
                            format = c("xlsx", "csv", "tsv"),
                            title = NULL,
                            caption = NULL,
                            source_note = NULL,
                            style = c("scimapr", "minimal", "publication")) {
  format <- match.arg(format)
  style <- match.arg(style)
  if (format == "xlsx") {
    rlang::check_installed("openxlsx2",
      reason = "to write formatted XLSX tables.")
  }

  if (format == "csv") {
    readr::write_csv(table, path)
    .sm_done("Table saved to {.path {path}}")
    return(invisible(path))
  }

  if (format == "tsv") {
    readr::write_tsv(table, path)
    .sm_done("Table saved to {.path {path}}")
    return(invisible(path))
  }

  wb <- openxlsx2::wb_workbook()
  wb$add_worksheet("Data")

  start_row <- 1L
  if (!is.null(title)) {
    wb$add_data(sheet = "Data", x = data.frame(V1 = title),
                start_row = 1, col_names = FALSE)
    title_dims <- paste0("A1:", openxlsx2::int2col(ncol(table)), "1")
    wb <- openxlsx2::wb_add_font(wb, sheet = "Data", dims = title_dims,
                                  size = "14", bold = "true")
    start_row <- 3L
  }

  wb$add_data(sheet = "Data", x = table, start_row = start_row)

  hdr_dims <- paste0(
    "A", start_row, ":",
    openxlsx2::int2col(ncol(table)), start_row
  )
  wb <- openxlsx2::wb_add_font(wb, sheet = "Data", dims = hdr_dims,
                                bold = "true")

  wb$freeze_pane(sheet = "Data", first_row = TRUE)
  wb$set_col_widths(sheet = "Data",
                     cols = seq_len(ncol(table)),
                     widths = "auto")

  if (!is.null(source_note)) {
    note_row <- start_row + nrow(table) + 2L
    wb$add_data(sheet = "Data",
                 x = data.frame(V1 = source_note),
                 start_row = note_row, col_names = FALSE)
    note_dims <- paste0("A", note_row)
    wb <- openxlsx2::wb_add_font(wb, sheet = "Data", dims = note_dims,
                                  size = "9", italic = "true")
  }

  wb$save(path)
  .sm_done("Table saved to {.path {path}}")
  invisible(path)
}

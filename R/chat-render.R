#' Render a chat response
#'
#' @description
#' Converts an `sm_chat_response` object into a formatted document string.
#' The rendered output includes the question, answer with inline citations,
#' and a reference list. Supported formats are Markdown, HTML, and Quarto.
#'
#' @param response An `sm_chat_response` object from [sm_chat()].
#' @param format Character. Output format: `"markdown"`, `"html"`, or
#'   `"quarto"`.
#' @param call Caller environment for error reporting.
#'
#' @return A character string containing the rendered response. Printed
#'   to the console and returned invisibly.
#'
#' @family chat
#' @export
#' @examples
#' \donttest{
#' # Requires a chat response object:
#' # rendered <- sm_chat_render(response, format = "markdown")
#' # cat(rendered)
#' }
sm_chat_render <- function(response,
                           format = c("markdown", "html", "quarto"),
                           call = rlang::caller_env()) {
  if (!inherits(response, "sm_chat_response")) {
    cli::cli_abort(
      "{.arg response} must be an {.cls sm_chat_response} object.",
      call = call
    )
  }
  format <- match.arg(format)

  rendered <- switch(format,
    markdown = .render_chat_markdown(response$answer, response$citations,
                                     response),
    html = .render_chat_html(response$answer, response$citations,
                              response),
    quarto = .render_chat_quarto(response$answer, response$citations,
                                  response)
  )

  cli::cli_text(rendered)
  invisible(rendered)
}

#' Render chat as Markdown
#' @noRd
.render_chat_markdown <- function(text, citations, response) {
  # Replace cite tokens with footnote markers
  for (i in seq_len(nrow(citations))) {
    token <- citations$cite_token[i]
    ref <- paste0("**[", citations$work_id[i], "]**")
    text <- gsub(token, ref, text, fixed = TRUE)
  }

  lines <- c(
    "## Corpus Chat",
    "",
    paste0("**Question:** ", response$question),
    "",
    paste0("**Model:** ", response$model,
           " | **Retrieved:** ", nrow(response$retrieved_works), " works",
           " | **Method:** ", response$retrieve_method),
    "",
    "---",
    "",
    "### Answer",
    "",
    text,
    ""
  )

  if (nrow(citations) > 0L) {
    lines <- c(lines,
      "---",
      "",
      "### References",
      ""
    )
    for (i in seq_len(nrow(citations))) {
      row <- citations[i, ]
      lines <- c(lines,
        paste0("- **[", row$work_id, "]** ", row$snippet)
      )
    }
    lines <- c(lines, "")
  }

  lines <- c(lines,
    "---",
    paste0("*Prompt hash: `", substr(response$prompt_hash, 1, 12), "`",
           " | Generated: ",
           format(response$timestamp, "%Y-%m-%d %H:%M:%S"), "*")
  )

  paste(lines, collapse = "\n")
}

#' Render chat as HTML
#' @noRd
.render_chat_html <- function(text, citations, response) {
  # Replace cite tokens with tooltip spans
  for (i in seq_len(nrow(citations))) {
    token <- citations$cite_token[i]
    tooltip <- paste0(
      '<sup title="', citations$work_id[i], ': ',
      gsub('"', '&quot;', citations$snippet[i] %||% ""),
      '">[', i, ']</sup>'
    )
    text <- gsub(token, tooltip, text, fixed = TRUE)
  }

  text_html <- gsub("\n", "<br>\n", text)

  refs_html <- ""
  if (nrow(citations) > 0L) {
    ref_items <- vapply(seq_len(nrow(citations)), function(i) {
      row <- citations[i, ]
      paste0('<li><strong>[', row$work_id, ']</strong> ', row$snippet, '</li>')
    }, character(1))
    refs_html <- paste0(
      '<h3>References</h3>\n<ol>\n',
      paste(ref_items, collapse = "\n"),
      '\n</ol>'
    )
  }

  html <- paste0(
    '<div class="sm-chat-response">\n',
    '<h2>Corpus Chat</h2>\n',
    '<p><strong>Question:</strong> ', response$question, '</p>\n',
    '<p><strong>Model:</strong> ', response$model,
    ' | <strong>Retrieved:</strong> ', nrow(response$retrieved_works),
    ' works</p>\n',
    '<hr>\n',
    '<h3>Answer</h3>\n',
    '<div class="answer">\n', text_html, '\n</div>\n',
    refs_html, '\n',
    '<hr>\n',
    '<p class="meta"><em>Prompt hash: <code>',
    substr(response$prompt_hash, 1, 12),
    '</code> | Generated: ',
    format(response$timestamp, "%Y-%m-%d %H:%M:%S"),
    '</em></p>\n',
    '</div>'
  )

  html
}

#' Render chat as Quarto-compatible markdown
#' @noRd
.render_chat_quarto <- function(text, citations, response) {
  # Replace cite tokens
  for (i in seq_len(nrow(citations))) {
    token <- citations$cite_token[i]
    ref <- paste0("**[", citations$work_id[i], "]**")
    text <- gsub(token, ref, text, fixed = TRUE)
  }

  lines <- c(
    "---",
    'title: "Corpus Chat Response"',
    paste0('date: "', format(response$timestamp, "%Y-%m-%d"), '"'),
    "format: html",
    "---",
    "",
    "## Question",
    "",
    response$question,
    "",
    "::: {.callout-note}",
    paste0("Model: ", response$model,
           " | Retrieved: ", nrow(response$retrieved_works), " works",
           " | Method: ", response$retrieve_method),
    ":::",
    "",
    "## Answer",
    "",
    text,
    ""
  )

  if (nrow(citations) > 0L) {
    lines <- c(lines,
      "## References",
      ""
    )
    for (i in seq_len(nrow(citations))) {
      row <- citations[i, ]
      lines <- c(lines,
        paste0("- **[", row$work_id, "]** ", row$snippet)
      )
    }
    lines <- c(lines, "")
  }

  lines <- c(lines,
    "::: {.callout-tip collapse=\"true\"}",
    "## Reproducibility",
    paste0("Prompt hash: `", substr(response$prompt_hash, 1, 12), "`"),
    ":::"
  )

  paste(lines, collapse = "\n")
}

# Render a chat response

Converts an `sm_chat_response` object into a formatted document string.
The rendered output includes the question, answer with inline citations,
and a reference list. Supported formats are Markdown, HTML, and Quarto.

## Usage

``` r
sm_chat_render(
  response,
  format = c("markdown", "html", "quarto"),
  call = rlang::caller_env()
)
```

## Arguments

- response:

  An `sm_chat_response` object from
  [`sm_chat()`](https://r-heller.github.io/scimapR/reference/sm_chat.md).

- format:

  Character. Output format: `"markdown"`, `"html"`, or `"quarto"`.

- call:

  Caller environment for error reporting.

## Value

A character string containing the rendered response. Printed to the
console and returned invisibly.

## See also

Other chat:
[`sm_chat()`](https://r-heller.github.io/scimapR/reference/sm_chat.md)

## Examples

``` r
# \donttest{
# Requires a chat response object:
# rendered <- sm_chat_render(response, format = "markdown")
# cat(rendered)
# }
```

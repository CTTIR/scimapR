# Screen corpus against a research question

`sm_screen_against_question()` uses a chat provider to screen each work
in a corpus against a structured research question. For each work, the
provider is asked to classify the title/abstract as `"include"`,
`"exclude"`, or `"uncertain"`, with a confidence score and brief reason.
Results are written to the corpus's `screening` table.

[`sm_screen_regex()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_regex.md)
provides a deterministic fallback using regular-expression matching on
titles and abstracts.

[`sm_screen_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_summary.md)
returns a count summary of screening decisions by stage.

## Usage

``` r
sm_screen_against_question(
  corpus,
  question,
  stages = c("title-abstract", "full-text"),
  llm = NULL,
  batch_size = 10L,
  include_uncertain = TRUE,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- question:

  An `sm_question` object.

- stages:

  Character vector of screening stages to run. One or more of
  `"title-abstract"` and `"full-text"`, run in that order. The full-text
  stage still screens titles and abstracts using its instruction: no
  full texts are fetched.

- llm:

  An ellmer chat provider object (e.g., from
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html)).
  Required: no default provider is created. Titles and abstracts are
  sent to this provider. Each request uses a fresh copy: the object is
  unchanged, and its system prompt and earlier turns are not used.

- batch_size:

  Integer. Number of works to send per request.

- include_uncertain:

  Logical. If `TRUE`, works classified as `"uncertain"` by the latest
  successful title-abstract decision are carried forward. Failed
  provider rows are retried and never carried forward.

- verbose:

  Logical. Print progress?

- call:

  Caller environment for error reporting.

## Value

A modified `sm_corpus` with updated `screening` table, including the
provider model on each new row. Failed batches warn and are retried on
the next run, replacing their earlier failed rows.

## See also

Other question:
[`is_sm_question()`](https://cttir.github.io/scimapR/dev/reference/is_sm_question.md),
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_for_question.md),
[`sm_question()`](https://cttir.github.io/scimapR/dev/reference/sm_question.md),
[`sm_screen_regex()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_regex.md),
[`sm_screen_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_summary.md)

## Examples

``` r
corpus <- sm_example_corpus()
q <- sm_question(
  text = "spatial transcriptomics in cancer",
  framework = "free"
)
# Deterministic regex screening (no provider needed):
screened <- sm_screen_regex(
  corpus, include_terms = c("spatial", "transcriptom")
)
#> ✔ Regex screening: 73 included, 127 excluded.
sm_screen_summary(screened)
#> 
#> ── Stage: regex (n=200) 
#> exclude: 127 (63.5%)
#> include: 73 (36.5%)
#> # A tibble: 2 × 4
#>   stage decision     n   pct
#>   <chr> <chr>    <int> <dbl>
#> 1 regex exclude    127  63.5
#> 2 regex include     73  36.5
```

# Screen corpus against a research question

`sm_screen_against_question()` uses an LLM (via ellmer) to screen each
work in a corpus against a structured research question. For each work,
the LLM is asked to classify the title/abstract as `"include"`,
`"exclude"`, or `"uncertain"`, with a confidence score and brief reason.
Results are written to the corpus's `screening` table.

[`sm_screen_regex()`](https://cttir.github.io/scimapR/reference/sm_screen_regex.md)
provides a deterministic, LLM-free fallback using regular-expression
matching on titles and abstracts.

[`sm_screen_summary()`](https://cttir.github.io/scimapR/reference/sm_screen_summary.md)
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
  `"title-abstract"` and `"full-text"`.

- llm:

  An ellmer chat provider object (e.g., from
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html)).
  If `NULL`, the function will attempt to create a default provider.

- batch_size:

  Integer. Number of works to send per LLM prompt.

- include_uncertain:

  Logical. If `TRUE`, works classified as `"uncertain"` are carried
  forward to the next stage.

- verbose:

  Logical. Print progress?

- call:

  Caller environment for error reporting.

## Value

A modified `sm_corpus` with updated `screening` table.

## See also

Other question:
[`is_sm_question()`](https://cttir.github.io/scimapR/reference/is_sm_question.md),
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/reference/sm_corpus_for_question.md),
[`sm_question()`](https://cttir.github.io/scimapR/reference/sm_question.md),
[`sm_screen_regex()`](https://cttir.github.io/scimapR/reference/sm_screen_regex.md),
[`sm_screen_summary()`](https://cttir.github.io/scimapR/reference/sm_screen_summary.md)

## Examples

``` r
corpus <- sm_example_corpus()
q <- sm_question(
  text = "spatial transcriptomics in cancer",
  framework = "free"
)
# Deterministic regex screening (no LLM needed):
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

# Screen corpus using regex matching

A deterministic, LLM-free screening method that uses regular expression
matching on work titles and abstracts. Works matching any
`include_terms` (case-insensitive) and none of the `exclude_terms` are
classified as `"include"`; works matching an exclude term are
`"exclude"`; works matching no include term are `"exclude"`.

## Usage

``` r
sm_screen_regex(
  corpus,
  include_terms,
  exclude_terms = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- include_terms:

  Character vector of regex patterns. A work must match at least one to
  be included.

- exclude_terms:

  Character vector of regex patterns. A work matching any is excluded.
  Default `NULL` (no exclusions).

- call:

  Caller environment for error reporting.

## Value

A modified `sm_corpus` with updated `screening` table.

## See also

Other question:
[`is_sm_question()`](https://r-heller.github.io/scimapR/reference/is_sm_question.md),
[`sm_corpus_for_question()`](https://r-heller.github.io/scimapR/reference/sm_corpus_for_question.md),
[`sm_question()`](https://r-heller.github.io/scimapR/reference/sm_question.md),
[`sm_screen_against_question()`](https://r-heller.github.io/scimapR/reference/sm_screen_against_question.md),
[`sm_screen_summary()`](https://r-heller.github.io/scimapR/reference/sm_screen_summary.md)

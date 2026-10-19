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
  unicode = TRUE,
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

- unicode:

  Logical (default `TRUE`). Match the terms in Unicode mode, so `\w`,
  `\b`, `\d`, `\s` and POSIX classes know non-ASCII letters, digits and
  spaces, as in German or French titles. `FALSE` gives ASCII-only
  classes.

- call:

  Caller environment for error reporting.

## Value

A modified `sm_corpus` with updated `screening` table.

## Details

Terms are Perl-compatible regular expressions (PCRE), matched as written
and case-insensitively against the title and abstract of each work. In
Unicode mode (the default) each term is prefixed with the PCRE item
`(*UCP)` unless its leading items already include it, so `\b` finds the
edge of a word that starts with an umlaut and `\w` consumes one. A term
can therefore also stop matching: one that used `\W`, `\S`, `\D` or `\B`
to stand for a non-ASCII letter no longer matches it, and `\b` no longer
finds an edge between an ASCII letter and a non-ASCII letter next to it,
as inside a German compound word. Write `[A-Za-z0-9_]` instead of `\w`
for an ASCII-only class.

## See also

Other question:
[`is_sm_question()`](https://cttir.github.io/scimapR/dev/reference/is_sm_question.md),
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_for_question.md),
[`sm_question()`](https://cttir.github.io/scimapR/dev/reference/sm_question.md),
[`sm_screen_against_question()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_against_question.md),
[`sm_screen_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_summary.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 20, n_authors = 5)
screened <- sm_screen_regex(corpus,
                            include_terms = c("spatial", "transcriptom"),
                            exclude_terms = "\\bmouse\\b")
#> ✔ Regex screening: 7 included, 13 excluded.
sm_screen_summary(screened)
#> 
#> ── Stage: regex (n=20) 
#> exclude: 13 (65%)
#> include: 7 (35%)
#> # A tibble: 2 × 4
#>   stage decision     n   pct
#>   <chr> <chr>    <int> <dbl>
#> 1 regex exclude     13    65
#> 2 regex include      7    35
```

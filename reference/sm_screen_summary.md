# Summarise screening decisions

Returns a summary tibble of screening decisions by stage, showing the
count of included, excluded, and uncertain works at each stage.

## Usage

``` r
sm_screen_summary(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns `stage`, `decision`, `n`, and `pct`.

## See also

Other question:
[`is_sm_question()`](https://cttir.github.io/scimapR/reference/is_sm_question.md),
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/reference/sm_corpus_for_question.md),
[`sm_question()`](https://cttir.github.io/scimapR/reference/sm_question.md),
[`sm_screen_against_question()`](https://cttir.github.io/scimapR/reference/sm_screen_against_question.md),
[`sm_screen_regex()`](https://cttir.github.io/scimapR/reference/sm_screen_regex.md)

## Examples

``` r
corpus <- sm_example_corpus(with_screening = TRUE)
sm_screen_summary(corpus)
#> 
#> ── Stage: title-abstract (n=200) 
#> exclude: 96 (48%)
#> include: 82 (41%)
#> uncertain: 22 (11%)
#> # A tibble: 3 × 4
#>   stage          decision      n   pct
#>   <chr>          <chr>     <int> <dbl>
#> 1 title-abstract exclude      96    48
#> 2 title-abstract include      82    41
#> 3 title-abstract uncertain    22    11
```

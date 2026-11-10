# Test if an object is an sm_question

Test if an object is an sm_question

## Usage

``` r
is_sm_question(x)
```

## Arguments

- x:

  An object to test.

## Value

Logical.

## See also

Other question:
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/reference/sm_corpus_for_question.md),
[`sm_question()`](https://cttir.github.io/scimapR/reference/sm_question.md),
[`sm_screen_against_question()`](https://cttir.github.io/scimapR/reference/sm_screen_against_question.md),
[`sm_screen_regex()`](https://cttir.github.io/scimapR/reference/sm_screen_regex.md),
[`sm_screen_summary()`](https://cttir.github.io/scimapR/reference/sm_screen_summary.md)

## Examples

``` r
q <- sm_question("Does exercise reduce falls in older adults?")
#> ! PICO framework: `intervention` not specified.
#> ℹ Query strings may be less precise without it.
is_sm_question(q)
#> [1] TRUE
is_sm_question("Does exercise reduce falls in older adults?")
#> [1] FALSE
```

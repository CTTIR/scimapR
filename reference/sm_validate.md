# Validate corpus integrity

Check referential integrity across all corpus tables and report issues.

## Usage

``` r
sm_validate(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- call:

  Caller environment for error reporting.

## Value

A tibble of validation issues, or a 0-row tibble if clean.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/reference/sm_build_corpus.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/reference/sm_dedupe.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/reference/sm_materialise.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/reference/sm_save_corpus.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- sm_example_corpus()
issues <- sm_validate(corpus)
nrow(issues)
#> [1] 0
```

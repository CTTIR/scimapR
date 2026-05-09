# Extract MeSH terms from corpus

Summarise MeSH (Medical Subject Headings) terms from the concepts table.

## Usage

``` r
sm_field_pubmed_mesh(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus`.

- call:

  Caller environment.

## Value

A tibble with `mesh_term`, `count`, and `proportion`.

## See also

Other field-helpers:
[`sm_field_clinical_trials()`](https://r-heller.github.io/scimapR/reference/sm_field_clinical_trials.md),
[`sm_field_funder()`](https://r-heller.github.io/scimapR/reference/sm_field_funder.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_field_pubmed_mesh(corpus)
#> ℹ No MeSH terms found. Enrich with `sm_enrich_concepts()`.
#> # A tibble: 0 × 3
#> # ℹ 3 variables: mesh_term <chr>, count <int>, proportion <dbl>
```

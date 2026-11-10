# Extract funding information

Summarise funding sources from corpus metadata.

## Usage

``` r
sm_field_funder(
  corpus,
  source = c("crossref", "openalex"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- source:

  Data source for funding info.

- call:

  Caller environment.

## Value

A tibble of funders with counts.

## See also

Other field-helpers:
[`sm_field_clinical_trials()`](https://cttir.github.io/scimapR/reference/sm_field_clinical_trials.md),
[`sm_field_pubmed_mesh()`](https://cttir.github.io/scimapR/reference/sm_field_pubmed_mesh.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_field_funder(corpus)
#> ℹ Funding data requires enrichment. Use `sm_enrich_concepts()` or fetch from
#>   crossref.
#> # A tibble: 0 × 4
#> # ℹ 4 variables: funder <chr>, doi_prefix <chr>, country <chr>, n_works <int>
```

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
[`sm_field_clinical_trials()`](https://r-heller.github.io/scimapR/reference/sm_field_clinical_trials.md),
[`sm_field_pubmed_mesh()`](https://r-heller.github.io/scimapR/reference/sm_field_pubmed_mesh.md)

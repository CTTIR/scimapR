# Link corpus works to clinical trials

Identify works in the corpus that are linked to clinical trials based on
PMIDs or DOIs.

## Usage

``` r
sm_field_clinical_trials(corpus, ..., call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus`.

- ...:

  Additional arguments (currently unused).

- call:

  Caller environment.

## Value

A tibble with `work_id` and trial-related information.

## See also

Other field-helpers:
[`sm_field_funder()`](https://r-heller.github.io/scimapR/reference/sm_field_funder.md),
[`sm_field_pubmed_mesh()`](https://r-heller.github.io/scimapR/reference/sm_field_pubmed_mesh.md)

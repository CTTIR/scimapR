# Merge external screening decisions into corpus

Add external screening decisions (from Rayyan, Covidence, or manual
spreadsheet) into the corpus screening table.

## Usage

``` r
sm_merge_screening_decisions(corpus, decisions)
```

## Arguments

- corpus:

  An `sm_corpus`.

- decisions:

  A tibble with screening decisions.

## Value

An `sm_corpus` with updated screening.

## See also

Other screening:
[`sm_export_covidence()`](https://r-heller.github.io/scimapR/reference/sm_export_covidence.md),
[`sm_export_rayyan()`](https://r-heller.github.io/scimapR/reference/sm_export_rayyan.md),
[`sm_import_rayyan()`](https://r-heller.github.io/scimapR/reference/sm_import_rayyan.md),
[`sm_screen_prisma()`](https://r-heller.github.io/scimapR/reference/sm_screen_prisma.md)

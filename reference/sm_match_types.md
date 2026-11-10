# Controlled vocabulary for coverage match types

The set of values the `match_type` column of
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)'s
`matches` tibble (and
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)'s)
can take.

## Usage

``` r
sm_match_types(describe = FALSE)
```

## Arguments

- describe:

  Logical; if `TRUE`, return a tibble of `level` + `description`, else
  the ordered character vector (default).

## Value

A character vector or a tibble.

## See also

[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)

Other coverage:
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/reference/sm_coverage_breakdowns.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md),
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)

## Examples

``` r
sm_match_types()
#> [1] "doi"   "title" "none" 
```

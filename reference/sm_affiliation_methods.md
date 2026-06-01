# Controlled vocabulary for affiliation match methods

The set of values the `match_method` column of
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
can take.

## Usage

``` r
sm_affiliation_methods(describe = FALSE)
```

## Arguments

- describe:

  Logical; if `TRUE`, return a tibble of `level` + `description`, else
  the ordered character vector (default).

## Value

A character vector or a tibble.

## See also

[`sm_affiliation_signals()`](https://cttir.github.io/scimapR/reference/sm_affiliation_signals.md)

Other affiliation:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
[`sm_affiliation_signals()`](https://cttir.github.io/scimapR/reference/sm_affiliation_signals.md),
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/reference/sm_affiliation_summary.md),
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/reference/sm_attribute_institution.md)

## Examples

``` r
sm_affiliation_methods()
#> [1] "pattern"      "email_domain" "postcode"     "none"        
```

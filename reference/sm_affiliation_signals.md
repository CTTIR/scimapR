# Controlled vocabulary for affiliation match signals

The ordered set of values the `match_signal` column of
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
/
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/reference/sm_affiliation_summary.md)
can take. Using this helper (rather than hard-coding strings) means
downstream filtering — e.g. separating institution-name matches from
email-domain matches — cannot drift if the levels change.

## Usage

``` r
sm_affiliation_signals(describe = FALSE)
```

## Arguments

- describe:

  Logical; if `TRUE`, return a tibble of `level` + a short
  `description`. If `FALSE` (default), return the ordered character
  vector of levels (suitable for `factor(levels = )`).

## Value

A character vector (ordered, highest matching priority first) or a
tibble of `level`/`description`.

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
[`sm_affiliation_methods()`](https://cttir.github.io/scimapR/reference/sm_affiliation_methods.md)

Other affiliation:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
[`sm_affiliation_methods()`](https://cttir.github.io/scimapR/reference/sm_affiliation_methods.md),
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/reference/sm_affiliation_summary.md),
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/reference/sm_attribute_institution.md)

## Examples

``` r
sm_affiliation_signals()
#> [1] "name_token"   "email_domain" "postcode"     "none"        
sm_affiliation_signals(describe = TRUE)
#> # A tibble: 4 × 2
#>   level        description                                                 
#>   <fct>        <chr>                                                       
#> 1 name_token   Institution name token matched a dictionary pattern.        
#> 2 email_domain Author email domain matched a dictionary email domain.      
#> 3 postcode     Affiliation postcode matched a dictionary postcode (opt-in).
#> 4 none         No signal matched this authorship.                          
```

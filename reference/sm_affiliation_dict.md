# Default affiliation-matching dictionary

A small, documented, user-overridable dictionary of institution name
variants used by
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md).
It covers common military / medical institution variants (including
German synonyms) plus email-domain fallbacks, and is designed to be
extended by appending rows.

## Usage

``` r
sm_affiliation_dict
```

## Format

A tibble with three columns:

- institution:

  Canonical institution name (character).

- pattern:

  A case-insensitive regular expression matched against affiliation
  strings (character).

- email_domain:

  Optional email domain used by the email-domain fallback, or `NA`
  (character).

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)

## Examples

``` r
sm_affiliation_dict
#> # A tibble: 14 × 3
#>    institution           pattern                         email_domain  
#>    <chr>                 <chr>                           <chr>         
#>  1 Bundeswehr Hospital   "bundeswehrkrankenhaus"         bundeswehr.org
#>  2 Bundeswehr Hospital   "armed forces hospital"         NA            
#>  3 Bundeswehr Hospital   "army hospital"                 NA            
#>  4 Bundeswehr Hospital   "military hospital"             NA            
#>  5 Bundeswehr Hospital   "bwkrhs"                        NA            
#>  6 Charite Berlin        "charit[eé]"                    charite.de    
#>  7 Charite Berlin        "universit[aä]tsmedizin berlin" NA            
#>  8 Walter Reed           "walter reed"                   NA            
#>  9 Walter Reed           "wrair"                         NA            
#> 10 US Army               "u\\.?s\\.? army"               army.mil      
#> 11 US Army               "united states army"            NA            
#> 12 NATO                  "\\bnato\\b"                    NA            
#> 13 Robert Koch Institute "robert koch"                   rki.de        
#> 14 Robert Koch Institute "robert-koch-institut"          NA            
```

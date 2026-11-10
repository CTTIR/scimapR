# Default affiliation-matching dictionary

A small, documented, user-overridable dictionary of institution name
variants used by
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md).
It covers common medical institution variants (including German
synonyms) plus email-domain fallbacks, and is designed to be extended by
appending rows.

## Usage

``` r
sm_affiliation_dict
```

## Format

A tibble with three columns:

- institution:

  Canonical institution name (character).

- pattern:

  A case-insensitive Perl-compatible regular expression matched against
  affiliation strings (character).

- email_domain:

  Optional email domain used by the email-domain fallback, or `NA`
  (character).

## Details

Patterns are case-insensitive PCRE with Unicode-aware `\w`, `\b`, `\d`
and `\s`:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
matches them in Unicode mode by default, so a row added for a German,
French or Scandinavian name can use these classes next to non-ASCII
letters (see the Details of
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
including its `unicode` argument). In that mode the shipped row
`\bembl\b` no longer matches "EMBL" directly followed by an umlaut, as
in a German compound word. The first pattern that matches wins, in row
order, so add specific rows before generic ones.

The rows for "Diakonie Hospital" match its German name, its
abbreviation, or "hospital" after "Diakonie" or after "Protestant
Deaconess", "Protestant Church" or "Protestant Diaconal", with at most
one word in between. A bare "deaconess hospital", "church hospital" or
"public services hospital", which names hospitals of many countries,
stays unmatched; up to scimapR 0.4.0 these phrases matched "Diakonie
Hospital" wherever they appeared. The dictionary is a starting point:
for an audit of your own institutions, pass a dictionary of them to
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md).

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
[`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/reference/sm_affiliation_unmatched.md)

## Examples

``` r
sm_affiliation_dict
#> # A tibble: 13 × 3
#>    institution           pattern                                    email_domain
#>    <chr>                 <chr>                                      <chr>       
#>  1 Diakonie Hospital     "diakoniekrankenhaus"                      diakonie.ex…
#>  2 Diakonie Hospital     "diakonie\\W+(\\w+\\W+)?hospital"          NA          
#>  3 Diakonie Hospital     "protestant (deaconess|church|diaconal)\\… NA          
#>  4 Diakonie Hospital     "diakkh"                                   NA          
#>  5 Charite Berlin        "charit[eé]"                               charite.de  
#>  6 Charite Berlin        "universit[aä]tsmedizin berlin"            NA          
#>  7 Westbrook             "westbrook"                                NA          
#>  8 Westbrook             "wbir"                                     NA          
#>  9 US FDA                "u\\.?s\\.? fda"                           fda.gov     
#> 10 US FDA                "united states fda"                        NA          
#> 11 EMBL                  "\\bembl\\b"                               NA          
#> 12 Robert Koch Institute "robert koch"                              rki.de      
#> 13 Robert Koch Institute "robert-koch-institut"                     NA          
```

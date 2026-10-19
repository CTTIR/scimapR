# Default affiliation-matching dictionary

A small, documented, user-overridable dictionary of institution name
variants used by
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md).
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

  A case-insensitive Perl-compatible regular expression matched against
  affiliation strings (character).

- email_domain:

  Optional email domain used by the email-domain fallback, or `NA`
  (character).

## Details

Patterns are case-insensitive PCRE with Unicode-aware `\w`, `\b`, `\d`
and `\s`:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
matches them in Unicode mode by default, so a row added for a German,
French or Scandinavian name can use these classes next to non-ASCII
letters (see the Details of
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md),
including its `unicode` argument). In that mode the shipped row
`\bnato\b` no longer matches "NATO" directly followed by an umlaut, as
in a German compound word. The first pattern that matches wins, in row
order, so add specific rows before generic ones.

The rows for "Bundeswehr Hospital" match its German name, its
abbreviation, or "hospital" after "Bundeswehr" or after "German Armed
Forces", "German Army" or "German Military", with at most one word in
between. A bare "military hospital", "army hospital" or "armed forces
hospital", which names hospitals of many countries, stays unmatched; up
to scimapR 0.4.0 these phrases matched "Bundeswehr Hospital" wherever
they appeared. The dictionary is a starting point: for an audit of your
own institutions, pass a dictionary of them to
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md).

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md),
[`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_unmatched.md)

## Examples

``` r
sm_affiliation_dict
#> # A tibble: 13 × 3
#>    institution           pattern                                    email_domain
#>    <chr>                 <chr>                                      <chr>       
#>  1 Bundeswehr Hospital   "bundeswehrkrankenhaus"                    bundeswehr.…
#>  2 Bundeswehr Hospital   "bundeswehr\\W+(\\w+\\W+)?hospital"        NA          
#>  3 Bundeswehr Hospital   "german (armed forces|army|military)\\W+(… NA          
#>  4 Bundeswehr Hospital   "bwkrhs"                                   NA          
#>  5 Charite Berlin        "charit[eé]"                               charite.de  
#>  6 Charite Berlin        "universit[aä]tsmedizin berlin"            NA          
#>  7 Walter Reed           "walter reed"                              NA          
#>  8 Walter Reed           "wrair"                                    NA          
#>  9 US Army               "u\\.?s\\.? army"                          army.mil    
#> 10 US Army               "united states army"                       NA          
#> 11 NATO                  "\\bnato\\b"                               NA          
#> 12 Robert Koch Institute "robert koch"                              rki.de      
#> 13 Robert Koch Institute "robert-koch-institut"                     NA          
```

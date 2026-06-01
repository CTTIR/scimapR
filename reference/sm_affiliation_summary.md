# Summarise affiliation matches

Tidy summary of the matches produced by
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
mirroring the audit-style summaries elsewhere in the package: counts of
works and authorships flagged, broken down by institution and by
`match_signal`.

## Usage

``` r
sm_affiliation_summary(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` previously passed through
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
  (so its `authorships` carry `institution_match` and `match_signal`).

- call:

  Caller environment for error reporting.

## Value

A tibble with columns `institution`, `match_signal`, `n_authorships`,
`n_works`, sorted by `n_authorships` descending. Type-stable: a 0-row
tibble (with a warning) when no matches are present.

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)

Other affiliation:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/reference/sm_attribute_institution.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
corpus <- sm_affiliation_match(corpus)
#> ✔ Affiliation matching flagged 1 authorship across 1 institution.
#> ℹ By signal: name_token: 1. See `sm_affiliation_summary()` for the full
#>   breakdown.
sm_affiliation_summary(corpus)
#> # A tibble: 1 × 4
#>   institution         match_signal n_authorships n_works
#>   <chr>               <chr>                <int>   <int>
#> 1 Bundeswehr Hospital name_token               1       1
```

# List affiliation strings that matched no institution

Audits an affiliation dictionary. After
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md),
it lists the most frequent `raw_affiliation` strings of the authorships
that no signal (name pattern, email domain or postcode) assigned to an
institution, so the dictionary can be extended where that matters most.

## Usage

``` r
sm_affiliation_unmatched(corpus, n = 25L, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` previously passed through
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  (so its `authorships` carry `institution_match`).

- n:

  Maximum number of strings to return: a positive whole number, or `Inf`
  for all of them. Default 25.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns `raw_affiliation` (character), `n_authorships`
(integer: unmatched authorships with that string) and `n_works`
(integer: distinct works among them), at most `n` rows, sorted by
`n_authorships` descending and then by `raw_affiliation` in code-point
order. Authorships whose `raw_affiliation` is `NA` or blank are not
listed. Type-stable: a 0-row tibble when every affiliation matched, and
a 0-row tibble with a warning when the corpus has not been matched.

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md),
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md)

Other affiliation:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md),
[`sm_affiliation_methods()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_methods.md),
[`sm_affiliation_signals()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_signals.md),
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md),
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)

## Examples

``` r
fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
dict <- readr::read_csv(
  sm_example_files("example_realuse_affiliation_dict.csv"),
  col_types = "ccc"
)
matched <- sm_affiliation_match(fix, dict)
#> ✔ Affiliation matching flagged 427 authorships across 4 institutions.
#> ℹ By signal: name_token: 427. See `sm_affiliation_summary()` for the full
#>   breakdown.
sm_affiliation_unmatched(matched, n = 5)
#> # A tibble: 5 × 3
#>   raw_affiliation                                          n_authorships n_works
#>   <chr>                                                            <int>   <int>
#> 1 Hilltop Univ Med Ctr, Dept Surg, NL-9999 ZZ Hilltop, Ne…           103      52
#> 2 Univ Northtown, Inst Clin Chem, Northtown, Germany.                 46      35
#> 3 Alpenau Cantonal Hosp, Dept Infect Dis, CH-9999 Alpenau…            42      33
#> 4 Univ Northtown, Dept Microbiol, Northtown, Germany.                 33      26
#> 5 Univ Northtown, Dept Trauma Surg, Northtown, Germany.               31      26
```

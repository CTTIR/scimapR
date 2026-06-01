# Attribute matched affiliations to a controlled institution vocabulary

Rolls institution matches (from
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md))
up to a controlled vocabulary, writing a normalised `institution_id` and
`institution_name` onto the `authorships` table. Supports a ROR-backed
vocabulary (via a user-supplied offline ROR table) or a `"custom"`
vocabulary derived directly from the matched institution names.

## Usage

``` r
sm_attribute_institution(
  corpus,
  vocabulary = c("ror", "custom"),
  ror_table = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`. If it has no `institution_match` column,
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
  is run first with default settings.

- vocabulary:

  `"ror"` (default) or `"custom"`.

- ror_table:

  For `vocabulary = "ror"`, a data frame with columns `ror_id`, `name`,
  and `aliases` (aliases either a `;`-separated string or a
  list-column). Matching is case-insensitive against `name` and each
  alias, as well as against the `institution_match` value. A synthetic
  example ships at
  `system.file("extdata", "example_ror.csv", package = "scimapR")`.

- call:

  Caller environment for error reporting.

## Value

The `corpus` with its `authorships` table gaining `institution_id` and
`institution_name` columns (for `"ror"`, `institution_id` holds the ROR
id). Unmatched rows keep `NA` – the function never errors on unmatched
affiliations. Type-stable.

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)

Other affiliation:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md),
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/reference/sm_affiliation_summary.md)

## Examples

``` r
ror <- utils::read.csv(
  system.file("extdata", "example_ror.csv", package = "scimapR"),
  stringsAsFactors = FALSE
)
corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
corpus$authorships$raw_affiliation[1] <- "Charite Universitatsmedizin Berlin"
corpus <- sm_affiliation_match(corpus)
#> ✔ Affiliation matching flagged 1 authorship across 1 institution.
#> ℹ By signal: name_token: 1. See `sm_affiliation_summary()` for the full
#>   breakdown.
corpus <- sm_attribute_institution(corpus, vocabulary = "ror",
                                   ror_table = ror)
corpus$authorships$institution_name[1]
#> [1] "Charite Berlin"
```

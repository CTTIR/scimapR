# Attribute matched affiliations to a controlled institution vocabulary

Rolls institution matches (from
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md))
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
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  is run first with default settings, that is with the shipped
  [sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md);
  to attribute your own institutions, run it first with a dictionary of
  them.

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

The `corpus` with `institution_id` and `institution_name` set on the
`authorships` rows that match the vocabulary (for `"ror"`,
`institution_id` holds the ROR id; for `"custom"`, `CUST:` and the
matched name). Unmatched rows keep the `institution_id` and
`institution_name` they had, such as the OpenAlex institution ids of a
fetched corpus, or `NA` – the function never errors on unmatched
affiliations. Type-stable.

## Details

The `institution_match` column stays as it is.
`sm_count(level = "institution")` labels each authorship by
`institution_match` before `institution_name` and `institution_id`, so
the roll-up to the vocabulary reaches the counts only for authorships
without a match, and the `"affiliation"` breakdown of
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md)
uses `institution_name` only when no authorship has a match. Up to
scimapR 0.4.0,
[`sm_count()`](https://cttir.github.io/scimapR/dev/reference/sm_count.md)
counted by `institution_id` whenever any authorship had one. To count or
break down by the vocabulary, put its names first, for example:

    a <- corpus$authorships
    corpus$authorships$institution_match <-
      dplyr::coalesce(a$institution_name, a$institution_match)

The ids written to matched rows are ROR ids or `CUST:` ids, which join
`corpus$institutions` only where that table lists them, so functions
that read the institutions table for these rows (such as
`sm_audit_geographic(by = "region")`) find no entry for them. Unmatched
rows keep their earlier ids and so their entries. Up to scimapR 0.4.0,
unmatched rows lost their `institution_id`.

## See also

[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)

Other affiliation:
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md),
[`sm_affiliation_methods()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_methods.md),
[`sm_affiliation_signals()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_signals.md),
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md),
[`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_unmatched.md)

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

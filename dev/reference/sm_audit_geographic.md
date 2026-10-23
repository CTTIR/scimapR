# Geographic representation audit

Audits the geographic distribution of a corpus, tabulating the
representation of countries, regions, or World Bank income tiers. The
analysis can be weighted by work count, total citations,
first-authorship, or corresponding authorship. Each work counts once per
distinct known group, with optional fractional credit.

The result includes a Gini coefficient for concentration and a coverage
metric (proportion of works with known geography).

## Usage

``` r
sm_audit_geographic(
  corpus,
  by = c("country", "region", "income_tier"),
  weight = c("count", "citations", "first-author", "corresponding"),
  method = c("full", "fractional"),
  call = rlang::caller_env()
)

# S3 method for class 'sm_audit_geographic'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- by:

  Character. Grouping variable: `"country"` (ISO 3166-1 alpha-2 codes
  from authorships), `"region"` (from institutions table), or
  `"income_tier"` (World Bank income classification from institutions).

- weight:

  Character. How to weight each work: `"count"` (one per work and group,
  before applying `method`), `"citations"` (weighted by cited_by_count),
  `"first-author"` (only first-author affiliations), `"corresponding"`
  (only corresponding-author affiliations).

- method:

  Counting rule: `"full"` gives each work one unit per distinct known
  group; `"fractional"` splits one unit equally among its known groups.
  Citation credit is split by the same shares.

- call:

  Caller environment for error reporting.

- x:

  An audit object to print.

- ...:

  Ignored.

## Value

An `sm_audit_geographic` S3 object containing:

- distribution:

  Tibble with columns `group`, `count`, `citations`, `pct`, `credit` and
  `weighted_citations`. Counts and raw citations include each work once
  per group under both methods. Percentages and the Gini use credit, or
  weighted citations for citation weighting. Count percentages describe
  work-group pairs under full counting and works under fractional
  counting.

- gini:

  Gini coefficient of the distribution.

- coverage:

  Proportion of works with at least one known geography.

- by:

  The grouping variable used.

- weight:

  The weighting method used.

- method:

  The counting rule used.

`x` invisibly (print methods).

## Details

Coverage uses all corpus works as its denominator and counts works with
at least one known group after the authorship filter. Missing geography
is excluded from credit allocation; incomplete metadata can therefore
change both coverage and the shares assigned to known groups.

## See also

Other audit:
[`print.sm_audit_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_summary.md),
[`sm_audit_funding()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_funding.md),
[`sm_audit_gender()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_gender.md),
[`sm_audit_oa()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_oa.md)

## Examples

``` r
corpus <- sm_example_corpus()
geo <- sm_audit_geographic(corpus)
print(geo)
#> 
#> ── <sm_audit_geographic> ───────────────────────────────────────────────────────
#> Grouping: country
#> Weighting: count
#> Counting: full
#> Coverage: 100% of works have known geography
#> Gini coefficient: 0.126
#> 
#> 
#> ── Distribution (top 10) 
#> DE: 63 (9.17%) [954 cit.]
#> FI: 46 (6.7%) [708 cit.]
#> AU: 44 (6.4%) [646 cit.]
#> NO: 38 (5.53%) [472 cit.]
#> GB: 37 (5.39%) [544 cit.]
#> IT: 37 (5.39%) [540 cit.]
#> DK: 36 (5.24%) [500 cit.]
#> BR: 33 (4.8%) [533 cit.]
#> CA: 33 (4.8%) [568 cit.]
#> CH: 33 (4.8%) [474 cit.]
#> ... and 10 more
#> 
#> 
#> ── Limitations 
#> • Country codes are derived from author affiliation metadata, which may be
#> incomplete or inaccurate.
#> • Full counting gives a work one unit in each known group; fractional counting
#> splits one unit among those groups.
#> • Region and income tier classifications rely on institutional metadata which
#> may not be populated for all works.
#> • Geographic representation does not capture diaspora researchers or
#> researchers with affiliations in multiple countries.
#> • The Gini coefficient measures concentration but does not account for
#> population size or research funding differences.
```

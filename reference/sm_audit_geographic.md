# Geographic representation audit

Audits the geographic distribution of a corpus, tabulating the
representation of countries, regions, or World Bank income tiers. The
analysis can be weighted by work count, total citations,
first-authorship, or corresponding authorship.

The result includes a Gini coefficient for concentration and a coverage
metric (proportion of works with known geography).

## Usage

``` r
sm_audit_geographic(
  corpus,
  by = c("country", "region", "income_tier"),
  weight = c("count", "citations", "first-author", "corresponding"),
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

  Character. How to weight each work: `"count"` (one per work),
  `"citations"` (weighted by cited_by_count), `"first-author"` (only
  first-author affiliations), `"corresponding"` (only
  corresponding-author affiliations).

- call:

  Caller environment for error reporting.

- x:

  An audit object to print.

- ...:

  Ignored.

## Value

An `sm_audit_geographic` S3 object containing:

- distribution:

  Tibble with columns `group`, `count`, `pct`, `citations`.

- gini:

  Gini coefficient of the distribution.

- coverage:

  Proportion of works with at least one known geography.

- by:

  The grouping variable used.

- weight:

  The weighting method used.

`x` invisibly (print methods).

## See also

Other audit:
[`print.sm_audit_summary()`](https://r-heller.github.io/scimapR/reference/sm_audit_summary.md),
[`sm_audit_funding()`](https://r-heller.github.io/scimapR/reference/sm_audit_funding.md),
[`sm_audit_gender()`](https://r-heller.github.io/scimapR/reference/sm_audit_gender.md),
[`sm_audit_oa()`](https://r-heller.github.io/scimapR/reference/sm_audit_oa.md)

## Examples

``` r
corpus <- sm_example_corpus()
geo <- sm_audit_geographic(corpus)
print(geo)
#> 
#> ── <sm_audit_geographic> ───────────────────────────────────────────────────────
#> Grouping: country
#> Weighting: count
#> Coverage: 100% of authorships have known geography
#> Gini coefficient: 0.143
#> 
#> 
#> ── Distribution (top 10) 
#> DE: 77 (10.2%) [1204 cit.]
#> AU: 50 (6.62%) [727 cit.]
#> FI: 49 (6.49%) [771 cit.]
#> NO: 43 (5.7%) [524 cit.]
#> IT: 41 (5.43%) [571 cit.]
#> GB: 40 (5.3%) [572 cit.]
#> CA: 38 (5.03%) [647 cit.]
#> DK: 38 (5.03%) [576 cit.]
#> NL: 37 (4.9%) [530 cit.]
#> BR: 35 (4.64%) [556 cit.]
#> ... and 10 more
#> 
#> 
#> ── Limitations 
#> • Country codes are derived from author affiliation metadata, which may be
#> incomplete or inaccurate.
#> • Multi-country affiliations may be under- or over-counted depending on the
#> data source.
#> • Region and income tier classifications rely on institutional metadata which
#> may not be populated for all works.
#> • Geographic representation does not capture diaspora researchers or
#> researchers with affiliations in multiple countries.
#> • The Gini coefficient measures concentration but does not account for
#> population size or research funding differences.
```

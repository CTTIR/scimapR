# Open access status audit

Audits the open-access (OA) status distribution of works in a corpus.
Uses the `oa_status` column in the works table, which may have values
such as `"gold"`, `"green"`, `"hybrid"`, `"bronze"`, or `"closed"`.

The result includes counts and percentages for each OA category, as well
as a coverage metric.

## Usage

``` r
sm_audit_oa(corpus, call = rlang::caller_env())

# S3 method for class 'sm_audit_oa'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- call:

  Caller environment for error reporting.

- x:

  An audit object to print.

- ...:

  Ignored.

## Value

An `sm_audit_oa` S3 object containing:

- distribution:

  Tibble with columns `oa_status`, `count`, `pct`.

- pct_open:

  Percentage of works that are open access (gold, green, hybrid, or
  bronze).

- coverage:

  Proportion of works with a known OA status.

- n_works:

  Total number of works.

## See also

Other audit:
[`print.sm_audit_summary()`](https://cttir.github.io/scimapR/reference/sm_audit_summary.md),
[`sm_audit_funding()`](https://cttir.github.io/scimapR/reference/sm_audit_funding.md),
[`sm_audit_gender()`](https://cttir.github.io/scimapR/reference/sm_audit_gender.md),
[`sm_audit_geographic()`](https://cttir.github.io/scimapR/reference/sm_audit_geographic.md)

## Examples

``` r
corpus <- sm_example_corpus()
oa <- sm_audit_oa(corpus)
print(oa)
#> 
#> ── <sm_audit_oa> ───────────────────────────────────────────────────────────────
#> Open access: 56.5%
#> Coverage: 100% of works have known OA status
#> Total works: 200
#> 
#> 
#> ── OA status distribution 
#> closed: 87 (43.5%)
#> gold: 35 (17.5%)
#> green: 32 (16%)
#> bronze: 24 (12%)
#> hybrid: 22 (11%)
#> 
#> 
#> ── Limitations 
#> • OA status may change over time as embargo periods expire or publishers change
#> their access policies.
#> • 'Green' OA indicates a version is available in a repository but it may not be
#> the version of record.
#> • 'Bronze' OA indicates free-to-read on the publisher site without a formal
#> open license; access may be revoked.
#> • OA status data depends on Unpaywall/OpenAlex coverage, which may not include
#> all repositories.
```

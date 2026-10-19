# Funding source audit

Audits the distribution of funding sources across works in a corpus.
Funding metadata is extracted from either Crossref `funder` fields or
OpenAlex `grants` fields, depending on the `source` parameter.

The result includes funder counts, the proportion of works with known
funding, and a concentration analysis.

## Usage

``` r
sm_audit_funding(
  corpus,
  source = c("crossref", "openalex"),
  call = rlang::caller_env()
)

# S3 method for class 'sm_audit_funding'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- source:

  Character. Where to look for funding data: `"crossref"` (uses DOIs to
  query Crossref funder metadata) or `"openalex"` (uses OpenAlex IDs).

- call:

  Caller environment for error reporting.

- x:

  An audit object to print.

- ...:

  Ignored.

## Value

An `sm_audit_funding` S3 object containing:

- funders:

  Tibble with columns `funder_name`, `funder_doi`, `n_works`, `pct`.

- coverage:

  Proportion of works with at least one funder.

- n_works_total:

  Total number of works in corpus.

- n_works_funded:

  Number of works with funding data.

- source:

  The data source used.

## See also

Other audit:
[`print.sm_audit_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_summary.md),
[`sm_audit_gender()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_gender.md),
[`sm_audit_geographic()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_geographic.md),
[`sm_audit_oa()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_oa.md)

## Examples

``` r
# Works without a DOI need no Crossref lookup, so this runs offline and
# returns an empty audit.
corpus <- sm_example_corpus(n_works = 20, n_authors = 10)
corpus$works$doi <- NA_character_
funding <- sm_audit_funding(corpus, source = "crossref")
#> ℹ No funding data found via "crossref".
#> ℹ This may be because the works lack DOIs/identifiers, or the source does not
#>   have funding metadata.
print(funding)
#> 
#> ── <sm_audit_funding> ──────────────────────────────────────────────────────────
#> Data source: crossref
#> Works with funding data: 0 / 20 (0%)
#> 
#> No funding data found.
#> 
#> 
#> ── Limitations 
#> • Funding metadata is voluntarily reported by publishers and is often
#> incomplete, especially for older publications.
#> • Crossref and OpenAlex may not capture all funding sources; institutional or
#> departmental funding is rarely recorded.
#> • Funder names are not standardised across databases; the same funder may
#> appear under multiple names.
#> • Absence of funding data does not mean a work was unfunded; it may simply be
#> unreported.
if (FALSE) { # interactive()
# Live lookup: one Crossref request per DOI (the example DOIs are invented,
# so no funders are found).
corpus <- sm_example_corpus(n_works = 3, n_authors = 3)
funding <- sm_audit_funding(corpus, source = "crossref")
print(funding)
}
```

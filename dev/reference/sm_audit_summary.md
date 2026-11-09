# Combined equity audit summary

Runs all available equity audits (geographic, gender, funding, OA
status) on a corpus and returns a combined summary. Individual audit
results can be passed as `...` arguments to avoid re-computation; any
missing audits are run with default parameters, except that the gender
audit uses `method = "manual"` and audits that send web requests run
only when `online = TRUE`.

## Usage

``` r
# S3 method for class 'sm_audit_summary'
print(x, ...)

sm_audit_summary(corpus, ..., online = FALSE, call = rlang::caller_env())
```

## Arguments

- x:

  An audit object to print.

- ...:

  Optional pre-computed audit objects (e.g., `sm_audit_geographic`,
  `sm_audit_gender`, `sm_audit_funding`, `sm_audit_oa`). If provided,
  these are included directly rather than being re-run.

- corpus:

  An `sm_corpus` object.

- online:

  Logical. Whether audits that send web requests may run. Only the
  funding audit does:
  [`sm_audit_funding()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_funding.md)
  looks up every DOI on Crossref. With the default `FALSE`, a funding
  audit is included only when one is passed in `...`; otherwise it is
  reported as not run. Set `TRUE` to run it with its default Crossref
  source.

- call:

  Caller environment for error reporting.

## Value

An `sm_audit_summary` S3 object containing:

- geographic:

  An `sm_audit_geographic` result.

- gender:

  An `sm_audit_gender` result.

- funding:

  An `sm_audit_funding` result. A funding audit that was not run has no
  funders, `source = "none"` and `coverage = NA`.

- oa:

  An `sm_audit_oa` result.

- overview:

  A tibble with one row per audit: `audit`, `coverage` (`NA` for an
  audit that was not run) and `top_finding`.

## See also

Other audit:
[`sm_audit_funding()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_funding.md),
[`sm_audit_gender()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_gender.md),
[`sm_audit_geographic()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_geographic.md),
[`sm_audit_oa()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_oa.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 50, n_authors = 20)
# The funding audit sends batched Crossref requests, so it is not run
# unless online = TRUE.
summary_audit <- sm_audit_summary(corpus)
#> ℹ Skipped the funding audit, which sends batched Crossref requests.
#> ℹ Use `online = TRUE` to run it, or pass a precomputed `sm_audit_funding()`
#>   result.
summary_audit$overview
#> # A tibble: 4 × 3
#>   audit       coverage top_finding                  
#>   <chr>          <dbl> <chr>                        
#> 1 geographic         1 DE (15.54%)                  
#> 2 gender             0 NA (100%)                    
#> 3 funding           NA not run (needs online = TRUE)
#> 4 open_access        1 54% open access              

# A precomputed audit is used as it is. This funding audit sends no
# request because its copy of the corpus has no DOIs.
no_doi <- corpus
no_doi$works$doi <- NA_character_
funding <- sm_audit_funding(no_doi)
#> No funding data: works lack DOIs or identifiers.
summary_audit <- sm_audit_summary(corpus, funding)
print(summary_audit)
#> 
#> ── <sm_audit_summary> ──────────────────────────────────────────────────────────
#> 
#> ── Overview 
#> geographic: coverage 100% | DE (15.54%)
#> gender: coverage 0% | NA (100%)
#> funding: coverage n/a | no work could be checked
#> open_access: coverage 100% | 54% open access
#> 
#> Use `print(x$geographic)`, `print(x$gender)`, etc. for detailed reports.
#> 
#> 
#> ── Limitations 
#> • All equity audits rely on metadata that may be incomplete, inaccurate, or
#> biased toward certain regions and publishers.
#> • Coverage varies across audit dimensions; low coverage means results should be
#> interpreted with extreme caution.
#> • These audits describe patterns in the available metadata and should not be
#> treated as definitive measures of equity.
#> • We encourage transparent reporting of method, coverage, and limitations
#> alongside any equity analysis.
```

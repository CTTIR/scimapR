# Flag citation-immature recent years

Adds citation-maturity flags to the `works` table so that downstream
trend and impact functions can shade or exclude recent,
citation-immature years instead of treating their (artificially low)
citation counts as final.

Works published within the most recent `lag` years – relative to the
corpus's "as-of" date (`metadata$last_refresh` if present, else the
maximum publication year) – are flagged provisional.

## Usage

``` r
sm_citation_maturity(corpus, lag = 2L, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus`.

- lag:

  Integer number of recent years to treat as citation-immature (default
  `2`).

- call:

  Caller environment for error reporting.

## Value

The `corpus` with two logical columns added to `works`:
`citation_mature` (`TRUE` when the year is mature) and
`cnci_provisional` (the negation; `TRUE` when citation-based indicators
should be treated as provisional). Type-stable: an empty corpus gains
the columns with 0 rows.

## See also

[`sm_its()`](https://cttir.github.io/scimapR/reference/sm_its.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md)

Other counting:
[`sm_count()`](https://cttir.github.io/scimapR/reference/sm_count.md),
[`sm_metric_summary()`](https://cttir.github.io/scimapR/reference/sm_metric_summary.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 20, seed = 1)
corpus <- sm_citation_maturity(corpus, lag = 2)
table(corpus$works$cnci_provisional)
#> 
#> FALSE 
#>    20 
```

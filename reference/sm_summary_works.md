# Summary statistics for works

Computes aggregate summary statistics for all works in the corpus.

## Usage

``` r
sm_summary_works(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object.

- call:

  Caller environment for error reporting.

## Value

A tibble with one row containing summary statistics: `n_works`,
`year_min`, `year_max`, `year_span`, `mean_citations`,
`median_citations`, `total_citations`, `n_types` (unique document
types), `n_sources` (unique journals/sources), `n_oa` (open access
works), `pct_oa`, `n_retracted`, `n_languages`.

## See also

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://cttir.github.io/scimapR/reference/sm_metric_h_index.md),
[`sm_metric_m_index()`](https://cttir.github.io/scimapR/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://cttir.github.io/scimapR/reference/sm_metric_novelty.md),
[`sm_metric_rcr()`](https://cttir.github.io/scimapR/reference/sm_metric_rcr.md),
[`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md),
[`sm_summary_authors()`](https://cttir.github.io/scimapR/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://cttir.github.io/scimapR/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://cttir.github.io/scimapR/reference/sm_summary_sources.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_summary_works(corpus)
#> # A tibble: 1 × 13
#>   n_works year_min year_max year_span mean_citations median_citations
#>     <int>    <int>    <int>     <int>          <dbl>            <dbl>
#> 1     200     2015     2024        10           15.3               12
#> # ℹ 7 more variables: total_citations <int>, n_types <int>, n_sources <int>,
#> #   n_oa <int>, pct_oa <dbl>, n_retracted <int>, n_languages <int>
```

# Summary statistics by publication period

Computes per-year summary statistics for works in the corpus.

## Usage

``` r
sm_summary_period(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object.

- call:

  Caller environment for error reporting.

## Value

A tibble with one row per year and columns: `year`, `n_works`,
`mean_citations`, `median_citations`, `total_citations`, `n_oa`,
`pct_oa`, `n_authors` (unique authors active in that year),
`mean_authors_per_work`.

## See also

Other metrics:
[`sm_metric_collab_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://r-heller.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://r-heller.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_h_index.md),
[`sm_metric_m_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://r-heller.github.io/scimapR/reference/sm_metric_novelty.md),
[`sm_metric_rcr()`](https://r-heller.github.io/scimapR/reference/sm_metric_rcr.md),
[`sm_summary_authors()`](https://r-heller.github.io/scimapR/reference/sm_summary_authors.md),
[`sm_summary_sources()`](https://r-heller.github.io/scimapR/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://r-heller.github.io/scimapR/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_summary_period(corpus)
#> # A tibble: 10 × 9
#>     year n_works mean_citations median_citations total_citations  n_oa pct_oa
#>    <int>   <int>          <dbl>            <dbl>           <int> <int>  <dbl>
#>  1  2015      17           14.2             10               241     8   47.1
#>  2  2016      18           15.3             16               275     9   50  
#>  3  2017      17           11.8             10               201     8   47.1
#>  4  2018      21           15.5             12               325     7   33.3
#>  5  2019      17           16               12               272    10   58.8
#>  6  2020      27           14               11               378    18   66.7
#>  7  2021      18           23.8             22.5             428    10   55.6
#>  8  2022       9           14               12               126     4   44.4
#>  9  2023      25           15.6             10               390    18   72  
#> 10  2024      31           13.4             10               417    21   67.7
#> # ℹ 2 more variables: n_authors <int>, mean_authors_per_work <dbl>
```

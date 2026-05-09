# Summary statistics for authors

Computes aggregate summary statistics for authors in the corpus.

## Usage

``` r
sm_summary_authors(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object.

- call:

  Caller environment for error reporting.

## Value

A tibble with one row containing: `n_authors`, `n_with_orcid`,
`pct_orcid`, `mean_works_per_author`, `median_works_per_author`,
`max_works_per_author`, `mean_authors_per_work`, `single_author_pct`.

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
[`sm_summary_period()`](https://cttir.github.io/scimapR/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://cttir.github.io/scimapR/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://cttir.github.io/scimapR/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_summary_authors(corpus)
#> # A tibble: 1 × 8
#>   n_authors n_with_orcid pct_orcid mean_works_per_author median_works_per_author
#>       <int>        <int>     <dbl>                 <dbl>                   <dbl>
#> 1        80           45      56.2                  9.44                       9
#> # ℹ 3 more variables: max_works_per_author <int>, mean_authors_per_work <dbl>,
#> #   single_author_pct <dbl>
```

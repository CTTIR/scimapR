# Calculate h-index

Computes the h-index for entities at the specified level. An entity has
h-index *h* if *h* of its works have at least *h* citations each.

## Usage

``` r
sm_metric_h_index(
  corpus,
  level = c("author", "institution", "source", "country"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object.

- level:

  Character; the entity level. One of `"author"` (default),
  `"institution"`, `"source"`, or `"country"`.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns for the entity ID/name and `h_index`.

## See also

Other metrics:
[`sm_metric_collab_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://r-heller.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://r-heller.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_m_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://r-heller.github.io/scimapR/reference/sm_metric_novelty.md),
[`sm_metric_rcr()`](https://r-heller.github.io/scimapR/reference/sm_metric_rcr.md),
[`sm_summary_authors()`](https://r-heller.github.io/scimapR/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://r-heller.github.io/scimapR/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://r-heller.github.io/scimapR/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://r-heller.github.io/scimapR/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_metric_h_index(corpus, level = "author")
#> # A tibble: 80 × 2
#>    author_id  h_index
#>    <chr>        <int>
#>  1 A000000001      14
#>  2 A000000032      11
#>  3 A000000042      11
#>  4 A000000013      10
#>  5 A000000038      10
#>  6 A000000015       9
#>  7 A000000020       9
#>  8 A000000022       9
#>  9 A000000036       9
#> 10 A000000045       9
#> # ℹ 70 more rows
```

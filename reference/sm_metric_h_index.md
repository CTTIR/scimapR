# Calculate h-index

Computes the h-index for entities at the specified level. An entity has
h-index *h* if *h* of its works have at least *h* citations each.

## Usage

``` r
sm_metric_h_index(
  corpus,
  level = c("author", "institution", "source", "country"),
  self_corrected = FALSE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object.

- level:

  Character; the entity level. One of `"author"` (default),
  `"institution"`, `"source"`, or `"country"`.

- self_corrected:

  Logical (default `FALSE`). When `TRUE`, self-citations identified by
  [`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md)
  are removed before computing the index (each work's citation count is
  reduced by the entity's internal self-citations to it, floored at 0).
  Only available for `"author"` and `"institution"` levels. The
  corrected index is always `<=` the uncorrected one.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns for the entity ID/name and `h_index`.

## Details

Self-correction uses the corpus's internal reference network (no API
calls): citations counted against a work are reduced by those coming
from works that share the entity. Because the network is internal to the
corpus, this is a lower-bound correction on the global `cited_by_count`.

## See also

[`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md)

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_m_index()`](https://cttir.github.io/scimapR/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://cttir.github.io/scimapR/reference/sm_metric_novelty.md),
[`sm_metric_rcr()`](https://cttir.github.io/scimapR/reference/sm_metric_rcr.md),
[`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md),
[`sm_summary_authors()`](https://cttir.github.io/scimapR/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://cttir.github.io/scimapR/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://cttir.github.io/scimapR/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://cttir.github.io/scimapR/reference/sm_summary_works.md)

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

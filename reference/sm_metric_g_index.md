# Calculate g-index

Computes the g-index for entities at the specified level. The g-index is
the largest *g* such that the top *g* works have at least *g*^2
citations in total (Egghe, 2006).

## Usage

``` r
sm_metric_g_index(
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

  Character; the entity level. Defaults to `"author"`.

- self_corrected:

  Logical (default `FALSE`); remove self-citations
  ([`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md))
  before computing the index. Author/institution only.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns for the entity ID/name and `g_index`.

## See also

[`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md)

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_h_index()`](https://cttir.github.io/scimapR/reference/sm_metric_h_index.md),
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
sm_metric_g_index(corpus, level = "author")
#> # A tibble: 80 × 2
#>    author_id  g_index
#>    <chr>        <int>
#>  1 A000000001      20
#>  2 A000000032      16
#>  3 A000000042      16
#>  4 A000000038      15
#>  5 A000000020      14
#>  6 A000000022      14
#>  7 A000000013      13
#>  8 A000000015      13
#>  9 A000000037      13
#> 10 A000000076      13
#> # ℹ 70 more rows
```

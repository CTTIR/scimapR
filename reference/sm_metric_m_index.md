# Calculate m-index (m-quotient)

Computes the m-index (m-quotient) for entities at the specified level.
The m-index equals the h-index divided by the number of years since the
entity's first publication (Hirsch, 2005).

## Usage

``` r
sm_metric_m_index(
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

A tibble with columns for the entity ID/name, `h_index`, `first_year`,
`career_years`, and `m_index`.

## See also

[`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md)

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://cttir.github.io/scimapR/reference/sm_metric_h_index.md),
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
sm_metric_m_index(corpus, level = "author")
#> # A tibble: 80 × 5
#>    author_id  h_index first_year career_years m_index
#>    <chr>        <int>      <int>        <int>   <dbl>
#>  1 A000000001      14       2015           11   1.27 
#>  2 A000000032      11       2016           10   1.1  
#>  3 A000000042      11       2016           10   1.1  
#>  4 A000000013      10       2016           10   1    
#>  5 A000000074       9       2017            9   1    
#>  6 A000000038      10       2015           11   0.909
#>  7 A000000022       9       2016           10   0.9  
#>  8 A000000021       8       2017            9   0.889
#>  9 A000000015       9       2015           11   0.818
#> 10 A000000020       9       2015           11   0.818
#> # ℹ 70 more rows
```

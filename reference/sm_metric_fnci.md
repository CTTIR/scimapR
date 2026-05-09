# Calculate Field-Normalized Citation Impact

Computes the Field-Normalized Citation Impact (FNCI) for each work in
the corpus. FNCI normalises a work's citation count by the average
citation count of all works in the same field and publication year.

## Usage

``` r
sm_metric_fnci(
  corpus,
  classification = c("openalex_concepts", "mesh", "manual"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object.

- classification:

  Character; the classification system used to assign works to fields.
  One of `"openalex_concepts"` (default), `"mesh"`, or `"manual"`.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns `work_id`, `field`, `year`, `cited_by_count`,
`field_mean`, and `fnci`.

## Details

FNCI is defined as:

\$\$FNCI_i = \frac{C_i}{\bar{C}\_{f,y}}\$\$

Where \\C_i\\ is the citation count of work *i* and \\\bar{C}\_{f,y}\\
is the mean citation count of all works in field *f* published in year
*y*.

An FNCI of 1.0 means the work is cited at the world average for its
field-year. Values \> 1.0 indicate above-average impact.

For `"openalex_concepts"`, the highest-scoring level-0 concept from the
concepts table is used. For `"mesh"`, MeSH terms are used (requires MeSH
data in concepts). For `"manual"`, a `field` column must already exist
in `corpus$works`.

## References

Waltman, L., van Eck, N. J., van Leeuwen, T. N., Visser, M. S., & van
Raan, A. F. J. (2011). Towards a New Crown Indicator: Some Theoretical
Considerations. *Journal of Informetrics*, 5(1), 37–47.
[doi:10.1016/j.joi.2010.08.001](https://doi.org/10.1016/j.joi.2010.08.001)

## See also

Other metrics:
[`sm_metric_collab_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://r-heller.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_g_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_h_index.md),
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
fnci <- sm_metric_fnci(corpus, classification = "openalex_concepts")
head(fnci)
#> # A tibble: 6 × 6
#>   work_id    field                    year cited_by_count field_mean  fnci
#>   <chr>      <chr>                   <int>          <int>      <dbl> <dbl>
#> 1 W000000001 clinical outcomes        2023              3       10.2 0.293
#> 2 W000000002 colorectal cancer        2020              9       12.2 0.738
#> 3 W000000003 gene expression          2024             28       11.3 2.47 
#> 4 W000000004 spatial transcriptomics  2020             29       27.5 1.05 
#> 5 W000000005 immune checkpoint        2020             16       16   1    
#> 6 W000000006 immune checkpoint        2018             16       16   1    
```

# Calculate Relative Citation Ratio

Computes the Relative Citation Ratio (RCR) for each work in the corpus.
RCR normalises citation counts by the expected citation rate of works in
the same field and publication year, providing a field-normalised
measure of scientific influence.

## Usage

``` r
sm_metric_rcr(corpus, baseline = "field_year", call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object.

- baseline:

  Character; the normalisation baseline. Currently only `"field_year"`
  is supported, which normalises by field (derived from concepts) and
  publication year.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns `work_id`, `cited_by_count`, `expected_rate`, and
`rcr`. Works without sufficient data receive `NA` for `rcr`.

## Details

The RCR is calculated as:

\$\$RCR = \frac{C_i}{E_i}\$\$

Where:

- C_i:

  The citation count of work *i*.

- E_i:

  The expected citation count, computed as the mean citation count of
  works in the same field-year group.

Field assignment uses the top-level concept (level 0) from the concepts
table. Works without concept assignments are grouped into an
"unclassified" field.

An RCR of 1.0 means the work is cited at the average rate for its
field-year. Values above 1.0 indicate above-average impact.

## References

Hutchins, B. I., Yuan, X., Anderson, J. M., & Santangelo, G. M. (2016).
Relative Citation Ratio (RCR): A New Metric That Uses Citation Rates to
Measure Influence at the Article Level. *PLOS Biology*, 14(9), e1002541.
[doi:10.1371/journal.pbio.1002541](https://doi.org/10.1371/journal.pbio.1002541)

## See also

Other metrics:
[`sm_metric_collab_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://r-heller.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://r-heller.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_h_index.md),
[`sm_metric_m_index()`](https://r-heller.github.io/scimapR/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://r-heller.github.io/scimapR/reference/sm_metric_novelty.md),
[`sm_summary_authors()`](https://r-heller.github.io/scimapR/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://r-heller.github.io/scimapR/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://r-heller.github.io/scimapR/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://r-heller.github.io/scimapR/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
rcr <- sm_metric_rcr(corpus)
head(rcr)
#> # A tibble: 6 × 4
#>   work_id    cited_by_count expected_rate   rcr
#>   <chr>               <int>         <dbl> <dbl>
#> 1 W000000001              3          10.2 0.293
#> 2 W000000002              9          12.2 0.738
#> 3 W000000003             28          11.3 2.47 
#> 4 W000000004             29          27.5 1.05 
#> 5 W000000005             16          16   1    
#> 6 W000000006             16          16   1    
```

# Calculate the CD (disruption) index

Computes the CD index (Funk & Owen-Smith, 2017) for each work in the
corpus. The CD index measures how disruptive a work is by comparing the
citation patterns of papers that cite the focal work versus those that
cite its references.

## Usage

``` r
sm_metric_disruption(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object with a populated `references` table.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns `work_id` and `cd_index`. The CD index ranges from
-1 (consolidating) to +1 (disruptive). Works without sufficient citation
data receive `NA`.

## Details

The CD index is defined as:

\$\$CD = \frac{n_i - n_j}{n_i + n_j + n_k}\$\$

Where for a focal work *f*:

- n_i:

  Number of works that cite *f* but do NOT cite any of *f*'s references
  (disruptive citations).

- n_j:

  Number of works that cite BOTH *f* and at least one of *f*'s
  references (consolidating citations).

- n_k:

  Number of works that cite at least one of *f*'s references but do NOT
  cite *f* (ignored-but-referencing citations).

A CD index near +1 indicates the focal work is highly disruptive: its
citers tend to ignore its references. A CD index near -1 indicates the
focal work consolidates existing ideas.

## References

Funk, R. J., & Owen-Smith, J. (2017). A Dynamic Network Measure of
Technological Change. *Management Science*, 63(3), 791–817.
[doi:10.1287/mnsc.2015.2366](https://doi.org/10.1287/mnsc.2015.2366)

## See also

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/reference/sm_metric_g_index.md),
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
cd <- sm_metric_disruption(corpus)
head(cd)
#> # A tibble: 6 × 2
#>   work_id    cd_index
#>   <chr>         <dbl>
#> 1 W000000001   0     
#> 2 W000000002   0.0101
#> 3 W000000003  -0.0642
#> 4 W000000004   0.167 
#> 5 W000000005   0.0303
#> 6 W000000006   0.188 
```

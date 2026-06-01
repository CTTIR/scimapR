# Calculate Uzzi novelty score

Computes the Uzzi et al. (2013) novelty score for each work based on
atypical combinations of cited journals. A work is novel if its
reference list contains unusual journal pairings – combinations that are
rarely seen together in the broader literature.

## Usage

``` r
sm_metric_novelty(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object with populated `references` and `works` tables. Works and their
  references should have `source_id` assignments.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns `work_id` and `novelty`. Higher values indicate
more novel (atypical) journal combinations. Works with insufficient data
receive `NA`.

## Details

The algorithm:

1.  For each work, identify the journals (sources) of its cited
    references.

2.  Enumerate all pairwise journal combinations in each reference list.

3.  Compute the observed frequency of each journal pair across all
    works.

4.  Compute the expected frequency under independence (product of
    marginal frequencies).

5.  The novelty score for a work is the median of \\-\log\_{10}(observed
    / expected)\\ across all its journal pairs. High values indicate
    atypical combinations.

Works with fewer than 2 references with known journals receive `NA`.

## References

Uzzi, B., Mukherjee, S., Stringer, M., & Jones, B. (2013). Atypical
Combinations and Scientific Impact. *Science*, 342(6157), 468–472.
[doi:10.1126/science.1240474](https://doi.org/10.1126/science.1240474)

## See also

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://cttir.github.io/scimapR/reference/sm_metric_h_index.md),
[`sm_metric_m_index()`](https://cttir.github.io/scimapR/reference/sm_metric_m_index.md),
[`sm_metric_rcr()`](https://cttir.github.io/scimapR/reference/sm_metric_rcr.md),
[`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md),
[`sm_summary_authors()`](https://cttir.github.io/scimapR/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://cttir.github.io/scimapR/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://cttir.github.io/scimapR/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://cttir.github.io/scimapR/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
nov <- sm_metric_novelty(corpus)
head(nov)
#> # A tibble: 6 × 2
#>   work_id    novelty
#>   <chr>        <dbl>
#> 1 W000000001  -0.323
#> 2 W000000002  -0.384
#> 3 W000000003  -0.335
#> 4 W000000004  -0.313
#> 5 W000000005  -0.345
#> 6 W000000006  -0.378
```

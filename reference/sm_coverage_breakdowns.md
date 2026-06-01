# Coverage breakdowns as a flat tibble

Accessor returning the per-dimension coverage breakdowns of an
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)
result as a single flat tibble (`dimension`, `level`, `n_reference`,
`n_matched`, `recall`), optionally filtered to one dimension.

## Usage

``` r
sm_coverage_breakdowns(x, dimension = NULL)
```

## Arguments

- x:

  An `sm_coverage` object.

- dimension:

  Optional dimension name (e.g. `"year"`) to filter to.

## Value

A tibble. Type-stable: returns a 0-row tibble with the documented
columns when there are no breakdowns.

## See also

[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)

Other coverage:
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md),
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 30, seed = 1)
ref <- corpus$works[1:25, c("work_id", "doi", "title", "year")]
cov <- sm_coverage_audit(corpus, ref, by = "year")
sm_coverage_breakdowns(cov, dimension = "year")
#> # A tibble: 9 × 5
#>   dimension level n_reference n_matched recall
#>   <chr>     <chr>       <int>     <int>  <dbl>
#> 1 year      2015            1         1      1
#> 2 year      2016            2         2      1
#> 3 year      2017            2         2      1
#> 4 year      2018            2         2      1
#> 5 year      2020            6         6      1
#> 6 year      2021            3         3      1
#> 7 year      2022            3         3      1
#> 8 year      2023            3         3      1
#> 9 year      2024            3         3      1
```

# Coverage breakdowns as a flat tibble

Accessor returning the per-dimension coverage breakdowns of an
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)
result as a single flat (long) tibble, optionally filtered to one
dimension.

## Usage

``` r
sm_coverage_breakdowns(x, dimension = NULL, tidy = TRUE)
```

## Arguments

- x:

  An `sm_coverage` object.

- dimension:

  Optional dimension name (e.g. `"year"`) to filter to.

- tidy:

  Logical (default `TRUE`). The stable long contract: returns columns
  `dimension`, `level`, `n_reference`, `n_matched`, `recall`,
  `n_corpus`, `precision`, `f1`. With `tidy = FALSE`, the legacy
  recall-only shape (`dimension`, `level`, `n_reference`, `n_matched`,
  `recall`) is returned for backward compatibility.

## Value

A tibble (see `tidy`). Type-stable: a 0-row tibble with the documented
columns when there are no breakdowns. Slices present on only one side
(corpus vs reference) carry `NA` in the other side's counts/metric.

## Details

This accessor honours the package's accessor return-type stability
contract (see
[scimapR-stability](https://cttir.github.io/scimapR/reference/scimapR-stability.md)):
with `tidy = TRUE` the column set is guaranteed and will only change via
a `lifecycle` deprecation.

## See also

[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[scimapR-stability](https://cttir.github.io/scimapR/reference/scimapR-stability.md)

Other coverage:
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md),
[`sm_match_types()`](https://cttir.github.io/scimapR/reference/sm_match_types.md),
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 30, seed = 1)
ref <- corpus$works[1:25, c("work_id", "doi", "title", "year")]
cov <- sm_coverage_audit(corpus, ref, by = "year")
sm_coverage_breakdowns(cov, dimension = "year")
#> # A tibble: 9 × 8
#>   dimension level n_reference n_matched recall n_corpus precision    f1
#>   <chr>     <chr>       <int>     <int>  <dbl>    <int>     <dbl> <dbl>
#> 1 year      2015            1         1      1        1     1     1    
#> 2 year      2016            2         2      1        2     1     1    
#> 3 year      2017            2         2      1        3     0.667 0.8  
#> 4 year      2018            2         2      1        2     1     1    
#> 5 year      2020            6         6      1        8     0.75  0.857
#> 6 year      2021            3         3      1        4     0.75  0.857
#> 7 year      2022            3         3      1        4     0.75  0.857
#> 8 year      2023            3         3      1        3     1     1    
#> 9 year      2024            3         3      1        3     1     1    
```

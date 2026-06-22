# Check corpus staleness

Inspects each work in a corpus and reports how long ago it was last
refreshed. Works with `last_refreshed` older than 30 days are flagged as
stale. This is useful before calling
[`sm_refresh()`](https://cttir.github.io/scimapR/reference/sm_refresh.md)
to preview which works would be updated.

## Usage

``` r
sm_staleness(corpus, threshold_days = 30, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- threshold_days:

  Numeric. Number of days after which a work is considered stale.
  Defaults to 30.

- call:

  Caller environment for error reporting.

## Value

A tibble with columns:

- work_id:

  Work identifier.

- last_refreshed:

  POSIXct timestamp of last refresh.

- age_days:

  Number of days since last refresh.

- is_stale:

  Logical; `TRUE` if `age_days > threshold_days`.

## See also

Other refresh:
[`sm_lock()`](https://cttir.github.io/scimapR/reference/sm_lock.md),
[`sm_refresh()`](https://cttir.github.io/scimapR/reference/sm_refresh.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_staleness(corpus)
#> ℹ 0 of 200 works are stale (>30 days).
#> # A tibble: 200 × 4
#>    work_id    last_refreshed        age_days is_stale
#>    <chr>      <dttm>                   <dbl> <lgl>   
#>  1 W000000001 2026-06-22 09:28:35 0.00000952 FALSE   
#>  2 W000000002 2026-06-22 09:28:35 0.00000952 FALSE   
#>  3 W000000003 2026-06-22 09:28:35 0.00000952 FALSE   
#>  4 W000000004 2026-06-22 09:28:35 0.00000952 FALSE   
#>  5 W000000005 2026-06-22 09:28:35 0.00000952 FALSE   
#>  6 W000000006 2026-06-22 09:28:35 0.00000952 FALSE   
#>  7 W000000007 2026-06-22 09:28:35 0.00000952 FALSE   
#>  8 W000000008 2026-06-22 09:28:35 0.00000952 FALSE   
#>  9 W000000009 2026-06-22 09:28:35 0.00000952 FALSE   
#> 10 W000000010 2026-06-22 09:28:35 0.00000952 FALSE   
#> # ℹ 190 more rows
```

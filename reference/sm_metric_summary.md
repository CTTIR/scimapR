# Robust summary of a heavy-tailed impact metric

Summarises a work-level impact metric robustly. Citation-based metrics
are heavy-tailed, so the mean is a poor central estimate; this function
reports the median with a bootstrap confidence interval and the
proportion of papers in the global top 10% by citations
(`%PP(top 10%)`), alongside the mean for comparison.

## Usage

``` r
sm_metric_summary(
  corpus,
  metric = c("citations", "cnci", "rcr"),
  robust = TRUE,
  n_boot = 2000L,
  conf = 0.95,
  top_pct = 0.1,
  seed = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- metric:

  Which work-level metric to summarise: `"citations"`
  (`cited_by_count`), `"cnci"` (field-normalised citation impact via
  [`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md)),
  or `"rcr"`
  ([`sm_metric_rcr()`](https://cttir.github.io/scimapR/reference/sm_metric_rcr.md)).

- robust:

  Logical (default `TRUE`). When `TRUE`, report the median with a
  bootstrap CI and `pp_top10`. When `FALSE`, report only `n`, `mean`,
  and `median` (no resampling).

- n_boot:

  Number of bootstrap resamples for the median CI (default `2000`).

- conf:

  Confidence level for the bootstrap interval (default `0.95`).

- top_pct:

  Top-fraction threshold for `pp_top10` (default `0.1`, i.e. the top 10%
  of works by citation count within the corpus).

- seed:

  Optional integer seed for reproducible bootstrap resampling. When
  supplied, the RNG state is saved and restored so the call has no
  global side effect (mirroring scimapR's reproducibility guarantees).

- call:

  Caller environment for error reporting.

## Value

A one-row tibble: `metric`, `n`, `mean`, `median`, and – when
`robust = TRUE` – `median_ci_low`, `median_ci_high`, `pp_top10`,
`n_boot`. Type-stable: an empty corpus returns a one-row tibble with
`n = 0` and `NA` statistics.

## Details

The bootstrap uses base-R resampling by default; if the optional boot
package is installed it is used instead (percentile interval).
`pp_top10` is computed against the within-corpus citation distribution
(the global top-10% threshold is the upper `top_pct` quantile of
`cited_by_count`).

## See also

[`sm_summary_works()`](https://cttir.github.io/scimapR/reference/sm_summary_works.md),
[`sm_count()`](https://cttir.github.io/scimapR/reference/sm_count.md)

Other counting:
[`sm_citation_maturity()`](https://cttir.github.io/scimapR/reference/sm_citation_maturity.md),
[`sm_count()`](https://cttir.github.io/scimapR/reference/sm_count.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 100, seed = 1)
sm_metric_summary(corpus, metric = "citations", seed = 1)
#> # A tibble: 1 × 8
#>   metric        n  mean median median_ci_low median_ci_high pp_top10 n_boot
#>   <chr>     <int> <dbl>  <dbl>         <dbl>          <dbl>    <dbl>  <int>
#> 1 citations   100  15.9     12          10.5             16      0.1   2000
```

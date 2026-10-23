# Robust summary of a heavy-tailed impact metric

Summarises a work-level impact metric robustly. Citation-based metrics
are heavy-tailed, so the mean is a poor central estimate; this function
reports the median with a bootstrap confidence interval and the
proportion of papers in the top citation fraction of a chosen reference,
alongside the mean. Without an external reference, `pp_top10` equals
`top_pct` by construction and does not measure impact relative to other
publications.

## Usage

``` r
sm_metric_summary(
  corpus,
  metric = c("citations", "cnci", "rcr", "fwci"),
  robust = TRUE,
  n_boot = 2000L,
  conf = 0.95,
  top_pct = 0.1,
  seed = NULL,
  min_cell = NULL,
  top_reference = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- metric:

  Which work-level metric to summarise: `"citations"`
  (`cited_by_count`), `"cnci"` (field-normalised citation impact,
  resolved as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md):
  a stored impact column such as `works$cnci` or `works$fwci`, a
  `corpus$metrics` table, else the FNCI that
  [`sm_metric_fnci()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_fnci.md)
  derives from citation counts), `"rcr"`
  ([`sm_metric_rcr()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_rcr.md))
  or `"fwci"` (OpenAlex's field-weighted citation impact, `works$fwci`;
  see
  [`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md)).

- robust:

  Logical (default `TRUE`). When `TRUE`, report the median with a
  bootstrap CI and `pp_top10`. When `FALSE`, report only `n`, `mean`,
  and `median` (no resampling).

- n_boot:

  Number of bootstrap resamples for the median CI (default `2000`).

- conf:

  Confidence level for the bootstrap interval (default `0.95`).

- top_pct:

  Single number strictly between 0 and 1: the top fraction of the
  reference distribution (default `0.1`). Ties share credit
  fractionally. The output column remains named `pp_top10` for any
  fraction.

- seed:

  Optional integer seed for reproducible bootstrap resampling. When
  supplied, the RNG state is saved and restored so the call has no
  global side effect (mirroring scimapR's reproducibility guarantees).

- min_cell:

  For `metric = "cnci"`: `NULL` (default) or a positive integer, passed
  to
  [`sm_metric_fnci()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_fnci.md)
  when the impact is derived from citation counts, as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).

- top_reference:

  Reference for `pp_top10`: `NULL` uses the corpus itself; a numeric
  vector supplies citation counts (at least two after dropping `NA`); a
  data frame supplies numeric `cited_by_count` and optionally `year`
  and/or `field`, matched on keys present in both it and `works`.
  Missing keys or unmatched cells are excluded with a message; no
  matching works gives `NA`. Reference counts must be finite and
  non-negative. Data-frame cells may contain a single reference work.
  `"openalex"` uses `is_top_10pct` for `top_pct = 0.1` or `is_top_1pct`
  for `0.01`, averaging non-missing flags; see
  [`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md).

- call:

  Caller environment for error reporting.

## Value

A one-row tibble: `metric`, `n`, `mean`, `median`, and – when
`robust = TRUE` – `median_ci_low`, `median_ci_high`, `pp_top10`,
`n_boot`. Type-stable: an empty corpus, or for `"cnci"` a corpus without
usable impact data, returns a one-row tibble with `n = 0` and `NA`
statistics. The attribute `impact_source` (character) names where the
values come from: for `"cnci"` the same label as the `impact_source` of
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
(such as `"works$fwci (OpenAlex)"`), for `"fwci"`
`"works$fwci (OpenAlex)"`, for `"citations"` `"works$cited_by_count"`
and for `"rcr"` `"sm_metric_rcr()"`; it is `NA` on the `n = 0` row. For
`"cnci"` and `"fwci"` a message (class `scimapR_impact_source`) names
the source too.

## Details

The bootstrap uses base-R resampling by default; if the optional boot
package is installed it is used instead (percentile interval).
`pp_top10` remains citation-based for every `metric`; `top_reference`
changes neither the metric summary nor the bootstrap. Tied citation
counts share the part of their reference block in the top fraction
equally, following Waltman and Schreiber (2013). Using the corpus itself
gives `top_pct` exactly before rounding. An external reference from
comparable fields and years, or OpenAlex flags, makes this an
informative share.

For `"cnci"` and `"fwci"` only works with a finite value count, and for
`"cnci"` only works of `corpus$works` (a `corpus$metrics` table may hold
others). `metric = "fwci"` aborts (class `scimapR_no_fwci`) when the
works have no `fwci` value.

## References

Waltman, L., & Schreiber, M. (2013). On the calculation of
percentile-based bibliometric indicators. Journal of the American
Society for Information Science and Technology, 64(2), 372–379.

## See also

[`sm_summary_works()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_works.md),
[`sm_count()`](https://cttir.github.io/scimapR/dev/reference/sm_count.md)

Other counting:
[`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md),
[`sm_citation_window()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_window.md),
[`sm_count()`](https://cttir.github.io/scimapR/dev/reference/sm_count.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 100, seed = 1)
sm_metric_summary(corpus, metric = "citations", seed = 1)
#> # A tibble: 1 × 8
#>   metric        n  mean median median_ci_low median_ci_high pp_top10 n_boot
#>   <chr>     <int> <dbl>  <dbl>         <dbl>          <dbl>    <dbl>  <int>
#> 1 citations   100  15.9     12          10.5             16      0.1   2000

# the real-use fixture carries OpenAlex's FWCI, which "cnci" then uses
fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
s <- sm_metric_summary(fix, metric = "cnci", robust = FALSE)
#> ℹ Impact source: works$fwci (OpenAlex).
attr(s, "impact_source")
#> [1] "works$fwci (OpenAlex)"
```

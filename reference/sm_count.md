# Full and fractional output / impact counting

Attributes publication output (and citation impact) to entities using
either full or fractional counting. Reviewers routinely ask for
fractional counts so that a single multi-author / multi-institution
paper is not counted in full for every contributor.

## Usage

``` r
sm_count(
  corpus,
  method = c("full", "fractional"),
  level = c("institution", "author", "source"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- method:

  `"full"` (default) gives each entity credit 1 per work it appears on.
  `"fractional"` splits each work's single unit of credit equally among
  the distinct entities on that work.

- level:

  Entity level: `"institution"` (default), `"author"`, or `"source"`.

- call:

  Caller environment for error reporting.

## Value

A tibble, one row per entity, sorted by `credit` descending:

- entity_id:

  Entity identifier.

- entity_name:

  Human-readable name (falls back to `entity_id`).

- n_works:

  Number of distinct works the entity appears on (this is the full count
  and is identical for both methods).

- credit:

  Output credit: `n_works` under `"full"`; the sum of per-work
  fractional shares under `"fractional"`.

- weighted_citations:

  Citation impact attributed to the entity: summed `cited_by_count`
  under `"full"`; summed fractional-share weighted `cited_by_count`
  under `"fractional"`.

Type-stable: an empty/inapplicable corpus returns a 0-row tibble with
these columns.

## Details

The fractional rule is the standard equal-share rule: a work with \\k\\
distinct entities contributes \\1/k\\ of credit (and \\1/k\\ of its
citations) to each. For `level = "source"` each work has a single
source, so fractional and full counts coincide.

## See also

[`sm_metric_summary()`](https://cttir.github.io/scimapR/reference/sm_metric_summary.md)

Other counting:
[`sm_citation_maturity()`](https://cttir.github.io/scimapR/reference/sm_citation_maturity.md),
[`sm_metric_summary()`](https://cttir.github.io/scimapR/reference/sm_metric_summary.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 30, seed = 1)
sm_count(corpus, method = "fractional", level = "author")
#> # A tibble: 58 × 5
#>    entity_id  entity_name      n_works credit weighted_citations
#>    <chr>      <chr>              <int>  <dbl>              <dbl>
#>  1 A000000001 Fatima Liu            30  7.04              100.  
#>  2 A000000002 Fatima Andersson       5  0.910               7.33
#>  3 A000000015 Sarah Tanaka           3  0.811               9.39
#>  4 A000000020 Maria Smith            3  0.792              15.0 
#>  5 A000000025 Erik Wang              3  0.783               4.58
#>  6 A000000039 James Patel            4  0.761              10.0 
#>  7 A000000016 Mohammed Brown         3  0.7                 7.2 
#>  8 A000000050 Mei Santos             3  0.65               14.4 
#>  9 A000000006 Fatima Brown           3  0.644               3.42
#> 10 A000000040 Lars Garcia            2  0.625               2.88
#> # ℹ 48 more rows
```

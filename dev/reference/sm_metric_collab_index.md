# Calculate collaboration index

Computes several collaboration indicators for the corpus, including the
Collaboration Index (CI), mean authors per paper, proportion of
multi-authored papers, and international collaboration rate.

## Usage

``` r
sm_metric_collab_index(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object with a populated `authorships` table.

- call:

  Caller environment for error reporting.

## Value

A tibble with one row per work and columns:

- `work_id`:

  The work identifier.

- `n_authors`:

  Number of authors on the work.

- `n_countries`:

  Distinct known countries; `NA` if none are known.

- `n_institutions`:

  Distinct known `institution_id` values; `NA` if none are known.
  Affiliation match labels are not counted.

- `is_international`:

  Logical; `TRUE` if more than one country is known; `FALSE` if exactly
  one is known, and `NA` if none are known. Missing codes can hide
  international collaboration.

- `is_multi_authored`:

  Logical; `TRUE` if more than one author.

## Details

The Collaboration Index (CI) for a set of works is typically defined as
the mean number of authors per paper. This function returns per-work
data, from which aggregate CI can be computed by the user. Country and
institution counts are `NA` when no non-blank value is known. With one
known country, `is_international` is `FALSE`, even if some affiliations
are missing. Institutions are counted by `institution_id` only; names
and affiliation text are not matched.

## See also

Other metrics:
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_h_index.md),
[`sm_metric_m_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_novelty.md),
[`sm_metric_rcr()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_rcr.md),
[`sm_self_citation()`](https://cttir.github.io/scimapR/dev/reference/sm_self_citation.md),
[`sm_summary_authors()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
collab <- sm_metric_collab_index(corpus)
head(collab)
#> # A tibble: 6 × 6
#>   work_id    n_authors n_countries n_institutions is_international
#>   <chr>          <int>       <int>          <int> <lgl>           
#> 1 W000000001         1           1             NA FALSE           
#> 2 W000000002         6           4             NA TRUE            
#> 3 W000000003         4           4             NA TRUE            
#> 4 W000000004         5           5             NA TRUE            
#> 5 W000000005         4           3             NA TRUE            
#> 6 W000000006         1           1             NA FALSE           
#> # ℹ 1 more variable: is_multi_authored <lgl>
# Aggregate collaboration index:
mean(collab$n_authors)
#> [1] 3.775
```

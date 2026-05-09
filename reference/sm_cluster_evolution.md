# Track cluster evolution over time

Analyses how research clusters evolve across time windows. For each pair
of consecutive windows, clusters are linked by measuring the Jaccard
similarity of their member works (or, more commonly, the overlap of
terms).

## Usage

``` r
sm_cluster_evolution(
  corpus,
  time_windows = NULL,
  link_threshold = 0.3,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object with a `cluster_id` column in `corpus$works` and a `year`
  column.

- time_windows:

  A list of integer vectors defining year ranges for each window, or
  `NULL` (default). If `NULL`, windows are created automatically by
  splitting the year range into roughly equal periods.

- link_threshold:

  Numeric between 0 and 1; minimum Jaccard similarity to link two
  clusters across time windows. Defaults to `0.3`.

- call:

  Caller environment for error reporting.

## Value

A list with two components:

- `snapshots`:

  A tibble with columns `window`, `cluster_id`, `n_works`, `top_terms`
  (a character string of representative terms).

- `transitions`:

  A tibble with columns `from_window`, `to_window`, `from_cluster`,
  `to_cluster`, `jaccard`, `n_shared`.

## Details

The function:

1.  Splits works into time windows.

2.  Within each window, identifies the cluster composition.

3.  Between consecutive windows, computes pairwise Jaccard similarity of
    clusters based on overlapping work IDs or, when works do not persist
    across windows, based on shared terms from titles.

4.  Links clusters exceeding `link_threshold`.

## See also

Other clustering:
[`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/reference/sm_cluster_hdbscan.md),
[`sm_cluster_kmeans()`](https://cttir.github.io/scimapR/reference/sm_cluster_kmeans.md),
[`sm_cluster_label()`](https://cttir.github.io/scimapR/reference/sm_cluster_label.md),
[`sm_cluster_leiden()`](https://cttir.github.io/scimapR/reference/sm_cluster_leiden.md)

## Examples

``` r
corpus <- sm_example_corpus(with_embeddings = TRUE)
corpus <- sm_cluster_kmeans(corpus, k = 5)
#> ✔ K-means clustering complete.
#> ℹ 5 clusters, sizes range from 27 to 49.
evo <- sm_cluster_evolution(corpus)
#> ✔ Cluster evolution computed across 3 time windows.
#> ℹ 50 transitions found above threshold 0.3.
evo$snapshots
#> # A tibble: 15 × 4
#>    window    cluster_id n_works top_terms                                       
#>    <chr>          <int>   <int> <chr>                                           
#>  1 2015-2017          1      12 spatial; transcriptomics; meta; biomarker; canc…
#>  2 2015-2017          2       8 expression; gene; biomarker; cross; discovery   
#>  3 2015-2017          3       8 clinical; outcomes; spatial; transcriptomics; c…
#>  4 2015-2017          4      11 spatial; transcriptomics; biomarker; cell; clin…
#>  5 2015-2017          5      13 clinical; outcomes; drug; resistance; cross     
#>  6 2018-2020          1      14 cancer; colorectal; randomized; trial; cell     
#>  7 2018-2020          2       7 cell; clinical; cohort; outcomes; rna           
#>  8 2018-2020          3      16 cell; rna; seq; single; microenvironment        
#>  9 2018-2020          4      15 clinical; outcomes; spatial; transcriptomics; e…
#> 10 2018-2020          5      13 microenvironment; tumor; biomarker; discovery; …
#> 11 2021-2024          1      14 clinical; expression; gene; outcomes; biomarker 
#> 12 2021-2024          2      12 cancer; checkpoint; colorectal; cross; immune   
#> 13 2021-2024          3      15 biomarker; cell; discovery; randomized; rna     
#> 14 2021-2024          4      19 spatial; transcriptomics; biomarker; case; cell 
#> 15 2021-2024          5      23 cancer; colorectal; drug; resistance; clinical  
evo$transitions
#> # A tibble: 50 × 6
#>    from_window to_window from_cluster to_cluster jaccard n_shared
#>    <chr>       <chr>            <int>      <int>   <dbl>    <int>
#>  1 2015-2017   2018-2020            3          3   0.871       27
#>  2 2015-2017   2018-2020            3          5   0.788       26
#>  3 2015-2017   2018-2020            3          4   0.879       29
#>  4 2015-2017   2018-2020            3          1   0.879       29
#>  5 2015-2017   2018-2020            3          2   0.742       23
#>  6 2015-2017   2018-2020            4          3   0.727       24
#>  7 2015-2017   2018-2020            4          5   0.758       25
#>  8 2015-2017   2018-2020            4          4   0.848       28
#>  9 2015-2017   2018-2020            4          1   0.848       28
#> 10 2015-2017   2018-2020            4          2   0.710       22
#> # ℹ 40 more rows
```

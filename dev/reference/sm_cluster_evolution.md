# Track cluster evolution over time

Analyses how research clusters evolve across time windows. For each pair
of consecutive windows, clusters are linked either by the overlap of the
terms in their titles (`link_by = "terms"`, the default) or, after one
clustering of the whole corpus, by their shared `cluster_id`
(`link_by = "cluster_id"`).

## Usage

``` r
sm_cluster_evolution(
  corpus,
  time_windows = NULL,
  link_threshold = 0.3,
  link_by = c("terms", "cluster_id"),
  noise = 0L,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object with a `cluster_id` column in `corpus$works` and a `year`
  column.

- time_windows:

  A list of integer vectors defining year ranges for each window, or
  `NULL` (default). If `NULL`, windows are created automatically by
  splitting the year range into roughly equal periods.

- link_threshold:

  Numeric between 0 and 1; minimum Jaccard similarity to link two
  clusters across time windows. Defaults to `0.3`. Not used with
  `link_by = "cluster_id"`.

- link_by:

  How clusters of consecutive windows are linked. `"terms"` (default)
  compares every pair of clusters by the Jaccard similarity of their
  title terms and keeps the pairs that reach `link_threshold`; use it
  when each window was clustered on its own. `"cluster_id"` follows a
  clustering of the whole corpus (for example from
  [`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_hdbscan.md)):
  every cluster present in both windows gives one transition to itself.

- noise:

  The `cluster_id` that marks noise, the works no cluster claims: `0L`
  by default, as
  [`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_hdbscan.md)
  assigns. With `link_by = "cluster_id"` noise gets no transition.
  `NULL` treats every id as a cluster; set it for clusterings that use
  another noise label or a real cluster 0. Not used with
  `link_by = "terms"`.

- call:

  Caller environment for error reporting.

## Value

A list with two components and the attribute `link_by` (the linking mode
used):

- `snapshots`:

  A tibble with columns `window`, `cluster_id`, `n_works`, `top_terms`
  (a character string of representative terms) and `share` (the
  cluster's share of the window's clustered works, noise included, so
  the shares of a window sum to 1).

- `transitions`:

  A tibble with columns `from_window`, `to_window`, `from_cluster`,
  `to_cluster`, `jaccard` (the Jaccard similarity of the two clusters'
  title terms, rounded to 4 digits; 0 when neither has any) and
  `n_shared` (the number of shared title terms).

## Details

The function:

1.  Splits works into time windows.

2.  Within each window, identifies the cluster composition.

3.  Between consecutive windows, links clusters. A work sits in exactly
    one window, so clusters cannot share works; `"terms"` therefore
    compares the terms of their titles and links the pairs whose Jaccard
    similarity reaches `link_threshold`, while `"cluster_id"` links each
    cluster to itself and reports the title-term Jaccard of its two
    windows without filtering.

With one clustering of the whole corpus, the same `cluster_id` in two
windows is the continuity, and large clusters rarely reach the term
threshold, so `"terms"` can report no transition at all. Use
`link_by = "cluster_id"` there.

## See also

Other clustering:
[`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_hdbscan.md),
[`sm_cluster_kmeans()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_kmeans.md),
[`sm_cluster_label()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_label.md),
[`sm_cluster_leiden()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_leiden.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus(with_embeddings = TRUE)
corpus <- sm_cluster_kmeans(corpus, k = 5)
#> ✔ K-means clustering complete.
#> ℹ 5 clusters, sizes range from 27 to 49.
evo <- sm_cluster_evolution(corpus)
#> ✔ Cluster evolution computed across 3 time windows.
#> ℹ 50 transitions found above threshold 0.3.
evo$snapshots
#> # A tibble: 15 × 5
#>    window    cluster_id n_works top_terms                                  share
#>    <chr>          <int>   <int> <chr>                                      <dbl>
#>  1 2015-2017          1       8 clinical; outcomes; spatial; transcriptom… 0.154
#>  2 2015-2017          2       8 expression; gene; biomarker; cross; disco… 0.154
#>  3 2015-2017          3      11 spatial; transcriptomics; biomarker; cell… 0.212
#>  4 2015-2017          4      12 spatial; transcriptomics; meta; biomarker… 0.231
#>  5 2015-2017          5      13 clinical; outcomes; drug; resistance; cro… 0.25 
#>  6 2018-2020          1      16 cell; rna; seq; single; microenvironment   0.246
#>  7 2018-2020          2       7 cell; clinical; cohort; outcomes; rna      0.108
#>  8 2018-2020          3      15 clinical; outcomes; spatial; transcriptom… 0.231
#>  9 2018-2020          4      14 cancer; colorectal; randomized; trial; ce… 0.215
#> 10 2018-2020          5      13 microenvironment; tumor; biomarker; disco… 0.2  
#> 11 2021-2024          1      15 biomarker; cell; discovery; randomized; r… 0.181
#> 12 2021-2024          2      12 cancer; checkpoint; colorectal; cross; im… 0.145
#> 13 2021-2024          3      19 spatial; transcriptomics; biomarker; case… 0.229
#> 14 2021-2024          4      14 clinical; expression; gene; outcomes; bio… 0.169
#> 15 2021-2024          5      23 cancer; colorectal; drug; resistance; cli… 0.277
evo$transitions
#> # A tibble: 50 × 6
#>    from_window to_window from_cluster to_cluster jaccard n_shared
#>    <chr>       <chr>            <int>      <int>   <dbl>    <int>
#>  1 2015-2017   2018-2020            1          1   0.871       27
#>  2 2015-2017   2018-2020            1          5   0.788       26
#>  3 2015-2017   2018-2020            1          3   0.879       29
#>  4 2015-2017   2018-2020            1          4   0.879       29
#>  5 2015-2017   2018-2020            1          2   0.742       23
#>  6 2015-2017   2018-2020            3          1   0.727       24
#>  7 2015-2017   2018-2020            3          5   0.758       25
#>  8 2015-2017   2018-2020            3          3   0.848       28
#>  9 2015-2017   2018-2020            3          4   0.848       28
#> 10 2015-2017   2018-2020            3          2   0.710       22
#> # ℹ 40 more rows

# one clustering for the whole corpus: follow each cluster id
evo <- sm_cluster_evolution(corpus, link_by = "cluster_id")
#> ✔ Cluster evolution computed across 3 time windows.
#> ℹ 10 transitions link the same cluster id in consecutive windows.
evo$transitions
#> # A tibble: 10 × 6
#>    from_window to_window from_cluster to_cluster jaccard n_shared
#>    <chr>       <chr>            <int>      <int>   <dbl>    <int>
#>  1 2015-2017   2018-2020            1          1   0.871       27
#>  2 2015-2017   2018-2020            2          2   0.645       20
#>  3 2015-2017   2018-2020            3          3   0.848       28
#>  4 2015-2017   2018-2020            4          4   0.848       28
#>  5 2015-2017   2018-2020            5          5   0.818       27
#>  6 2018-2020   2021-2024            1          1   0.788       26
#>  7 2018-2020   2021-2024            2          2   0.727       24
#>  8 2018-2020   2021-2024            3          3   0.970       32
#>  9 2018-2020   2021-2024            4          4   0.939       31
#> 10 2018-2020   2021-2024            5          5   0.909       30
# }
```

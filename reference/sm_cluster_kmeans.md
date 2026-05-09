# K-means clustering of works

Clusters works using K-means clustering via
[`stats::kmeans()`](https://rdrr.io/r/stats/kmeans.html). Optionally
reduces embedding dimensions first with UMAP or PCA.

## Usage

``` r
sm_cluster_kmeans(
  corpus,
  k,
  reducer = c("umap", "pca", "none"),
  n_components = 5L,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object with embeddings.

- k:

  Integer; the number of clusters. Required.

- reducer:

  Character; dimensionality reduction method to apply before clustering.
  One of `"umap"` (default), `"pca"`, or `"none"`.

- n_components:

  Integer; number of dimensions to reduce to. Defaults to `5L`.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with a `cluster_id` column added to `corpus$works`.

## Details

Requires embeddings in `corpus$embeddings`. Compute them first with
[`sm_embed_works()`](https://cttir.github.io/scimapR/reference/sm_embed_works.md)
or load from cache with
[`sm_embed_load()`](https://cttir.github.io/scimapR/reference/sm_embed_load.md).

K-means is deterministic given a fixed random seed. Consider setting a
seed before calling this function for reproducibility.

## See also

Other clustering:
[`sm_cluster_evolution()`](https://cttir.github.io/scimapR/reference/sm_cluster_evolution.md),
[`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/reference/sm_cluster_hdbscan.md),
[`sm_cluster_label()`](https://cttir.github.io/scimapR/reference/sm_cluster_label.md),
[`sm_cluster_leiden()`](https://cttir.github.io/scimapR/reference/sm_cluster_leiden.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus(with_embeddings = TRUE)
corpus <- sm_cluster_kmeans(corpus, k = 5)
#> ✔ K-means clustering complete.
#> ℹ 5 clusters, sizes range from 27 to 49.
table(corpus$works$cluster_id)
#> 
#>  1  2  3  4  5 
#> 40 27 39 45 49 
# }
```

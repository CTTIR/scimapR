# HDBSCAN clustering of works

Clusters works using the HDBSCAN (Hierarchical Density-Based Spatial
Clustering of Applications with Noise) algorithm via
[`dbscan::hdbscan()`](https://michael.hahsler.net/dbscan/reference/hdbscan.html).
Optionally reduces embedding dimensions first with UMAP or PCA.

## Usage

``` r
sm_cluster_hdbscan(
  corpus,
  min_cluster_size = 15L,
  min_samples = NULL,
  reducer = c("umap", "pca", "none"),
  n_components = 5L,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object with embeddings.

- min_cluster_size:

  Integer; minimum cluster size for HDBSCAN. Defaults to `15L`.

- min_samples:

  Integer or `NULL`; minimum number of samples in a neighbourhood for a
  point to be a core point. If `NULL` (default), set equal to
  `min_cluster_size`.

- reducer:

  Character; dimensionality reduction method to apply before clustering.
  One of `"umap"` (default), `"pca"`, or `"none"`.

- n_components:

  Integer; number of dimensions to reduce to. Defaults to `5L`.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with a `cluster_id` column added to `corpus$works`.
Noise points (not assigned to any cluster) receive `cluster_id = 0L`.
Works without a row in `corpus$embeddings` (such as works without text,
see
[`sm_embed_works()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_works.md))
get `NA`.

## Details

Work IDs and embedding row names must be unique. Repeated IDs stop with
class `scimapR_duplicate_ids`; use
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md)
to inspect them.

Requires embeddings in `corpus$embeddings`. Compute them first with
[`sm_embed_works()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_works.md)
or load from cache with
[`sm_embed_load()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_load.md).

The reducer step helps HDBSCAN work in a lower-dimensional space where
density estimation is more reliable.

## See also

Other clustering:
[`sm_cluster_evolution()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_evolution.md),
[`sm_cluster_kmeans()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_kmeans.md),
[`sm_cluster_label()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_label.md),
[`sm_cluster_leiden()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_leiden.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus(with_embeddings = TRUE)
corpus <- sm_cluster_hdbscan(corpus, min_cluster_size = 10L)
#> ✔ HDBSCAN clustering complete.
#> ℹ 5 clusters found, 0 noise points.
table(corpus$works$cluster_id)
#> 
#>  1  2  3  4  5 
#> 45 27 39 40 49 
# }
```

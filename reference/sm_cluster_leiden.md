# Leiden community detection

Clusters works using the Leiden community detection algorithm via
[`igraph::cluster_leiden()`](https://r.igraph.org/reference/cluster_leiden.html).
If no network is provided, a semantic similarity network is built
automatically from embeddings.

## Usage

``` r
sm_cluster_leiden(
  corpus,
  network = NULL,
  resolution = 1,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object.

- network:

  A
  [tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
  or igraph::igraph object, or `NULL`. If `NULL` (default), a semantic
  similarity network is built via
  [`sm_network_semantic()`](https://cttir.github.io/scimapR/reference/sm_network_semantic.md).

- resolution:

  Numeric; resolution parameter for the Leiden algorithm. Higher values
  produce more (smaller) clusters. Defaults to `1.0`.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with a `cluster_id` column added to `corpus$works`.

## Details

The Leiden algorithm (Traag et al., 2019) is a refinement of the Louvain
algorithm that guarantees well-connected communities. It operates on the
edge weights of the network.

When `network = NULL`, embeddings must be present in the corpus so that
[`sm_network_semantic()`](https://cttir.github.io/scimapR/reference/sm_network_semantic.md)
can build a k-NN graph.

## See also

Other clustering:
[`sm_cluster_evolution()`](https://cttir.github.io/scimapR/reference/sm_cluster_evolution.md),
[`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/reference/sm_cluster_hdbscan.md),
[`sm_cluster_kmeans()`](https://cttir.github.io/scimapR/reference/sm_cluster_kmeans.md),
[`sm_cluster_label()`](https://cttir.github.io/scimapR/reference/sm_cluster_label.md)

## Examples

``` r
# \donttest{
if (requireNamespace("igraph", quietly = TRUE)) {
  corpus <- sm_example_corpus(with_embeddings = TRUE)
  corpus <- sm_cluster_leiden(corpus, resolution = 1.0)
  table(corpus$works$cluster_id)
}
#> ✔ Leiden clustering complete.
#> ℹ 5 communities found.
#> 
#>  1  2  3  4  5 
#> 49 39 45 40 27 
# }
```

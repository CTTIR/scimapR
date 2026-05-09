# Plot thematic map (Callon centrality-density)

Strategic diagram plotting clusters by centrality (external links) and
density (internal links), following Callon et al.

## Usage

``` r
sm_plot_thematic_map(corpus, by = "cluster_id", dark = FALSE, ...)
```

## Arguments

- corpus:

  An `sm_corpus` with clusters.

- by:

  Grouping variable. Default `"cluster_id"`.

- dark:

  Logical; dark mode?

- ...:

  Additional arguments.

## Value

A `ggplot` object.

## See also

Other plots:
[`autoplot.sm_corpus()`](https://cttir.github.io/scimapR/reference/autoplot.sm_corpus.md),
[`sm_palette_qualitative()`](https://cttir.github.io/scimapR/reference/sm_palette_qualitative.md),
[`sm_plot_bradford()`](https://cttir.github.io/scimapR/reference/sm_plot_bradford.md),
[`sm_plot_citation_network()`](https://cttir.github.io/scimapR/reference/sm_plot_citation_network.md),
[`sm_plot_collab()`](https://cttir.github.io/scimapR/reference/sm_plot_collab.md),
[`sm_plot_equity_dashboard()`](https://cttir.github.io/scimapR/reference/sm_plot_equity_dashboard.md),
[`sm_plot_evolution()`](https://cttir.github.io/scimapR/reference/sm_plot_evolution.md),
[`sm_plot_heaps()`](https://cttir.github.io/scimapR/reference/sm_plot_heaps.md),
[`sm_plot_landscape()`](https://cttir.github.io/scimapR/reference/sm_plot_landscape.md),
[`sm_plot_lotka()`](https://cttir.github.io/scimapR/reference/sm_plot_lotka.md),
[`sm_plot_production()`](https://cttir.github.io/scimapR/reference/sm_plot_production.md),
[`sm_plot_top()`](https://cttir.github.io/scimapR/reference/sm_plot_top.md),
[`sm_scale_color()`](https://cttir.github.io/scimapR/reference/sm_scale_color.md),
[`sm_theme()`](https://cttir.github.io/scimapR/reference/sm_theme.md)

## Examples

``` r
# \donttest{
if (requireNamespace("dbscan", quietly = TRUE) &&
    requireNamespace("uwot", quietly = TRUE) &&
    requireNamespace("ggrepel", quietly = TRUE)) {
  corpus <- sm_example_corpus(with_embeddings = TRUE, seed = 42)
  corpus <- sm_cluster_hdbscan(corpus, min_cluster_size = 10)
  sm_plot_thematic_map(corpus)
}
#> ✔ HDBSCAN clustering complete.
#> ℹ 5 clusters found, 0 noise points.

# }
```

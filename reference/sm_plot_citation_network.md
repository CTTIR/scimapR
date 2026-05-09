# Plot citation network

Visualise the citation network of top-cited works.

## Usage

``` r
sm_plot_citation_network(corpus, top_n = 50L, dark = FALSE, ...)
```

## Arguments

- corpus:

  An `sm_corpus`.

- top_n:

  Number of top works to include.

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
[`sm_plot_collab()`](https://cttir.github.io/scimapR/reference/sm_plot_collab.md),
[`sm_plot_equity_dashboard()`](https://cttir.github.io/scimapR/reference/sm_plot_equity_dashboard.md),
[`sm_plot_evolution()`](https://cttir.github.io/scimapR/reference/sm_plot_evolution.md),
[`sm_plot_heaps()`](https://cttir.github.io/scimapR/reference/sm_plot_heaps.md),
[`sm_plot_landscape()`](https://cttir.github.io/scimapR/reference/sm_plot_landscape.md),
[`sm_plot_lotka()`](https://cttir.github.io/scimapR/reference/sm_plot_lotka.md),
[`sm_plot_production()`](https://cttir.github.io/scimapR/reference/sm_plot_production.md),
[`sm_plot_thematic_map()`](https://cttir.github.io/scimapR/reference/sm_plot_thematic_map.md),
[`sm_plot_top()`](https://cttir.github.io/scimapR/reference/sm_plot_top.md),
[`sm_scale_color()`](https://cttir.github.io/scimapR/reference/sm_scale_color.md),
[`sm_theme()`](https://cttir.github.io/scimapR/reference/sm_theme.md)

## Examples

``` r
# \donttest{
if (requireNamespace("ggraph", quietly = TRUE)) {
  corpus <- sm_example_corpus()
  sm_plot_citation_network(corpus)
}

# }
```

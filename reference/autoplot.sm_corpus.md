# Autoplot for sm_corpus

Automatically generate a suitable plot for an `sm_corpus` based on the
requested type.

## Usage

``` r
# S3 method for class 'sm_corpus'
autoplot(
  object,
  type = c("production", "landscape", "thematic", "collab", "equity", "top", "lotka",
    "bradford"),
  ...
)
```

## Arguments

- object:

  An `sm_corpus` object.

- type:

  Plot type.

- ...:

  Additional arguments passed to the plot function.

## Value

A `ggplot` object.

## See also

Other plots:
[`sm_palette_qualitative()`](https://r-heller.github.io/scimapR/reference/sm_palette_qualitative.md),
[`sm_plot_bradford()`](https://r-heller.github.io/scimapR/reference/sm_plot_bradford.md),
[`sm_plot_citation_network()`](https://r-heller.github.io/scimapR/reference/sm_plot_citation_network.md),
[`sm_plot_collab()`](https://r-heller.github.io/scimapR/reference/sm_plot_collab.md),
[`sm_plot_equity_dashboard()`](https://r-heller.github.io/scimapR/reference/sm_plot_equity_dashboard.md),
[`sm_plot_evolution()`](https://r-heller.github.io/scimapR/reference/sm_plot_evolution.md),
[`sm_plot_heaps()`](https://r-heller.github.io/scimapR/reference/sm_plot_heaps.md),
[`sm_plot_landscape()`](https://r-heller.github.io/scimapR/reference/sm_plot_landscape.md),
[`sm_plot_lotka()`](https://r-heller.github.io/scimapR/reference/sm_plot_lotka.md),
[`sm_plot_production()`](https://r-heller.github.io/scimapR/reference/sm_plot_production.md),
[`sm_plot_thematic_map()`](https://r-heller.github.io/scimapR/reference/sm_plot_thematic_map.md),
[`sm_plot_top()`](https://r-heller.github.io/scimapR/reference/sm_plot_top.md),
[`sm_scale_color()`](https://r-heller.github.io/scimapR/reference/sm_scale_color.md),
[`sm_theme()`](https://r-heller.github.io/scimapR/reference/sm_theme.md)

## Examples

``` r
corpus <- sm_example_corpus()
ggplot2::autoplot(corpus, type = "production")
```

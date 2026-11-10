# Viridis colour scale for scimapR

Wraps viridis with sensible defaults for scimapR plots.

## Usage

``` r
sm_scale_color(option = "viridis", discrete = TRUE, ...)

sm_scale_fill(option = "viridis", discrete = TRUE, ...)
```

## Arguments

- option:

  Viridis palette option. One of `"viridis"`, `"magma"`, `"plasma"`,
  `"cividis"`, `"inferno"`, `"mako"`, `"rocket"`, `"turbo"`.

- discrete:

  Logical; discrete or continuous scale?

- ...:

  Additional arguments passed to the viridis scale function.

## Value

A ggplot2 scale object.

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
[`sm_plot_thematic_map()`](https://cttir.github.io/scimapR/reference/sm_plot_thematic_map.md),
[`sm_plot_top()`](https://cttir.github.io/scimapR/reference/sm_plot_top.md),
[`sm_theme()`](https://cttir.github.io/scimapR/reference/sm_theme.md)

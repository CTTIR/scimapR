# Plot annual scientific production

Bar chart of publication counts over time.

## Usage

``` r
sm_plot_production(corpus, by = c("year", "month"), dark = FALSE, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- by:

  Time unit: `"year"` or `"month"`.

- dark:

  Logical; dark mode?

- ...:

  Additional arguments (currently unused).

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
[`sm_plot_thematic_map()`](https://cttir.github.io/scimapR/reference/sm_plot_thematic_map.md),
[`sm_plot_top()`](https://cttir.github.io/scimapR/reference/sm_plot_top.md),
[`sm_scale_color()`](https://cttir.github.io/scimapR/reference/sm_scale_color.md),
[`sm_theme()`](https://cttir.github.io/scimapR/reference/sm_theme.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_plot_production(corpus)
```

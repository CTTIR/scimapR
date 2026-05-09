# scimapR plot theme

A restrained, publication-ready ggplot2 theme with viridis defaults.

## Usage

``` r
sm_theme(base_size = 11, base_family = "", dark = FALSE, ...)
```

## Arguments

- base_size:

  Base font size in points.

- base_family:

  Base font family.

- dark:

  Logical; use dark mode?

- ...:

  Additional arguments passed to
  [`ggplot2::theme()`](https://ggplot2.tidyverse.org/reference/theme.html).

## Value

A [`ggplot2::theme`](https://ggplot2.tidyverse.org/reference/theme.html)
object.

## See also

Other plots:
[`autoplot.sm_corpus()`](https://r-heller.github.io/scimapR/reference/autoplot.sm_corpus.md),
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
[`sm_scale_color()`](https://r-heller.github.io/scimapR/reference/sm_scale_color.md)

## Examples

``` r
library(ggplot2)
ggplot(mtcars, aes(wt, mpg)) + geom_point() + sm_theme()
```

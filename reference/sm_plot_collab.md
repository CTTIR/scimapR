# Plot collaboration map

Visualise international or institutional collaboration patterns.

## Usage

``` r
sm_plot_collab(
  corpus,
  level = c("country", "institution", "author"),
  top_n = 20L,
  dark = FALSE,
  precompute = FALSE,
  max_nodes = NULL,
  ...
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- level:

  Collaboration level.

- top_n:

  Number of top entities to include.

- dark:

  Logical; dark mode?

- precompute:

  Logical (default `FALSE`). When `TRUE`, return a plain `ggplot` with
  the layout computed eagerly (see
  [`sm_plot_citation_network()`](https://cttir.github.io/scimapR/reference/sm_plot_citation_network.md)
  for why this matters when knitting large graphs).

- max_nodes:

  Optional integer node cap. `NULL` (default) keeps all nodes; set it to
  downsample large graphs to the highest-degree nodes (opt-in, with a
  `cli` message).

- ...:

  Additional arguments.

## Value

A `ggplot` object (`ggraph` when `precompute = FALSE`, plain `ggplot`
when `precompute = TRUE`).

## See also

Other plots:
[`autoplot.sm_corpus()`](https://cttir.github.io/scimapR/reference/autoplot.sm_corpus.md),
[`sm_palette_qualitative()`](https://cttir.github.io/scimapR/reference/sm_palette_qualitative.md),
[`sm_plot_bradford()`](https://cttir.github.io/scimapR/reference/sm_plot_bradford.md),
[`sm_plot_citation_network()`](https://cttir.github.io/scimapR/reference/sm_plot_citation_network.md),
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
corpus <- sm_example_corpus()
sm_plot_collab(corpus, level = "country")
```

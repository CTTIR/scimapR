# Plot citation network

Visualise the citation network of top-cited works.

## Usage

``` r
sm_plot_citation_network(
  corpus,
  top_n = 50L,
  dark = FALSE,
  precompute = FALSE,
  max_nodes = NULL,
  ...
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- top_n:

  Number of top works to include.

- dark:

  Logical; dark mode?

- precompute:

  Logical (default `FALSE`). When `TRUE`, the graph layout is computed
  eagerly and a plain self-contained `ggplot` (materialised coordinates)
  is returned, instead of a lazy `ggraph` object. Use this when
  embedding the plot in an RMarkdown/knitr/`callr`/workflowr document:
  the heavy layout runs once here rather than in the (often
  memory-limited) render subprocess, where large `ggraph` objects can
  crash the harness.

- max_nodes:

  Optional integer node cap. `NULL` (default) keeps all nodes so
  existing renders are unchanged; set it to downsample large graphs to
  the highest-degree nodes (opt-in, with a `cli` message).

- ...:

  Additional arguments.

## Value

A `ggplot` object (a `ggraph` plot when `precompute = FALSE`, a plain
`ggplot` when `precompute = TRUE`).

## Large graphs

For big networks, prefer `precompute = TRUE` and save the returned
object (e.g. with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html));
printing it in a document then re-renders cheaply without recomputing
the layout. See the networks section of the getting- started vignette.

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
corpus <- sm_example_corpus()
sm_plot_citation_network(corpus)
```

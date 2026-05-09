# Launch the scimapR Shiny application

Launch a comprehensive 13-tab interactive explorer for bibliometric
analysis. The app provides auto/light/dark theming, publication-ready
export in multiple formats, and viridis colour palettes throughout.

## Usage

``` r
sm_run_app(corpus = NULL, launch.browser = TRUE, ...)
```

## Arguments

- corpus:

  An `sm_corpus` to load on startup. If `NULL`, loads
  [`sm_example_corpus()`](https://cttir.github.io/scimapR/reference/sm_example_corpus.md)
  so users can explore without their own data.

- launch.browser:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Invisible `NULL`. Launches a Shiny application.

## Examples

``` r
# \donttest{
if (interactive()) {
  sm_run_app()
  # sm_run_app(my_corpus)
}
# }
```

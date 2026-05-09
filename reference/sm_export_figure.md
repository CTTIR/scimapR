# Export a plot as a publication-ready figure

Save a ggplot to disk in multiple formats and resolutions. By default,
raster formats are saved at both 300 and 600 dpi.

## Usage

``` r
sm_export_figure(
  plot,
  path,
  format = c("png", "pdf", "svg", "tiff", "eps"),
  dpi = c(300, 600),
  width = 7,
  height = 5,
  units = c("in", "cm", "mm"),
  background = c("white", "transparent"),
  multi_dpi = TRUE
)
```

## Arguments

- plot:

  A `ggplot` object.

- path:

  Output file path (extension determines format if `format` not
  specified).

- format:

  Output format.

- dpi:

  Resolution for raster formats.

- width:

  Plot width.

- height:

  Plot height.

- units:

  Size units.

- background:

  Background colour.

- multi_dpi:

  Logical; write both 300 and 600 dpi versions for raster formats?

## Value

Character vector of paths actually written, invisibly.

## See also

Other export:
[`sm_export_csv()`](https://cttir.github.io/scimapR/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/reference/sm_export_rds.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 20)
p <- sm_plot_production(corpus)
path <- tempfile(fileext = ".png")
sm_export_figure(p, path, multi_dpi = FALSE)
#> ✔ Saved figure to: /tmp/RtmpbTCVFU/file21d22183466c.png
```

# Export a table as formatted XLSX or CSV

Save a tibble or data frame with publication-ready formatting. XLSX
output includes bold headers, frozen top row, autofilter, and optional
title/caption/source note.

## Usage

``` r
sm_export_table(
  table,
  path,
  format = c("xlsx", "csv", "tsv"),
  title = NULL,
  caption = NULL,
  source_note = NULL,
  style = c("scimapr", "minimal", "publication")
)
```

## Arguments

- table:

  A data frame or tibble.

- path:

  Output file path.

- format:

  Output format.

- title:

  Optional title row (merged, larger font).

- caption:

  Optional caption row beneath header.

- source_note:

  Optional source note in footer.

- style:

  Formatting style.

## Value

`path` invisibly.

## See also

Other export:
[`sm_export_csv()`](https://cttir.github.io/scimapR/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/reference/sm_export_rds.md),
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
dat <- data.frame(Author = "Smith J", Works = 10L, Citations = 150L)
path <- tempfile(fileext = ".xlsx")
sm_export_table(dat, path)
#> ✔ Table saved to /tmp/Rtmpxwo82y/file24532716a07f.xlsx
```

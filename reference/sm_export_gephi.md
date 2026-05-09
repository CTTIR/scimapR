# Export network for Gephi (GEXF format)

Write a tidygraph network to GEXF XML format for use with Gephi.

## Usage

``` r
sm_export_gephi(network, path)
```

## Arguments

- network:

  A `tbl_graph` object.

- path:

  Output file path (should end in `.gexf`).

## Value

`path` invisibly.

## See also

Other export:
[`sm_export_csv()`](https://r-heller.github.io/scimapR/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://r-heller.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://r-heller.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_quarto_report()`](https://r-heller.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://r-heller.github.io/scimapR/reference/sm_export_rds.md),
[`sm_export_table()`](https://r-heller.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://r-heller.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://r-heller.github.io/scimapR/reference/sm_export_zip.md)

# Export network for Cytoscape (JSON)

Write network to Cytoscape JSON format.

## Usage

``` r
sm_export_cytoscape(network, path)
```

## Arguments

- network:

  A `tbl_graph` object.

- path:

  Output file path.

## Value

`path` invisibly.

## See also

Other export:
[`sm_export_csv()`](https://cttir.github.io/scimapR/reference/sm_export_csv.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/reference/sm_export_rds.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus()
net <- sm_network_cocitation(corpus)
sm_export_cytoscape(net, tempfile(fileext = ".json"))
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> ✔ Network exported for Cytoscape to /tmp/RtmpyoACUq/file23fa656be935.json
# }
```

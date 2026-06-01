# Export network for VOSviewer

Write network to VOSviewer-compatible format.

## Usage

``` r
sm_export_vosviewer(network, path)
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
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/reference/sm_export_rds.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus()
net <- sm_network_cocitation(corpus)
sm_export_vosviewer(net, tempfile(fileext = ".tsv"))
#> Warning: Unknown or uninitialised column: `from`.
#> Warning: Unknown or uninitialised column: `to`.
#> ✔ Network exported for VOSviewer to /tmp/RtmpIQMgiF/file237049e0e8.tsv
# }
```

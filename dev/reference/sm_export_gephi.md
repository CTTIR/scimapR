# Export network for Gephi (GEXF format)

Write a tidygraph network to GEXF XML format for use with Gephi. Labels
are escaped as XML, and directed networks retain their direction.

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
[`sm_export_csv()`](https://cttir.github.io/scimapR/dev/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/dev/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/dev/reference/sm_export_figure.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/dev/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/dev/reference/sm_export_rds.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/dev/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/dev/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/dev/reference/sm_export_zip.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus()
net <- sm_network_cocitation(corpus)
sm_export_gephi(net, tempfile(fileext = ".gexf"))
#> ✔ Network exported to /tmp/RtmpRkJWHY/file1f9fe02d5f5.gexf
# }
```

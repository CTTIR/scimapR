# Export network for VOSviewer

Write a headerless network file with integer node ids and positive link
strengths, plus a tab-separated map file with `id` and `label` columns.
Missing weights become 1. Directed edges are written as supplied, but
VOSviewer treats the links as undirected.

## Usage

``` r
sm_export_vosviewer(network, path, map_path = NULL)
```

## Arguments

- network:

  A `tbl_graph` object.

- path:

  Output file path.

- map_path:

  Map file path. By default, `_map` is inserted before the extension of
  `path`, or appended if `path` has no extension.

## Value

`path` invisibly.

## See also

Other export:
[`sm_export_csv()`](https://cttir.github.io/scimapR/dev/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/dev/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/dev/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/dev/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/dev/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/dev/reference/sm_export_rds.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/dev/reference/sm_export_table.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/dev/reference/sm_export_zip.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus()
net <- sm_network_cocitation(corpus)
sm_export_vosviewer(net, tempfile(fileext = ".tsv"))
#> ✔ Network exported for VOSviewer to /tmp/RtmpRkJWHY/file1f9f27a5bb74.tsv
# The matching map file is written beside the network file.
# }
```

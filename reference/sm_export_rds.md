# Export corpus as RDS

Save the full corpus including embeddings as a compressed RDS file.

## Usage

``` r
sm_export_rds(corpus, path, compress = "xz")
```

## Arguments

- corpus:

  An `sm_corpus` object.

- path:

  Output file path.

- compress:

  Compression type. Default `"xz"`.

## Value

`path` invisibly.

## See also

Other export:
[`sm_export_csv()`](https://cttir.github.io/scimapR/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10)
path <- tempfile(fileext = ".rds")
sm_export_rds(corpus, path)
#> ✔ Corpus saved to /tmp/RtmpVDxLPH/file25bd4e2f7615.rds
```

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
[`sm_export_csv()`](https://r-heller.github.io/scimapR/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://r-heller.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://r-heller.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://r-heller.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://r-heller.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_table()`](https://r-heller.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://r-heller.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://r-heller.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10)
path <- tempfile(fileext = ".rds")
sm_export_rds(corpus, path)
#> ✔ Corpus saved to /tmp/Rtmp7Xki0Y/file238558ada6f6.rds
```

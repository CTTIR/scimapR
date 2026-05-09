# Export corpus as self-contained ZIP bundle

Build a ZIP archive containing the corpus RDS, certificate, figures,
tables, and an auto-generated README. This is the "send everything to a
collaborator" workflow.

## Usage

``` r
sm_export_zip(
  corpus,
  path,
  include = c("rds", "certificate", "tables"),
  figure_formats = c("png"),
  figure_dpi = c(300),
  report_template = "standard"
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- path:

  Output ZIP file path.

- include:

  Components to include in the bundle.

- figure_formats:

  Figure output formats.

- figure_dpi:

  Figure resolutions.

- report_template:

  Quarto report template.

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
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/reference/sm_export_vosviewer.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus(n_works = 10)
path <- tempfile(fileext = ".zip")
sm_export_zip(corpus, path, include = c("rds", "certificate"))
#> ✔ Corpus saved to /tmp/RtmpbTCVFU/file21d2347513d7/corpus.rds
#> ✔ Certificate written to /tmp/RtmpbTCVFU/file21d2347513d7/certificate.yaml.
#> ✔ Certificate created. Corpus hash: 58b250d94efb
#> ✔ Bundle saved to /tmp/RtmpbTCVFU/file21d276ca6955.zip
# }
```

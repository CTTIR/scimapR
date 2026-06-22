# Export corpus tables as CSV files

Write each corpus table as a separate CSV file in a directory.

## Usage

``` r
sm_export_csv(corpus, dir, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- dir:

  Output directory.

- ...:

  Additional arguments passed to
  [`readr::write_csv()`](https://readr.tidyverse.org/reference/write_delim.html).

## Value

`dir` invisibly.

## See also

Other export:
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_quarto_report()`](https://cttir.github.io/scimapR/reference/sm_export_quarto_report.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/reference/sm_export_rds.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10)
dir <- tempdir()
sm_export_csv(corpus, dir)
#> ✔ Corpus tables saved to /tmp/RtmpygYB6X
```

# Export a Quarto report

Generate a comprehensive bibliometric report from a corpus using a
Quarto template.

## Usage

``` r
sm_export_quarto_report(
  corpus,
  path,
  template = c("standard", "minimal", "thesis"),
  include_chat = FALSE,
  include_audit = TRUE,
  include_trajectory = FALSE
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- path:

  Output path for the rendered report.

- template:

  Report template.

- include_chat:

  Logical; include chat session?

- include_audit:

  Logical; include equity audit?

- include_trajectory:

  Logical; include trajectory analysis?

## Value

`path` invisibly.

## See also

Other export:
[`sm_export_csv()`](https://cttir.github.io/scimapR/reference/sm_export_csv.md),
[`sm_export_cytoscape()`](https://cttir.github.io/scimapR/reference/sm_export_cytoscape.md),
[`sm_export_figure()`](https://cttir.github.io/scimapR/reference/sm_export_figure.md),
[`sm_export_gephi()`](https://cttir.github.io/scimapR/reference/sm_export_gephi.md),
[`sm_export_rds()`](https://cttir.github.io/scimapR/reference/sm_export_rds.md),
[`sm_export_table()`](https://cttir.github.io/scimapR/reference/sm_export_table.md),
[`sm_export_vosviewer()`](https://cttir.github.io/scimapR/reference/sm_export_vosviewer.md),
[`sm_export_zip()`](https://cttir.github.io/scimapR/reference/sm_export_zip.md)

## Examples

``` r
# \donttest{
if (requireNamespace("quarto", quietly = TRUE)) {
  corpus <- sm_example_corpus()
  sm_export_quarto_report(corpus, tempfile(fileext = ".html"))
}
#> ℹ Quarto report rendering requires a Quarto installation.
#> ℹ Template: standard
# }
```

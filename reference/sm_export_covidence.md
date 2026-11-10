# Export corpus for Covidence

Write corpus works in RIS format for Covidence import.

## Usage

``` r
sm_export_covidence(corpus, path)
```

## Arguments

- corpus:

  An `sm_corpus`.

- path:

  Output file path.

## Value

`path` invisibly.

## See also

Other screening:
[`sm_export_rayyan()`](https://cttir.github.io/scimapR/reference/sm_export_rayyan.md),
[`sm_import_rayyan()`](https://cttir.github.io/scimapR/reference/sm_import_rayyan.md),
[`sm_merge_screening_decisions()`](https://cttir.github.io/scimapR/reference/sm_merge_screening_decisions.md),
[`sm_screen_prisma()`](https://cttir.github.io/scimapR/reference/sm_screen_prisma.md)

## Examples

``` r
path <- tempfile(fileext = ".ris")
sm_export_covidence(sm_example_corpus(n_works = 2), path)
#> ✔ Exported 2 works to /tmp/RtmpreoyoG/file1c5673e60771.ris
readLines(path, n = 3)
#> [1] "TY  - JOUR"                                                 
#> [2] "ID  - W000000001"                                           
#> [3] "TI  - Gene Expression in immune checkpoint: a meta-analysis"
unlink(path)
```

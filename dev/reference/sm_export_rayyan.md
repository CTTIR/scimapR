# Export corpus for Rayyan

Write corpus works in RIS format for import into Rayyan. Work IDs appear
in the RIS ID field and a note; missing fields are omitted.

## Usage

``` r
sm_export_rayyan(corpus, path)
```

## Arguments

- corpus:

  An `sm_corpus`.

- path:

  Output file path.

## Value

`path` invisibly.

## Details

Keep the ID or the scimapR work_id note when exporting decisions.

## See also

Other screening:
[`sm_export_covidence()`](https://cttir.github.io/scimapR/dev/reference/sm_export_covidence.md),
[`sm_import_rayyan()`](https://cttir.github.io/scimapR/dev/reference/sm_import_rayyan.md),
[`sm_merge_screening_decisions()`](https://cttir.github.io/scimapR/dev/reference/sm_merge_screening_decisions.md),
[`sm_screen_prisma()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_prisma.md)

## Examples

``` r
path <- tempfile(fileext = ".ris")
sm_export_rayyan(sm_example_corpus(n_works = 2), path)
#> ✔ Exported 2 works to /tmp/RtmpSrcliq/file1ec9632bb84d.ris
readLines(path, n = 3)
#> [1] "TY  - JOUR"                                                 
#> [2] "ID  - W000000001"                                           
#> [3] "TI  - Gene Expression in immune checkpoint: a meta-analysis"
unlink(path)
```

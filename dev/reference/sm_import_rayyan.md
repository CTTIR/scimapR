# Import screening decisions from Rayyan

Read Rayyan CSV export and parse screening decisions.

## Usage

``` r
sm_import_rayyan(path, corpus = NULL, id_col = NULL)
```

## Arguments

- path:

  Path to Rayyan CSV export.

- corpus:

  Optional corpus for DOI matching and ID validation.

- id_col:

  Optional name of the CSV column containing work IDs.

## Value

One screening row per CSV record. Unmatched work IDs remain missing and
warn. Decisions use include, exclude and uncertain.

## Details

IDs come from the named column, otherwise from the scimapR work_id note,
or from unique matching corpus DOIs. Decisions and reasons come from
their columns or Rayyan inclusion and exclusion notes. Disagreeing
reviewers give an uncertain decision.

## See also

Other screening:
[`sm_export_covidence()`](https://cttir.github.io/scimapR/dev/reference/sm_export_covidence.md),
[`sm_export_rayyan()`](https://cttir.github.io/scimapR/dev/reference/sm_export_rayyan.md),
[`sm_merge_screening_decisions()`](https://cttir.github.io/scimapR/dev/reference/sm_merge_screening_decisions.md),
[`sm_screen_prisma()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_prisma.md)

## Examples

``` r
path <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(id = "paper-a", decision = "Included"),
                 path, row.names = FALSE)
sm_import_rayyan(path, id_col = "id")
#> # A tibble: 1 × 7
#>   work_id stage          decision reason confidence source decided_at         
#>   <chr>   <chr>          <chr>    <chr>       <dbl> <chr>  <dttm>             
#> 1 paper-a title-abstract include  NA             NA rayyan 2026-10-25 19:58:24
unlink(path)
```

# Merge external screening decisions into corpus

Add external screening decisions (from Rayyan, Covidence, or manual
spreadsheet) into the corpus screening table.

## Usage

``` r
sm_merge_screening_decisions(corpus, decisions)
```

## Arguments

- corpus:

  An `sm_corpus`.

- decisions:

  A tibble with screening decisions.

## Value

An `sm_corpus` with updated screening.

## See also

Other screening:
[`sm_export_covidence()`](https://cttir.github.io/scimapR/reference/sm_export_covidence.md),
[`sm_export_rayyan()`](https://cttir.github.io/scimapR/reference/sm_export_rayyan.md),
[`sm_import_rayyan()`](https://cttir.github.io/scimapR/reference/sm_import_rayyan.md),
[`sm_screen_prisma()`](https://cttir.github.io/scimapR/reference/sm_screen_prisma.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 5)
decisions <- tibble::tibble(
  work_id = corpus$works$work_id[1:2],
  stage = "title-abstract",
  decision = c("Included", "Excluded"),
  reason = c(NA, "wrong population"),
  source = "reviewer 1"
)
corpus <- sm_merge_screening_decisions(corpus, decisions)
corpus$screening
#> # A tibble: 2 × 7
#>   work_id    stage         decision reason confidence source decided_at
#>   <chr>      <chr>         <chr>    <chr>       <dbl> <chr>  <dttm>    
#> 1 W000000001 title-abstra… include  NA             NA revie… NA        
#> 2 W000000002 title-abstra… exclude  wrong…         NA revie… NA        
```

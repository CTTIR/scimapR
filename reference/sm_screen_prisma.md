# Generate PRISMA flow diagram

Create a PRISMA 2020-compatible flow diagram from corpus screening data.

## Usage

``` r
sm_screen_prisma(
  corpus,
  decisions = NULL,
  stages = c("identification", "screening", "eligibility", "inclusion")
)
```

## Arguments

- corpus:

  An `sm_corpus` with screening decisions.

- decisions:

  Optional external decisions tibble.

- stages:

  Stage names for the flow.

## Value

A list with `$counts` (tibble) and `$plot` (ggplot).

## See also

Other screening:
[`sm_export_covidence()`](https://cttir.github.io/scimapR/reference/sm_export_covidence.md),
[`sm_export_rayyan()`](https://cttir.github.io/scimapR/reference/sm_export_rayyan.md),
[`sm_import_rayyan()`](https://cttir.github.io/scimapR/reference/sm_import_rayyan.md),
[`sm_merge_screening_decisions()`](https://cttir.github.io/scimapR/reference/sm_merge_screening_decisions.md)

## Examples

``` r
corpus <- sm_example_corpus(with_screening = TRUE)
prisma <- sm_screen_prisma(corpus)
prisma$counts
#> # A tibble: 4 × 4
#>   stage          n_entering n_excluded n_remaining
#>   <chr>               <int>      <int>       <int>
#> 1 identification        200          0         200
#> 2 screening             200          0         200
#> 3 eligibility           200          0         200
#> 4 inclusion             200          0         200
```

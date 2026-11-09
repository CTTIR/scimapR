# Generate PRISMA flow diagram

Create a PRISMA 2020-compatible flow diagram from corpus screening data.

## Usage

``` r
sm_screen_prisma(
  corpus,
  decisions = NULL,
  stages = c("identification", "title-abstract", "full-text", "inclusion"),
  n_identified = NULL
)
```

## Arguments

- corpus:

  An `sm_corpus` with screening decisions.

- decisions:

  Optional external decisions tibble.

- stages:

  Stage names in flow order. Defaults to identification, title-abstract,
  full-text and inclusion. Only current works still in the flow count;
  each stage uses the latest decision per work.

- n_identified:

  Whole count before deduplication and other removals, at least the
  corpus size. Defaults to `metadata$n_identified` when set, otherwise
  the corpus size. Ignored without an identification stage.

## Value

A list with `$counts` (tibble) and `$plot` (ggplot).

## See also

Other screening:
[`sm_export_covidence()`](https://cttir.github.io/scimapR/dev/reference/sm_export_covidence.md),
[`sm_export_rayyan()`](https://cttir.github.io/scimapR/dev/reference/sm_export_rayyan.md),
[`sm_import_rayyan()`](https://cttir.github.io/scimapR/dev/reference/sm_import_rayyan.md),
[`sm_merge_screening_decisions()`](https://cttir.github.io/scimapR/dev/reference/sm_merge_screening_decisions.md)

## Examples

``` r
corpus <- sm_example_corpus(with_screening = TRUE)
prisma <- sm_screen_prisma(corpus)
prisma$counts
#> # A tibble: 4 × 4
#>   stage          n_entering n_excluded n_remaining
#>   <chr>               <int>      <int>       <int>
#> 1 identification        200          0         200
#> 2 title-abstract        200         96         104
#> 3 full-text             104          0         104
#> 4 inclusion             104          0         104
```

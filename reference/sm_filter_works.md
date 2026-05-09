# Filter works in a corpus

Subset a corpus by filtering works on year, type, OA status, or custom
expressions.

## Usage

``` r
sm_filter_works(corpus, ..., year_range = NULL, types = NULL, oa_only = FALSE)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- ...:

  Filtering expressions passed to
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html),
  evaluated in the context of the `works` tibble.

- year_range:

  Optional two-element integer vector for year filtering.

- types:

  Optional character vector of document types to keep.

- oa_only:

  Logical; keep only open access works?

## Value

An `sm_corpus` with the filtered subset.

## See also

Other filters:
[`sm_query()`](https://r-heller.github.io/scimapR/reference/sm_query.md)

## Examples

``` r
corpus <- sm_example_corpus()
filtered <- sm_filter_works(corpus, year_range = c(2020, 2024))
nrow(filtered$works)
#> [1] 110
```

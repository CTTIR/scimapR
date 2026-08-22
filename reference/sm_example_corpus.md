# Generate a synthetic example corpus

Creates a realistic synthetic corpus for examples, testing, and
demonstration. Works have plausible titles, DOIs, years, and citations.
Authors are clustered into collaborating groups.

## Usage

``` r
sm_example_corpus(
  n_works = 200L,
  n_authors = 80L,
  year_range = c(2015L, 2024L),
  n_clusters = 5L,
  with_embeddings = TRUE,
  with_screening = FALSE,
  with_trajectory_seed = TRUE,
  seed = 42L
)
```

## Arguments

- n_works:

  Number of works to generate.

- n_authors:

  Number of authors to generate.

- year_range:

  Two-element integer vector of year range.

- n_clusters:

  Number of topic clusters.

- with_embeddings:

  Logical; generate random embeddings?

- with_screening:

  Logical; generate screening decisions?

- with_trajectory_seed:

  Logical; create a prolific author for trajectory demonstration?

- seed:

  Random seed for reproducibility.

## Value

An `sm_corpus` object.

## See also

Other example:
[`sm_example_files()`](https://cttir.github.io/scimapR/reference/sm_example_files.md)

## Examples

``` r
corpus <- sm_example_corpus()
print(corpus)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 200 | Authors: 80 | Institutions: 0
#> Years: 2015 - 2024
#> Sources (journals): 10
#> Embeddings: 200 x 64
#> Provenance: synthetic (200)
#> Status: Unlocked (last refreshed: 2026-08-22 13:17:50)
```

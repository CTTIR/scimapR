# Bundled example corpus

A pre-built synthetic corpus with 200 works, 80 authors, 5 clusters, and
embeddings. Created with `sm_example_corpus(seed = 42)`.

## Usage

``` r
sm_example_db
```

## Format

An `sm_corpus` S3 object.

## Source

Synthetically generated.

## Examples

``` r
data(sm_example_db)
print(sm_example_db)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 200 | Authors: 80 | Institutions: 0
#> Years: 2015 - 2024
#> Sources (journals): 10
#> Embeddings: 200 x 64
#> Provenance: synthetic (200)
#> Status: Unlocked (last refreshed: 2026-05-08 23:20:49)
```

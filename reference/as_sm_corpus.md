# Coerce objects to sm_corpus

Generic function to convert various data types to an `sm_corpus` object.

## Usage

``` r
as_sm_corpus(x, ...)

# S3 method for class 'sm_corpus'
as_sm_corpus(x, ...)

# S3 method for class 'data.frame'
as_sm_corpus(x, source_label = "data.frame", ...)

# S3 method for class 'list'
as_sm_corpus(x, ...)

# S3 method for class 'bibliometrixDB'
as_sm_corpus(x, source_label = "bibliometrix-import", ...)
```

## Arguments

- x:

  An object to coerce.

- ...:

  Additional arguments passed to methods.

- source_label:

  Label for provenance tracking.

## Value

An `sm_corpus` object.

## See also

Other corpus:
[`is_sm_corpus()`](https://cttir.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/reference/sm_build_corpus.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/reference/sm_dedupe.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- sm_example_corpus()
as_sm_corpus(corpus)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 200 | Authors: 80 | Institutions: 0
#> Years: 2015 - 2024
#> Sources (journals): 10
#> Embeddings: 200 x 64
#> Provenance: synthetic (200)
#> Status: Unlocked (last refreshed: 2026-06-01 12:23:18)
as_sm_corpus(corpus$works)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 200 | Authors: 0 | Institutions: 0
#> Years: 2015 - 2024
#> Sources (journals): 0
#> Embeddings: none
#> Status: Unlocked (last refreshed: never)
```

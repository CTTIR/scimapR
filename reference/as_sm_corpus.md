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
[`is_sm_corpus()`](https://r-heller.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://r-heller.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://r-heller.github.io/scimapR/reference/sm_build_corpus.md),
[`sm_corpus()`](https://r-heller.github.io/scimapR/reference/sm_corpus.md),
[`sm_dedupe()`](https://r-heller.github.io/scimapR/reference/sm_dedupe.md),
[`sm_save_corpus()`](https://r-heller.github.io/scimapR/reference/sm_save_corpus.md),
[`sm_validate()`](https://r-heller.github.io/scimapR/reference/sm_validate.md),
[`validate_sm_corpus()`](https://r-heller.github.io/scimapR/reference/validate_sm_corpus.md)

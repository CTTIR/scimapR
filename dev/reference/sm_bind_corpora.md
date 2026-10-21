# Bind two corpora together

Row-bind all tables of two `sm_corpus` objects, the yearly citation
counts (`citations_by_year`) too when either corpus has them. The bound
corpus keeps the metadata of `corpus1`, with the local input files
([`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md))
of both corpora, each file and content once.

## Usage

``` r
sm_bind_corpora(corpus1, corpus2, mix_models = FALSE)
```

## Arguments

- corpus1:

  An `sm_corpus`.

- corpus2:

  An `sm_corpus`.

- mix_models:

  Logical; bind embeddings that come from different models (or of which
  only one corpus records its model)? Defaults to `FALSE`. See Details.

## Value

An `sm_corpus` object.

## Details

Embeddings are bound when both corpora have them, with the same number
of dimensions, and when they come from the same model as
`metadata$embedding` records it (see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md));
the bound corpus keeps that record. Embeddings that record different
models, or of which only one corpus records its model, are not
comparable: the function stops (class
`scimapR_embedding_model_mismatch`) unless `mix_models = TRUE`, which
binds them and records the model as `"mixed"`. Embeddings of two corpora
that record no model, such as corpora embedded by earlier versions of
scimapR, are bound as before, and the model of the bound rows stays
unrecorded. When only one corpus has embeddings, or their widths differ,
the bound corpus has none.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_build_corpus.md),
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/dev/reference/sm_dedupe.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

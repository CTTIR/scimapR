# Build a corpus from multiple sources

Combine multiple file reads and/or API fetches into a single
deduplicated `sm_corpus`.

## Usage

``` r
sm_build_corpus(..., dedupe = TRUE, mix_models = FALSE, verbose = TRUE)
```

## Arguments

- ...:

  One or more `sm_corpus` objects or file paths.

- dedupe:

  Logical; deduplicate by normalised DOI after combining, keeping the
  most complete record and its child rows?

- mix_models:

  Logical; bind embeddings that come from different models (or of which
  only one input records its model)? Passed to
  [`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md).
  Defaults to `FALSE`.

- verbose:

  Logical; show progress messages?

## Value

An `sm_corpus` object.

## Details

The inputs are bound in turn with
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
so its rules for embeddings apply: embeddings that record different
models in `metadata$embedding`, or of which only one input records its
model, stop the function (class `scimapR_embedding_model_mismatch`)
unless `mix_models = TRUE`. Pass every file of a split export; the IDs
stay unique.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/dev/reference/sm_dedupe.md),
[`sm_link_references()`](https://cttir.github.io/scimapR/dev/reference/sm_link_references.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_oa_statuses()`](https://cttir.github.io/scimapR/dev/reference/sm_oa_statuses.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

## Examples

``` r
c1 <- sm_example_corpus(n_works = 50, seed = 1)
c2 <- sm_example_corpus(n_works = 50, seed = 2)
combined <- sm_build_corpus(c1, c2, dedupe = TRUE)
#> ℹ Re-keyed 50 works, 79 authors, 10 sources and 0 institutions in the second
#>   corpus.
#> ℹ 50 works share a DOI with the first corpus; use `sm_dedupe()` to remove
#>   duplicates.
#> ✔ Removed 50 duplicate works with the same doi.
```

# Deduplicate corpus works by selected columns

Remove duplicate works, preferring the record with more complete data.
Ties keep the first record. Kept records stay in their input order, with
only their child rows and referenced lookup records.

## Usage

``` r
sm_dedupe(corpus, by = "doi", verbose = TRUE)
```

## Arguments

- corpus:

  An `sm_corpus`.

- by:

  Non-empty character vector of works columns that together identify
  duplicates. Default `"doi"`. DOIs and titles are normalised, other
  character values are trimmed, and other types compare as stored. A
  missing or empty value in any key column never counts as a duplicate.

- verbose:

  Logical; show progress?

## Value

An `sm_corpus` object.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_build_corpus.md),
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
[`sm_link_references()`](https://cttir.github.io/scimapR/dev/reference/sm_link_references.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_oa_statuses()`](https://cttir.github.io/scimapR/dev/reference/sm_oa_statuses.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

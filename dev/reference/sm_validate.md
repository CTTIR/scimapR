# Validate corpus integrity

Check referential integrity across all corpus tables and report issues.
Checks work, author, source and institution links, duplicate lookup IDs,
and duplicate or orphan embedding row names. A locked corpus with a
stored hash is also checked for changed content.

## Usage

``` r
sm_validate(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- call:

  Caller environment for error reporting.

## Value

A tibble with `table`, `issue` and `n_affected`, or a 0-row tibble with
the same columns if clean. Missing links count distinct unresolved IDs;
duplicates count surplus rows.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_build_corpus.md),
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/dev/reference/sm_dedupe.md),
[`sm_link_references()`](https://cttir.github.io/scimapR/dev/reference/sm_link_references.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_oa_statuses()`](https://cttir.github.io/scimapR/dev/reference/sm_oa_statuses.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- sm_example_corpus()
issues <- sm_validate(corpus)
nrow(issues)
#> [1] 0
```

# Link cited references to works in a corpus

Resolves cited DOIs and OpenAlex identifiers against the works in the
corpus. Use this for corpora built from tables or saved before
references were linked automatically. No network request is made.

## Usage

``` r
sm_link_references(
  corpus,
  by = c("doi", "openalex_id"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object.

- by:

  Identifiers to match, in priority order: `"doi"` and `"openalex_id"`
  by default.

- verbose:

  Report the numbers of linked and unresolved references.

- call:

  Caller environment for error reporting.

## Value

The corpus with `references$cited_work_id` filled where possible.

## Details

Links to existing corpus works are preserved. Missing or dangling links
are resolved by a normalised DOI in `cited_doi` or a Web of Science DOI
field in `cited_raw`, including bracketed DOI lists. OpenAlex matching
accepts a whole short work id or its URL in `cited_raw`. A match must
identify exactly one work and must not point to the citing work itself.
The first identifier type in `by` giving a unique, non-self match wins.
A dangling link without a match is retained. The source identifiers and
provenance are unchanged. Locked corpora must first be unlocked.

Readers and fetchers that build references,
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md)
and
[`sm_dedupe()`](https://cttir.github.io/scimapR/dev/reference/sm_dedupe.md)
link automatically.
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
`new_sm_corpus()`,
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
subsetting and
[`sm_example_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_example_corpus.md)
take the supplied links as given.

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
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_oa_statuses()`](https://cttir.github.io/scimapR/dev/reference/sm_oa_statuses.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- readRDS(sm_example_files("example_realuse_corpus.rds"))
linked <- sm_link_references(corpus)
#> ℹ 226 of 2316 references point to corpus works (226 newly linked).
#> ℹ 0 ambiguous matches and 0 self-matches remain unresolved.
sum(linked$references$cited_work_id %in% linked$works$work_id)
#> [1] 226
```

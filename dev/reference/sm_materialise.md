# Materialise cached enrichment into a corpus

Joins cached enrichment data into the matching `sm_corpus` sub-tibbles
by their key columns, returning an updated, schema-valid `sm_corpus`.
This replaces hand-written cache-to-corpus joins (which are easy to get
wrong — e.g. a `bind_rows()` that coerces a `NULL` element to a logical
column).

## Usage

``` r
sm_materialise(
  corpus,
  sources,
  .by = NULL,
  overwrite = FALSE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- sources:

  Either a named list whose names are corpus sub-tables (`works`,
  `authors`, `authorships`, `sources`, `institutions`, `references`,
  `concepts`, ...) and whose elements are tibbles or paths to cached
  `.rds`/`.parquet` files; or a single directory path containing
  `<table>.rds` / `<table>.parquet` files.

- .by:

  Optional named list mapping table name to its join key column(s).
  Missing or empty key values never match. Defaults: `works`,
  `provenance` and `screening` use `work_id`; `authors` use `author_id`;
  `institutions` use `institution_id`; `sources` use `source_id`;
  `authorships` use `(work_id, author_id)`; `references` use
  `(work_id, ref_index)` (formerly `(work_id, cited_work_id)`);
  `concepts` use `(work_id, concept_id)`. For keywords, use
  `.by = list(concepts = c("work_id", "vocabulary", "concept_name"))`.

- overwrite:

  Logical (default `FALSE`). When `FALSE`, enrichment only fills `NA`
  cells of overlapping columns; populated cells are never overwritten.
  When `TRUE`, non-`NA` enrichment values win.

- call:

  Caller environment for error reporting.

## Value

An updated, validated `sm_corpus` with the enrichment columns merged
into the relevant sub-tables. New columns are added; existing rows are
preserved (this is a column-enrichment join, not a row append).

## Details

Missing key columns warn and skip the source. Enrichment rows with a
missing key value are dropped with `scimapR_materialise_na_keys`; corpus
rows with missing keys keep their values and produce a
`scimapR_materialise_unmatched_rows` message. A repeated complete key in
`works`, `authors`, `institutions`, `sources`, `references` or
`concepts` aborts with `scimapR_materialise_key_not_unique`. The group
keys in `authorships`, `provenance` and `screening` can repeat: every
matching row receives the enrichment. Duplicate enrichment keys warn and
keep the first. Concept vocabularies used as keys are normalised on both
sides before matching. After a merge into `concepts`, legacy spellings
in its `vocabulary` column are renamed to the names of
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
without a message.

## See also

[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)

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
[`sm_oa_statuses()`](https://cttir.github.io/scimapR/dev/reference/sm_oa_statuses.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10, seed = 1)
metrics <- tibble::tibble(work_id = corpus$works$work_id,
                          cnci = runif(10, 0.5, 2))
corpus2 <- sm_materialise(corpus, sources = list(works = metrics))
#> ✔ Materialised 10 enrichment rows into works (+1 column).
"cnci" %in% names(corpus2$works)
#> [1] TRUE
```

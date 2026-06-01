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
  Defaults to each table's natural key (e.g. `works` -\> `work_id`).

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

Missing keys produce a
[`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html) and
skip that source rather than erroring. Internally, row-binds use a
type-safe helper so a `NULL`/empty source never corrupts a column's
type.

## See also

[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md)

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/reference/as_sm_corpus.md),
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
corpus <- sm_example_corpus(n_works = 10, seed = 1)
metrics <- tibble::tibble(work_id = corpus$works$work_id,
                          cnci = runif(10, 0.5, 2))
corpus2 <- sm_materialise(corpus, sources = list(works = metrics))
#> ✔ Materialised 10 enrichment rows into works (+1 column).
"cnci" %in% names(corpus2$works)
#> [1] TRUE
```

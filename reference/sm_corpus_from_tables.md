# Construct an sm_corpus from a relational set of tables

A documented, validating constructor that builds an `sm_corpus` from a
named list of data frames – making non-OpenAlex/WoS tabular sources
first-class and side-stepping format-specific parsers. Required columns
are validated against the `sm_corpus` schema, column types are coerced
(with informative messages), absent optional tables are filled with
correctly-typed 0-row tibbles, and the result is validated before being
returned.

This is the recommended ingestion path for arbitrary tabular sources.

## Usage

``` r
sm_corpus_from_tables(
  tables,
  schema = NULL,
  .coerce = TRUE,
  metadata = list(),
  call = rlang::caller_env()
)
```

## Arguments

- tables:

  A named list of data frames. Recognised names are `works`, `authors`,
  `authorships`, `institutions`, `sources`, `references`, `concepts`,
  `provenance`, `screening`. `works` is required (and must have, or be
  coercible to, a `work_id` column; if absent, work ids are generated).

- schema:

  Optional named list of empty template tibbles overriding the built-in
  schema (advanced use). Defaults to the standard `sm_corpus` schema.

- .coerce:

  Logical (default `TRUE`); coerce supplied columns to the schema's
  types. When `FALSE`, columns are used as-is (missing columns are still
  filled with typed `NA`).

- metadata:

  Optional list of corpus-level metadata.

- call:

  Caller environment for error reporting.

## Value

A validated `sm_corpus` object.

## See also

[`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md),
[`as_sm_corpus()`](https://cttir.github.io/scimapR/reference/as_sm_corpus.md)

Other reporting:
[`sm_figure_manifest()`](https://cttir.github.io/scimapR/reference/sm_figure_manifest.md)

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/reference/sm_build_corpus.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/reference/sm_dedupe.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/reference/sm_materialise.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/reference/validate_sm_corpus.md)

## Examples

``` r
works <- data.frame(
  work_id = c("W1", "W2"),
  title = c("First", "Second"),
  year = c("2020", "2021"),   # character -> coerced to integer
  doi = c("10.1/a", "10.1/b")
)
authorships <- data.frame(
  work_id = c("W1", "W1", "W2"),
  author_id = c("A1", "A2", "A1"),
  position = c(1, 2, 1)
)
corpus <- sm_corpus_from_tables(list(works = works,
                                     authorships = authorships))
#> ℹ works: coerced column year to the schema type.
#> ℹ works: filled missing column abstract, type, source_id, cited_by_count,
#>   oa_status, language, pmid, arxiv_id, openalex_id, is_retracted,
#>   retraction_date, and last_refreshed with typed `NA`.
#> ℹ authorships: coerced column position to the schema type.
#> ℹ authorships: filled missing column is_corresponding, institution_id,
#>   raw_affiliation, and country_code with typed `NA`.
corpus
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 2 | Authors: 0 | Institutions: 0
#> Years: 2020 - 2021
#> Sources (journals): 0
#> Embeddings: none
#> Status: Unlocked (last refreshed: never)
```

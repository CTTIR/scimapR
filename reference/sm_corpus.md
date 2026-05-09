# Create an sm_corpus object

Build a typed, tibble-of-tibbles corpus container for bibliometric
analysis. The corpus is the central data structure in scimapR, holding
works, authors, authorships, institutions, sources, references,
concepts, embeddings, provenance, screening decisions, and metadata.

## Usage

``` r
sm_corpus(
  works,
  authors = NULL,
  authorships = NULL,
  institutions = NULL,
  sources = NULL,
  references = NULL,
  concepts = NULL,
  embeddings = NULL,
  provenance = NULL,
  screening = NULL,
  metadata = list()
)

# S3 method for class 'sm_corpus'
x[i, ...]

# S3 method for class 'sm_corpus'
length(x)

# S3 method for class 'sm_corpus'
dim(x)

# S3 method for class 'sm_corpus'
as_tibble(x, ...)

# S3 method for class 'sm_corpus'
as.data.frame(x, ...)

# S3 method for class 'sm_corpus'
print(x, ...)

# S3 method for class 'sm_corpus'
format(x, ...)

# S3 method for class 'sm_corpus'
summary(object, ...)

# S3 method for class 'sm_corpus'
str(object, ...)
```

## Arguments

- works:

  A tibble of works (publications). See Details for schema.

- authors:

  A tibble of authors. If `NULL`, constructed from `works`.

- authorships:

  A tibble linking works to authors. If `NULL`, empty.

- institutions:

  A tibble of institutions. If `NULL`, empty.

- sources:

  A tibble of publication sources/journals. If `NULL`, empty.

- references:

  A tibble of cited references. If `NULL`, empty.

- concepts:

  A tibble of concepts/keywords. If `NULL`, empty.

- embeddings:

  A numeric matrix of work embeddings, or `NULL`.

- provenance:

  A tibble tracking data lineage. If `NULL`, empty.

- screening:

  A tibble of screening decisions. If `NULL`, empty.

- metadata:

  A list of corpus-level metadata.

- x, object:

  An `sm_corpus` object.

- i:

  Row index for subsetting.

- ...:

  Ignored.

## Value

An `sm_corpus` S3 object.

- `[`: An `sm_corpus` with the selected works.

- [`length()`](https://rdrr.io/r/base/length.html): Number of works
  (integer).

- [`dim()`](https://rdrr.io/r/base/dim.html): Integer vector of length 2
  (rows, columns of works table).

&nbsp;

- `as_tibble()`: The works tibble.

- [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html): The
  works table as a data frame.

&nbsp;

- [`print()`](https://rdrr.io/r/base/print.html): `x` invisibly.

- [`format()`](https://rdrr.io/r/base/format.html): A single character
  string.

- [`summary()`](https://rdrr.io/r/base/summary.html): A named list of
  summary statistics.

- [`str()`](https://rdrr.io/r/utils/str.html): `object` invisibly.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/reference/sm_build_corpus.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/reference/sm_dedupe.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- sm_corpus(
  works = tibble::tibble(
    work_id = "W000000001",
    doi = "10.1234/example",
    title = "Example Work",
    abstract = "An example abstract.",
    year = 2024L,
    type = "journal-article",
    source_id = NA_character_,
    cited_by_count = 0L,
    oa_status = "closed",
    language = "en",
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = NA_real_,
    last_refreshed = Sys.time()
  )
)
print(corpus)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 1 | Authors: 0 | Institutions: 0
#> Years: 2024 - 2024
#> Sources (journals): 0
#> Embeddings: none
#> Status: Unlocked (last refreshed: never)
```

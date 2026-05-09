# Fetch works from OpenAlex

Query the [OpenAlex](https://openalex.org/) API for scholarly works and
return the results as an `sm_corpus`.

Supports both free-text search (`query`) and structured filter syntax
(`filter`). Uses cursor-based pagination to retrieve up to `n_max`
works. An API key (polite pool) and a `mailto` address are strongly
recommended for higher rate limits.

## Usage

``` r
sm_fetch_openalex(
  query = NULL,
  filter = NULL,
  n_max = 200L,
  per_page = 200L,
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  api_key = Sys.getenv("OPENALEX_API_KEY"),
  engine = c("native", "openalexR", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Free-text search query passed to the `search` parameter. If `NULL`,
  `filter` must be supplied.

- filter:

  A character string using OpenAlex filter syntax, e.g.
  `"from_publication_date:2020-01-01,type:journal-article"`.

- n_max:

  Maximum number of works to return (default 200).

- per_page:

  Number of results per page (max 200).

- mailto:

  Email address for the polite pool. Read from `SCIMAPR_MAILTO` env var
  by default.

- api_key:

  OpenAlex API key. Read from `OPENALEX_API_KEY` env var.

- engine:

  One of `"native"` (built-in httr2 client), `"openalexR"` (use the
  openalexR package), or `"auto"` (use openalexR if available, otherwise
  native).

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object.

## See also

Other fetchers:
[`sm_fetch_arxiv()`](https://r-heller.github.io/scimapR/reference/sm_fetch_arxiv.md),
[`sm_fetch_biorxiv()`](https://r-heller.github.io/scimapR/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://r-heller.github.io/scimapR/reference/sm_fetch_crossref.md),
[`sm_fetch_orcid()`](https://r-heller.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://r-heller.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://r-heller.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://r-heller.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_openalex(query = "bibliometrics", n_max = 10)
print(corpus)
} # }
```

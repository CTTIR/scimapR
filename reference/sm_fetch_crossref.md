# Fetch works from Crossref

Query the [Crossref](https://api.crossref.org/) API for scholarly works
and return the results as an `sm_corpus`.

Uses offset-based pagination to retrieve up to `n_max` works. Providing
a `mailto` address enables the polite pool (faster rate limits).

## Usage

``` r
sm_fetch_crossref(
  query = NULL,
  filter = NULL,
  n_max = 200L,
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  engine = c("native", "rcrossref", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Free-text search query. If `NULL`, `filter` must be supplied.

- filter:

  Crossref filter syntax, e.g.
  `"from-pub-date:2020,type:journal-article"`.

- n_max:

  Maximum number of works to return (default 200).

- mailto:

  Email address for the polite pool. Read from `SCIMAPR_MAILTO` env var
  by default.

- engine:

  One of `"native"` (built-in httr2 client), `"rcrossref"` (use the
  rcrossref package), or `"auto"` (use rcrossref if available, otherwise
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
[`sm_fetch_openalex()`](https://r-heller.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://r-heller.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://r-heller.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://r-heller.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://r-heller.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_crossref(query = "bibliometrics", n_max = 10)
print(corpus)
} # }
```

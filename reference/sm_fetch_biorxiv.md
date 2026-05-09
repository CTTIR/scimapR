# Fetch works from bioRxiv/medRxiv

Query the [bioRxiv](https://www.biorxiv.org/) or
[medRxiv](https://www.medrxiv.org/) API for preprints and return the
results as an `sm_corpus`.

The API provides date-range-based content retrieval. If `query` is
supplied, results are filtered locally by title/abstract matching.

## Usage

``` r
sm_fetch_biorxiv(
  query = NULL,
  server = c("biorxiv", "medrxiv"),
  from_date = NULL,
  to_date = NULL,
  n_max = 200L,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Optional search string for local filtering of results.

- server:

  One of `"biorxiv"` or `"medrxiv"`.

- from_date:

  Start date in `"YYYY-MM-DD"` format. Defaults to 30 days ago.

- to_date:

  End date in `"YYYY-MM-DD"` format. Defaults to today.

- n_max:

  Maximum number of results to return (default 200).

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object.

## See also

Other fetchers:
[`sm_fetch_arxiv()`](https://r-heller.github.io/scimapR/reference/sm_fetch_arxiv.md),
[`sm_fetch_crossref()`](https://r-heller.github.io/scimapR/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://r-heller.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://r-heller.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://r-heller.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://r-heller.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://r-heller.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_biorxiv(
  from_date = "2024-01-01",
  to_date = "2024-01-07",
  n_max = 10
)
print(corpus)
} # }
```

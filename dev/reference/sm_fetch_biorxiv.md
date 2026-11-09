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

## Failed requests

Native requests retry transient server and network failures, and short
announced rate-limit waits. Long waits abort immediately. If a later
page fails, the error inherits from `scimapR_fetch_incomplete` and holds
the earlier parsed works in `rlang::last_error()$partial`. Their
metadata records `fetch_incomplete` with the source, received and
expected counts, and failure reason. If those pages cannot be parsed,
`partial` is `NULL`. The default remains an error; an incomplete fetch
is never returned as an ordinary successful result.

## See also

Other fetchers:
[`sm_fetch_arxiv()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_arxiv.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_semantic_scholar.md)

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

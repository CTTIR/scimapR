# Fetch policy citations from Overton

Search the [Overton](https://www.overton.io/) API for policy document
citations of scholarly works and return the results as an `sm_corpus`.

Requires an Overton API key (set via the `OVERTON_API_KEY` environment
variable).

## Usage

``` r
sm_fetch_overton(
  query,
  api_key = Sys.getenv("OVERTON_API_KEY"),
  n_max = 100L,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Search query string.

- api_key:

  Overton API key. Read from `OVERTON_API_KEY` env var.

- n_max:

  Maximum number of results to return (default 100).

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
[`sm_fetch_openalex()`](https://r-heller.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://r-heller.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_pubmed()`](https://r-heller.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://r-heller.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_overton(query = "climate change policy", n_max = 10)
print(corpus)
} # }
```

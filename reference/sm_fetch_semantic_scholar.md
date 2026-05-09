# Fetch works from Semantic Scholar

Query the [Semantic Scholar](https://www.semanticscholar.org/) Academic
Graph API for papers and return the results as an `sm_corpus`.

Supports both keyword search (`query`) and batch paper lookup
(`paper_ids`). Optionally fetches pre-computed SPECTER embeddings.

## Usage

``` r
sm_fetch_semantic_scholar(
  query = NULL,
  paper_ids = NULL,
  n_max = 100L,
  api_key = Sys.getenv("SEMANTIC_SCHOLAR_API_KEY"),
  include_embeddings = FALSE,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Free-text search query. If `NULL`, `paper_ids` must be supplied.

- paper_ids:

  Character vector of Semantic Scholar paper IDs, DOIs (prefixed
  `DOI:`), arXiv IDs (prefixed `ARXIV:`), or PMIDs (prefixed `PMID:`).
  If `NULL`, `query` must be supplied.

- n_max:

  Maximum number of papers to return (default 100).

- api_key:

  Semantic Scholar API key. Read from `SEMANTIC_SCHOLAR_API_KEY` env var
  by default.

- include_embeddings:

  Logical; if `TRUE`, request SPECTER embeddings for each paper and
  attach as an embedding matrix.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object.

## See also

Other fetchers:
[`sm_fetch_arxiv()`](https://cttir.github.io/scimapR/reference/sm_fetch_arxiv.md),
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/reference/sm_fetch_pubmed.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_semantic_scholar(query = "bibliometrics", n_max = 10)
print(corpus)
} # }
```

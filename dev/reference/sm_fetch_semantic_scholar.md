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
  attach as an embedding matrix. These are the API's default SPECTER v1
  vectors, recorded in `metadata$embedding` with the model id
  `"embedding.specter_v1"` (see
  [`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md));
  [`sm_enrich_specter()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_specter.md)
  fetches SPECTER v2 vectors.

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
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_semantic_scholar(query = "bibliometrics", n_max = 10)
print(corpus)
} # }
```

# Fetch works from PubMed

Query [PubMed](https://pubmed.ncbi.nlm.nih.gov/) via the NCBI
E-utilities (esearch + efetch) and return the results as an `sm_corpus`.

Uses retmax/retstart pagination to retrieve up to `n_max` records.
Providing an NCBI API key allows up to 10 requests/second instead of 3.

## Usage

``` r
sm_fetch_pubmed(
  query,
  n_max = 200L,
  api_key = Sys.getenv("NCBI_API_KEY"),
  engine = c("native", "rentrez", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  PubMed search query string (required).

- n_max:

  Maximum number of records to return (default 200).

- api_key:

  NCBI API key. Read from `NCBI_API_KEY` env var by default.

- engine:

  One of `"native"` (built-in httr2 client), `"rentrez"` (use the
  rentrez package), or `"auto"` (use rentrez if available, otherwise
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
[`sm_fetch_openalex()`](https://r-heller.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://r-heller.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://r-heller.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_semantic_scholar()`](https://r-heller.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_pubmed(query = "bibliometrics[tiab]", n_max = 10)
print(corpus)
} # }
```

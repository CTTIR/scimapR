# Fetch works from PubMed

Query [PubMed](https://pubmed.ncbi.nlm.nih.gov/) via the NCBI
E-utilities (esearch + efetch) and return the results as an `sm_corpus`.

Uses retmax/retstart pagination to retrieve up to `n_max` records.
Providing an NCBI API key allows up to 10 requests/second instead of 3.

MeSH headings become concepts in the `"mesh"` vocabulary. Their `score`
is 1 for a major topic of the article (`MajorTopicYN` on the descriptor
or one of its qualifiers) and 0 otherwise.

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

An `sm_corpus` object. Its provenance records the search (`query`,
`n_max` and `engine`), so that
[`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
can run it again.

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
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_pubmed(query = "bibliometrics[tiab]", n_max = 10)
print(corpus)
} # }
```

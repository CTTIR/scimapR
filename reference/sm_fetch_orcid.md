# Fetch works from ORCID

Retrieve works associated with an [ORCID](https://orcid.org/) identifier
via the ORCID Public API and return the results as an `sm_corpus`.

This fetches work summaries from the public API endpoint
`https://pub.orcid.org/v3.0/{orcid}/works`.

## Usage

``` r
sm_fetch_orcid(orcid, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- orcid:

  An ORCID identifier (e.g., `"0000-0001-8006-9742"`).

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
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
# \donttest{
# Queries the ORCID public API; 0000-0002-1825-0097 is the ORCID test record.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- try(sm_fetch_orcid("0000-0002-1825-0097"))
  print(corpus)
}
#> ℹ Fetching works for ORCID "0000-0002-1825-0097"...
#> ✔ Parsed 6 ORCID works into sm_corpus.
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 6 | Authors: 1 | Institutions: 0
#> Years: 1987 - 2012
#> Sources (journals): 0
#> Embeddings: none
#> Provenance: orcid (6)
#> Status: Unlocked (last refreshed: never)
# }
```

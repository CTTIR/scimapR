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
[`sm_fetch_arxiv()`](https://r-heller.github.io/scimapR/reference/sm_fetch_arxiv.md),
[`sm_fetch_biorxiv()`](https://r-heller.github.io/scimapR/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://r-heller.github.io/scimapR/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://r-heller.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_overton()`](https://r-heller.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://r-heller.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://r-heller.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_orcid("0000-0001-8006-9742")
print(corpus)
} # }
```

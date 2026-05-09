# Fetch works from arXiv

Query the [arXiv](https://arxiv.org/) API (Atom feed) for preprints and
return the results as an `sm_corpus`.

Uses start/max_results pagination to retrieve up to `n_max` results. The
arXiv API is free and requires no authentication.

## Usage

``` r
sm_fetch_arxiv(query, n_max = 200L, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- query:

  arXiv search query string using the arXiv query syntax. Supports
  `all:`, `ti:`, `au:`, `abs:`, `cat:`, etc.

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
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_arxiv(query = "all:bibliometrics", n_max = 10)
print(corpus)
} # }
```

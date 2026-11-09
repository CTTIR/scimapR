# Fetch works from Crossref

Query the [Crossref](https://api.crossref.org/) API for scholarly works
and return the results as an `sm_corpus`.

Uses cursor pagination to retrieve up to `n_max` works. Providing a
`mailto` address enables the polite pool (faster rate limits).

## Usage

``` r
sm_fetch_crossref(
  query = NULL,
  filter = NULL,
  n_max = 200L,
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  engine = c("native", "rcrossref", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Free-text search query. If `NULL`, `filter` must be supplied.

- filter:

  Crossref filter syntax, e.g.
  `"from-pub-date:2020,type:journal-article"`.

- n_max:

  Maximum number of works to return (default 200).

- mailto:

  Email address for the polite pool. Read from `SCIMAPR_MAILTO` env var
  by default.

- engine:

  One of `"native"` (built-in httr2 client), `"rcrossref"` (use the
  rcrossref package), or `"auto"` (use rcrossref if available, otherwise
  native).

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object. Its provenance records the search (`query`,
`filter`, `n_max` and `engine`), so that
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
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_crossref(query = "bibliometrics", n_max = 10)
print(corpus)
} # }
```

# Fetch works from OpenAlex

Query the [OpenAlex](https://openalex.org/) API for scholarly works and
return the results as an `sm_corpus`.

Supports both free-text search (`query`) and structured filter syntax
(`filter`). Uses cursor-based pagination to retrieve up to `n_max`
works. Set an OpenAlex API key (see "API key and rate limits").

Besides `cited_by_count`, the works keep OpenAlex's field-weighted
citation impact (`fwci`), its citation percentile
(`citation_percentile`, 0 to 1, with the flags `is_top_10pct` and
`is_top_1pct`) and the date of these values (`citations_as_of`), and the
corpus gets the yearly citation counts as `citations_by_year` (see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
and
[`sm_citation_window()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_window.md)).
The openalexR engine has no percentile, so its three percentile columns
are `NA`. To add these fields to a corpus from another source, use
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md).

## Usage

``` r
sm_fetch_openalex(
  query = NULL,
  filter = NULL,
  n_max = 200L,
  per_page = 200L,
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  api_key = Sys.getenv("OPENALEX_API_KEY"),
  engine = c("native", "openalexR", "auto"),
  batch_size = 50L,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Free-text search query passed to the `search` parameter. If `NULL`,
  `filter` must be supplied.

- filter:

  A character string using OpenAlex filter syntax, e.g.
  `"from_publication_date:2020-01-01,type:journal-article"`.

- n_max:

  Maximum number of works to return (default 200).

- per_page:

  Number of results per page (max 200).

- mailto:

  Contact address sent with each request as the `mailto` parameter. Read
  from the `SCIMAPR_MAILTO` environment variable by default. OpenAlex no
  longer gives such requests a larger budget (the API key does), and the
  openalexR engine does not send it.

- api_key:

  OpenAlex API key. Read from the `OPENALEX_API_KEY` environment
  variable by default; see "API key and rate limits".

- engine:

  One of `"native"` (built-in httr2 client), `"openalexR"` (use the
  openalexR package), or `"auto"` (use openalexR if version 3.1.1 or
  later is installed, otherwise native).

- batch_size:

  Integer; maximum number of `|`-joined values allowed in a single
  OpenAlex filter clause before the request is automatically split into
  multiple batched requests. OpenAlex limits the number of values in an
  `OR` filter and the overall URL length, so long DOI (or other ID)
  lists are chunked, fetched per batch, and row-bound with
  de-duplication. Default `50`, which stays comfortably under the API's
  documented limit of 100.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object. Its provenance records the search (`query`,
`filter`, `n_max` and `engine`), so that
[`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
can run it again.

## API key and rate limits

OpenAlex expects a free API key. Requests without one share one small
daily budget with everyone on the same network address; once it is used
up, OpenAlex answers HTTP 429 (too many requests) until the budget
resets at midnight UTC. Set the key in the `OPENALEX_API_KEY`
environment variable (for example in `~/.Renviron`) or pass it as
`api_key`. It is sent in the `Authorization` header, never in the URL,
and it is stored nowhere in the corpus.

On HTTP 429 the function stops at once with an error of class
`scimapR_openalex_rate_limit` instead of waiting: the message gives the
reset time and the remaining budget that OpenAlex reports (the fields
`reset_at` and `remaining` of the condition) and says whether a key was
sent. Only a wait of up to two seconds (OpenAlex also limits requests
per second) is waited out, once. Other failed requests stop with class
`scimapR_openalex_failed`; both classes inherit from
`scimapR_openalex_error`. With `engine = "openalexR"` the openalexR
package (version 3.1.1 or later) sends the requests: it gets the key too
and its own retries are switched off, but it does not pass on the
response headers, so the reset time and the budget are not known.

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

[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md),
[`sm_citation_window()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_window.md)

Other fetchers:
[`sm_fetch_arxiv()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_arxiv.md),
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_crossref.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_fetch_openalex(query = "bibliometrics", n_max = 10)
print(corpus)
} # }
```

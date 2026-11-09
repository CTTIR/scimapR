# Refresh stale corpus data

Re-fetches metadata for works whose `last_refreshed` timestamp is older
than `max_age_days`. For each stale work, the original provenance source
is consulted: OpenAlex supplies citation counts and open-access status;
Crossref supplies citation counts. Other sources remain stale. Failed
requests, missing identifiers and records not returned are reported.
Only works with returned updates receive a new timestamp and provenance
row. `metadata$last_refresh` advances only when at least one work was
refreshed and none failed. Enrichment rows never select a refresh
source.

The operation is **idempotent**: running it twice in succession will not
re-fetch works that were just refreshed. The function **refuses to
operate on a locked corpus**; use
[`sm_unlock()`](https://cttir.github.io/scimapR/dev/reference/sm_lock.md)
first.

## Usage

``` r
sm_refresh(
  corpus,
  max_age_days = 30,
  what = c("citations", "oa_status"),
  sources = NULL,
  verbose = TRUE,
  api_key = Sys.getenv("OPENALEX_API_KEY"),
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- max_age_days:

  Numeric. Works last refreshed more than this many days ago will be
  re-fetched. Default `30`.

- what:

  Character vector of data aspects to refresh. One or more of
  `"citations"` and `"oa_status"` (the default). `"new_refs"` and
  `"altmetric"` are accepted but unsupported: they warn and are ignored,
  or error when no implemented aspect remains.

- sources:

  Optional character vector restricting which provenance sources to
  re-query (e.g., `"openalex"`, `"crossref"`). If `NULL` (the default),
  the original source for each work is used.

- verbose:

  Logical. Print progress messages?

- api_key:

  OpenAlex API key, sent only in the authorization header.

- mailto:

  Contact address for Crossref requests.

- call:

  Caller environment for error reporting.

## Value

A refreshed `sm_corpus` with updated fields and appended provenance
rows.

## See also

Other refresh:
[`sm_lock()`](https://cttir.github.io/scimapR/dev/reference/sm_lock.md),
[`sm_staleness()`](https://cttir.github.io/scimapR/dev/reference/sm_staleness.md)

## Examples

``` r
corpus <- sm_example_corpus()
# In practice, this would re-fetch from APIs:
# refreshed <- sm_refresh(corpus, max_age_days = 7)
```

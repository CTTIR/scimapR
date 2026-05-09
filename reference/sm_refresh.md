# Refresh stale corpus data

Re-fetches metadata for works whose `last_refreshed` timestamp is older
than `max_age_days`. For each stale work, the original provenance source
is consulted (e.g., OpenAlex, Crossref, PubMed) to update citation
counts, open-access status, new references, and Altmetric data. A new
provenance row is appended for each refreshed work, making the operation
fully auditable.

The operation is **idempotent**: running it twice in succession will not
re-fetch works that were just refreshed. The function **refuses to
operate on a locked corpus**; use
[`sm_unlock()`](https://cttir.github.io/scimapR/reference/sm_lock.md)
first.

## Usage

``` r
sm_refresh(
  corpus,
  max_age_days = 30,
  what = c("citations", "oa_status", "new_refs", "altmetric"),
  sources = NULL,
  verbose = TRUE,
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
  `"citations"`, `"oa_status"`, `"new_refs"`, `"altmetric"`.

- sources:

  Optional character vector restricting which provenance sources to
  re-query (e.g., `"openalex"`, `"crossref"`). If `NULL` (the default),
  the original source for each work is used.

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

A refreshed `sm_corpus` with updated fields and appended provenance
rows.

## See also

Other refresh:
[`sm_lock()`](https://cttir.github.io/scimapR/reference/sm_lock.md),
[`sm_staleness()`](https://cttir.github.io/scimapR/reference/sm_staleness.md)

## Examples

``` r
corpus <- sm_example_corpus()
# In practice, this would re-fetch from APIs:
# refreshed <- sm_refresh(corpus, max_age_days = 7)
```

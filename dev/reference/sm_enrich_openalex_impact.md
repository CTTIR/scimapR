# Add OpenAlex impact fields to any corpus

Looks the works of a corpus up on [OpenAlex](https://openalex.org/) by
identifier and adds OpenAlex's impact fields: the field-weighted
citation impact (`fwci`), the citation percentile
(`citation_percentile`, 0 to 1, with the flags `is_top_10pct` and
`is_top_1pct`), the date of these values (`citations_as_of`) and the
yearly citation counts (the corpus element `citations_by_year`). The
corpus can come from any source, such as Web of Science files or
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md);
only identifiers are sent.

## Usage

``` r
sm_enrich_openalex_impact(
  corpus,
  by = c("openalex_id", "doi"),
  batch_size = 50L,
  api_key = Sys.getenv("OPENALEX_API_KEY"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- by:

  The identifiers to look works up by, in order of preference: one or
  both of `"openalex_id"` and `"doi"`. The default tries the OpenAlex id
  first and the DOI for works without one, as in corpora from Web of
  Science files, whose `openalex_id` is `NA`.

- batch_size:

  Number of identifiers per request, from 1 to 100 (default `50`).
  Larger values are lowered to 100 with a message.

- api_key:

  OpenAlex API key. Read from the `OPENALEX_API_KEY` environment
  variable by default; see "API key and rate limits".

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

The `corpus` with the `works` columns `fwci`, `citation_percentile`,
`is_top_10pct`, `is_top_1pct` and `citations_as_of` (see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)),
the element `citations_by_year` and a provenance row for each work
found. The columns and the element are added even when OpenAlex has none
of the works looked up (with `NA` and no rows where the corpus had
none). A corpus without works, or without works that have an identifier,
is returned unchanged.

## Details

Each work is looked up by the first identifier of `by` that it has: its
OpenAlex id (`works$openalex_id`, shortened to the `W` number) or its
DOI (normalised on both sides, so `https://doi.org/` prefixes and case
do not matter). Works without either are counted and left as they are. A
DOI that contains `,` or `|` cannot be written into an OpenAlex filter;
such works are left out and counted too. The identifiers are sent in
batches of `batch_size` (at most 100, the number of values an OpenAlex
filter takes), with only the fields needed (`select`). When OpenAlex has
several records for one DOI, the record with the most yearly citations
is used, then the one with the lowest OpenAlex id.

The fields are joined with
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md)
(`overwrite = TRUE`). All five values of a work found come from its
OpenAlex record, `NA` where the record has none, so a new run replaces
the values of an earlier run or of another source, and the values, their
date (`citations_as_of`) and the yearly counts of a work always belong
to one record. The works not found keep their values. Only these five
`works` columns change; `cited_by_count` and the other columns keep the
values of their source. The `citations_by_year` rows of every work found
are replaced by the counts OpenAlex has now; the rows of the other works
stay. `metadata$last_refresh` is not changed.

Every work found gets a provenance row with the source
`"openalex_impact"`, its OpenAlex id in `source_id_external`, a short
description of the call in `query` and the kind `"enrichment"`, so
[`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
never replays the step as a search. Neither the API key nor any request
URL or filter is stored.

On HTTP 429 (the request budget is used up) the function stops at once
and joins nothing, not even the batches fetched before: a partial
enrichment would compare works with OpenAlex values against works
without them. The error (class `scimapR_openalex_rate_limit`) names the
reset time, the remaining budget OpenAlex reports and the key setting.
Any other failed request stops it too (class `scimapR_openalex_failed`).

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

## See also

[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md),
[`sm_citation_window()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_window.md)

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_concepts.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_unpaywall.md)

## Examples

``` r
if (FALSE) { # \dontrun{
fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
fix <- sm_enrich_openalex_impact(fix, by = "doi")
sm_citation_window(fix, window = 3)
} # }
```

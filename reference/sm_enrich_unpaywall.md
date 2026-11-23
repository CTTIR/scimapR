# Enrich corpus with Unpaywall open-access data

Look up DOIs in the corpus via the [Unpaywall](https://unpaywall.org/)
API and add open-access status and best OA URL to the `works` table.

This enricher is idempotent: re-running it updates existing OA data
rather than duplicating it. Requires a `mailto` address for API access.

## Usage

``` r
sm_enrich_unpaywall(
  corpus,
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- mailto:

  Email address for the Unpaywall API. Read from `SCIMAPR_MAILTO` env
  var by default.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with updated `oa_status` and `oa_url` columns in
the `works` table, plus provenance rows for the works Unpaywall answered
for ("not found" included). Works that Unpaywall does not know (HTTP
404) keep their previous `oa_status` and `oa_url`. So do works whose
lookup failed for another reason (rejected address, rate limit, server
or network error); they are reported in a warning of class
`scimapR_unpaywall_unchecked` with their `work_ids`.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md)

## Examples

``` r
# \donttest{
# Queries the Unpaywall web API; runs only when a contact e-mail address
# is set in the SCIMAPR_MAILTO environment variable.
if (nzchar(Sys.getenv("SCIMAPR_MAILTO")) &&
    requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- sm_corpus(works = tibble::tibble(
    work_id = "W1",
    doi = "10.1371/journal.pbio.1002541"
  ))
  enriched <- try(sm_enrich_unpaywall(corpus))
  if (is_sm_corpus(enriched)) enriched$works[, c("oa_status", "oa_url")]
}
# }
```

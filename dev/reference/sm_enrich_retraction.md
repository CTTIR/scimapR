# Enrich corpus with retraction data

Check works in the corpus against the [Retraction
Watch](https://retractionwatch.com/) database (via the Crossref update
notices and OpenAlex) to identify retracted publications.

Updates the `is_retracted` and `retraction_date` columns in the `works`
table.

This enricher is idempotent: re-running it updates existing retraction
data rather than duplicating it.

## Usage

``` r
sm_enrich_retraction(
  corpus,
  verbose = TRUE,
  api_key = Sys.getenv("OPENALEX_API_KEY"),
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- verbose:

  Print progress messages?

- api_key:

  OpenAlex API key, sent in the authorization header.

- mailto:

  Contact address sent only to Crossref.

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with updated `is_retracted` and `retraction_date`
columns in the `works` table, plus new provenance rows for checked works
only. Failed requests warn; when no work could be checked they error
without changing the corpus. Missing records are reported separately.
Existing retraction flags are never cleared.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_orcid.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_unpaywall.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus()
corpus <- sm_enrich_retraction(corpus)
} # }
```

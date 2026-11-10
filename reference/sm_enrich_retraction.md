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
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
# \donttest{
# Queries the OpenAlex and Crossref web APIs; the second DOI belongs to a
# retracted article.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- sm_corpus(works = tibble::tibble(
    work_id = c("W1", "W2"),
    doi = c("10.1016/j.joi.2017.08.007", "10.1016/S0140-6736(97)11096-0")
  ))
  enriched <- try(sm_enrich_retraction(corpus))
  if (is_sm_corpus(enriched)) enriched$works[, c("doi", "is_retracted")]
}
#> ℹ 1 retracted of 2 checked; 0 not found in OpenAlex; 0 not checked.
#> # A tibble: 2 × 2
#>   doi                           is_retracted
#>   <chr>                         <lgl>       
#> 1 10.1016/j.joi.2017.08.007     FALSE       
#> 2 10.1016/S0140-6736(97)11096-0 TRUE        
# }
```

# Enrich corpus with OpenCitations citation data

Look up DOIs using the [OpenCitations Index
API](https://api.opencitations.net/index/v2) and add outgoing
references. DOI and OpenAlex identifiers link these references to works
in the corpus. The separate incoming citation count replaces
`works$cited_by_count`.

This enricher is idempotent: re-running it updates existing citation
data rather than duplicating it.

## Usage

``` r
sm_enrich_opencitations(corpus, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with updated `cited_by_count` in the `works`
table, outgoing `references` linked where possible, and new provenance
rows for works with usable responses.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
# \donttest{
# Queries the OpenCitations web API.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- sm_corpus(works = tibble::tibble(
    work_id = "W1",
    doi = "10.1016/j.joi.2017.08.007"
  ))
  enriched <- try(sm_enrich_opencitations(corpus))
  if (is_sm_corpus(enriched)) enriched$works[, c("doi", "cited_by_count")]
}
#> ℹ Looking up 1 DOIs on OpenCitations...
#> ✔ Enriched 1 works with OpenCitations data.
#> # A tibble: 1 × 2
#>   doi                       cited_by_count
#>   <chr>                              <int>
#> 1 10.1016/j.joi.2017.08.007          12084
# }
```

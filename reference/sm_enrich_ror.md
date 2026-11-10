# Enrich corpus institutions with ROR data

Look up institutions in the corpus via the [Research Organization
Registry (ROR)](https://ror.readme.io/) API and enrich the
`institutions` table with standardized metadata including country,
region, type, and income tier.

Works by matching raw affiliation strings against the ROR affiliation
matching API, or by directly resolving existing ROR identifiers.

This enricher is idempotent: re-running it updates existing ROR data
rather than duplicating it.

## Usage

``` r
sm_enrich_ror(corpus, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with updated `institutions` and `authorships`
tables, plus new provenance rows.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
# \donttest{
# Queries the ROR affiliation matching API.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- sm_example_corpus(n_works = 2)
  corpus$authorships$raw_affiliation <- "University of Oxford, Oxford, UK"
  enriched <- try(sm_enrich_ror(corpus))
  if (is_sm_corpus(enriched)) enriched$institutions
}
#> ℹ Matching 1 affiliations against ROR...
#> ✔ Resolved 1 affiliations via ROR; added 1 new institutions.
#> # A tibble: 1 × 7
#>   institution_id        ror   display_name country_code region income_tier type 
#>   <chr>                 <chr> <chr>        <chr>        <chr>  <chr>       <chr>
#> 1 https://ror.org/052g… http… NA           GB           NA     NA          educ…
# }
```

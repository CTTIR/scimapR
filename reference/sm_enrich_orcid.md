# Enrich corpus authors with ORCID data

Look up authors in the corpus who have ORCID identifiers and fetch
additional profile information from the [ORCID](https://orcid.org/)
Public API. Updates the `authors` table with display name alternatives
and the `authorships` table with affiliation data.

This enricher is idempotent: re-running it updates existing ORCID data
rather than duplicating it.

## Usage

``` r
sm_enrich_orcid(corpus, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with updated `authors` and `authorships` tables,
plus new provenance rows.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
# \donttest{
# Queries the ORCID public API; 0000-0002-1825-0097 is the ORCID test record.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- try(sm_fetch_orcid("0000-0002-1825-0097"))
  enriched <- if (is_sm_corpus(corpus)) try(sm_enrich_orcid(corpus))
  if (is_sm_corpus(enriched)) enriched$authors
}
#> ℹ Fetching works for ORCID "0000-0002-1825-0097"...
#> ✔ Parsed 6 ORCID works into sm_corpus.
#> ℹ Enriching 1 authors from ORCID...
#> ✔ Enriched 1 authors with ORCID data.
#> # A tibble: 1 × 7
#>   author_id  orcid           display_name display_name_alterna…¹ inferred_gender
#>   <chr>      <chr>           <chr>        <list>                 <chr>          
#> 1 A000000001 0000-0002-1825… Josiah Carb… <chr [3]>              NA             
#> # ℹ abbreviated name: ¹​display_name_alternatives
#> # ℹ 2 more variables: gender_confidence <dbl>, gender_method <chr>
# }
```

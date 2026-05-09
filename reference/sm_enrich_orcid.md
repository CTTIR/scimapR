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
[`sm_enrich_altmetric()`](https://r-heller.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://r-heller.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_opencitations()`](https://r-heller.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_retraction()`](https://r-heller.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://r-heller.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://r-heller.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://r-heller.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus()
corpus <- sm_enrich_orcid(corpus)
} # }
```

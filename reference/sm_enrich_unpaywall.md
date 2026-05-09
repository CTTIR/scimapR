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
the `works` table, plus new provenance rows.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus()
corpus <- sm_enrich_unpaywall(corpus)
} # }
```

# Enrich corpus with Altmetric attention data

Look up DOIs in the corpus via the
[Altmetric](https://www.altmetric.com/) API and add attention scores,
Mendeley reader counts, and social media metrics to the `works` table.

This enricher is idempotent: re-running it updates existing Altmetric
data rather than duplicating it.

## Usage

``` r
sm_enrich_altmetric(
  corpus,
  api_key = Sys.getenv("ALTMETRIC_API_KEY"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- api_key:

  Altmetric API key. Read from `ALTMETRIC_API_KEY` env var. The free
  tier (no key) is used when empty.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with added `altmetric_score`, `mendeley_readers`,
`twitter_count`, and `news_count` columns in the `works` table, plus new
provenance rows.

## See also

Other enrichers:
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus()
corpus <- sm_enrich_altmetric(corpus)
} # }
```

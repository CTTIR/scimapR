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

  Altmetric API key. Read from `ALTMETRIC_API_KEY` env var. The
  Altmetric Details Page API has required a key since November 2025;
  without one, no work is enriched and a warning says so.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with added `altmetric_score`, `mendeley_readers`,
`twitter_count`, and `news_count` columns in the `works` table, plus
provenance rows for the works Altmetric answered for. Works whose lookup
failed (other than "not found") keep missing values and are reported in
a warning of class `scimapR_altmetric_unchecked` with their `work_ids`.

## See also

Other enrichers:
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Not run: the Altmetric API needs an API key (`ALTMETRIC_API_KEY`).
corpus <- sm_corpus(works = tibble::tibble(
  work_id = "W1",
  doi = "10.1371/journal.pbio.1002541"
))
corpus <- sm_enrich_altmetric(corpus)
} # }
```

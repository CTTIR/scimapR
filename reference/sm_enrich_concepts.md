# Enrich corpus with concepts from OpenAlex or MeSH

Look up works in the corpus via OpenAlex or PubMed to retrieve
associated concepts, topics, or MeSH terms and add them to the
`concepts` table.

This enricher is idempotent: re-running it updates existing concept data
rather than duplicating rows.

## Usage

``` r
sm_enrich_concepts(
  corpus,
  source = c("openalex", "mesh"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- source:

  One of `"openalex"` (fetch OpenAlex concepts via DOI) or `"mesh"`
  (fetch MeSH terms via PubMed PMID).

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with updated `concepts` table and new provenance
rows.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
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
corpus <- sm_enrich_concepts(corpus, source = "openalex")
} # }
```

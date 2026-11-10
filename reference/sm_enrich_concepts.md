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
  api_key = Sys.getenv("OPENALEX_API_KEY"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- source:

  One of `"openalex"` (fetch OpenAlex concepts via DOI) or `"mesh"`
  (fetch MeSH terms via PubMed PMID; the concept `score` is 1 for a
  major topic of the article and 0 otherwise).

- verbose:

  Print progress messages?

- api_key:

  OpenAlex API key, sent in the authorization header.

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with updated `concepts` table and new provenance
rows for enriched works. Failed OpenAlex lookups warn and stop at a rate
limit, preserving earlier successful results.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/reference/sm_enrich_altmetric.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/reference/sm_enrich_ror.md),
[`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/reference/sm_enrich_unpaywall.md)

## Examples

``` r
# \donttest{
# Queries the OpenAlex web API.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- sm_corpus(works = tibble::tibble(
    work_id = c("W1", "W2"),
    doi = c("10.1016/j.joi.2017.08.007", "10.1371/journal.pbio.1002541")
  ))
  enriched <- try(sm_enrich_concepts(corpus, source = "openalex"))
  if (is_sm_corpus(enriched)) enriched$concepts
}
#> ℹ Fetching OpenAlex concepts for 2 works...
#> ✔ Added concepts for 2 works via OpenAlex.
#> # A tibble: 28 × 6
#>    work_id concept_id                       concept_name  level score vocabulary
#>    <chr>   <chr>                            <chr>         <int> <dbl> <chr>     
#>  1 W1      https://openalex.org/C177212765  Workflow          2 0.857 openalex  
#>  2 W1      https://openalex.org/C178315738  Bibliometrics     2 0.774 openalex  
#>  3 W1      https://openalex.org/C41008148   Computer sci…     0 0.769 openalex  
#>  4 W1      https://openalex.org/C2522767166 Data science      1 0.629 openalex  
#>  5 W1      https://openalex.org/C2777904410 Software          2 0.585 openalex  
#>  6 W1      https://openalex.org/C2984968299 Software tool     3 0.412 openalex  
#>  7 W1      https://openalex.org/C115903868  Software eng…     1 0.394 openalex  
#>  8 W1      https://openalex.org/C124101348  Data mining       1 0.362 openalex  
#>  9 W1      https://openalex.org/C77088390   Database          1 0.221 openalex  
#> 10 W1      https://openalex.org/C199360897  Programming …     1 0     openalex  
#> # ℹ 18 more rows
# }
```

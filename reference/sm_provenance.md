# Get corpus provenance

Returns the full provenance table from a corpus, documenting the data
lineage of every work: where it was fetched from, when, with which
query, and which version of scimapR performed the ingestion.

## Usage

``` r
sm_provenance(corpus)
```

## Arguments

- corpus:

  An `sm_corpus` object.

## Value

A tibble with columns `work_id`, `source`, `source_id_external`,
`fetch_date`, `query`, `engine`, `scimapR_version`, and `prompt_hash`.

## See also

Other reproducibility:
[`sm_certificate()`](https://r-heller.github.io/scimapR/reference/sm_certificate.md),
[`sm_cite_corpus()`](https://r-heller.github.io/scimapR/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://r-heller.github.io/scimapR/reference/sm_diff_corpora.md),
[`sm_hash_corpus()`](https://r-heller.github.io/scimapR/reference/sm_hash_corpus.md),
[`sm_snapshot()`](https://r-heller.github.io/scimapR/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_provenance(corpus)
#> # A tibble: 200 × 8
#>    work_id    source    source_id_external fetch_date          query      engine
#>    <chr>      <chr>     <chr>              <dttm>              <chr>      <chr> 
#>  1 W000000001 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  2 W000000002 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  3 W000000003 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  4 W000000004 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  5 W000000005 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  6 W000000006 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  7 W000000007 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  8 W000000008 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#>  9 W000000009 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#> 10 W000000010 synthetic NA                 2026-05-09 07:24:10 sm_exampl… native
#> # ℹ 190 more rows
#> # ℹ 2 more variables: scimapR_version <chr>, prompt_hash <chr>
```

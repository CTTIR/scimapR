# Modern Citation Indicators

## Beyond the h-index

scimapR implements several modern citation indicators that go beyond
simple counts.

``` r

library(scimapR)
corpus <- sm_example_corpus(seed = 42)
```

## Classical indices

``` r

h <- sm_metric_h_index(corpus, level = "author")
head(h, 10)
#> # A tibble: 10 × 2
#>    author_id  h_index
#>    <chr>        <int>
#>  1 A000000001      14
#>  2 A000000032      11
#>  3 A000000042      11
#>  4 A000000013      10
#>  5 A000000038      10
#>  6 A000000015       9
#>  7 A000000020       9
#>  8 A000000022       9
#>  9 A000000036       9
#> 10 A000000045       9
```

## CD index (disruption)

The CD index (Funk & Owen-Smith, 2017) measures whether a work
consolidates or disrupts its field.

``` r

cd <- sm_metric_disruption(corpus)
head(cd)
#> # A tibble: 6 × 2
#>   work_id    cd_index
#>   <chr>         <dbl>
#> 1 W000000001   0     
#> 2 W000000002   0.0101
#> 3 W000000003  -0.0642
#> 4 W000000004   0.167 
#> 5 W000000005   0.0303
#> 6 W000000006   0.188
```

## Relative Citation Ratio

The RCR (Hutchins et al., 2016) normalises citations relative to the
co-citation network.

``` r

rcr <- sm_metric_rcr(corpus)
head(rcr)
#> # A tibble: 6 × 4
#>   work_id    cited_by_count expected_rate   rcr
#>   <chr>               <int>         <dbl> <dbl>
#> 1 W000000001              3          10.2 0.293
#> 2 W000000002              9          12.2 0.738
#> 3 W000000003             28          11.3 2.47 
#> 4 W000000004             29          27.5 1.05 
#> 5 W000000005             16          16   1    
#> 6 W000000006             16          16   1
```

## Field-Normalized Citation Impact

FNCI (Waltman et al., 2011) normalises by field and year.

``` r

fnci <- sm_metric_fnci(corpus)
head(fnci)
#> # A tibble: 6 × 6
#>   work_id    field                    year cited_by_count field_mean  fnci
#>   <chr>      <chr>                   <int>          <int>      <dbl> <dbl>
#> 1 W000000001 clinical outcomes        2023              3       10.2 0.293
#> 2 W000000002 colorectal cancer        2020              9       12.2 0.738
#> 3 W000000003 gene expression          2024             28       11.3 2.47 
#> 4 W000000004 spatial transcriptomics  2020             29       27.5 1.05 
#> 5 W000000005 immune checkpoint        2020             16       16   1    
#> 6 W000000006 immune checkpoint        2018             16       16   1
```

## Uzzi novelty

Measures atypical journal combinations in reference lists (Uzzi et al.,
2013).

``` r

nov <- sm_metric_novelty(corpus)
head(nov)
#> # A tibble: 6 × 2
#>   work_id    novelty
#>   <chr>        <dbl>
#> 1 W000000001  -0.323
#> 2 W000000002  -0.384
#> 3 W000000003  -0.335
#> 4 W000000004  -0.313
#> 5 W000000005  -0.345
#> 6 W000000006  -0.378
```

## Summary tables

``` r

sm_summary_authors(corpus) |> head(5)
#> # A tibble: 1 × 8
#>   n_authors n_with_orcid pct_orcid mean_works_per_author median_works_per_author
#>       <int>        <int>     <dbl>                 <dbl>                   <dbl>
#> 1        80           45      56.2                  9.44                       9
#> # ℹ 3 more variables: max_works_per_author <int>, mean_authors_per_work <dbl>,
#> #   single_author_pct <dbl>
```

## Self-citation and self-corrected indices

[`sm_self_citation()`](https://cttir.github.io/scimapR/reference/sm_self_citation.md)
derives author (or institution) self-citation from the reference lists
already in the corpus — no per-citation API calls. It returns per-entity
and per-work tibbles plus a provenance trail showing which works drove
each self-citation, suitable for an institutional report.

``` r

sc_corpus <- readRDS(system.file("extdata", "example_self_citation_corpus.rds",
                                 package = "scimapR"))
sc <- sm_self_citation(sc_corpus, level = "author")
sc$by_entity
#> # A tibble: 2 × 4
#>   entity_id n_citations_received n_self_citations self_citation_share
#>   <chr>                    <int>            <int>               <dbl>
#> 1 A1                           5                4                 0.8
#> 2 A2                           4                2                 0.5
head(sc$provenance)
#> # A tibble: 6 × 3
#>   citing_work_id cited_work_id shared_author_id
#>   <chr>          <chr>         <chr>           
#> 1 W2             W1            A1              
#> 2 W4             W2            A1              
#> 3 W4             W2            A2              
#> 4 W5             W3            A2              
#> 5 W6             W2            A1              
#> 6 W6             W4            A1
```

The h/g/m indices accept `self_corrected = TRUE`, which recomputes the
index after removing those self-citations (always `<=` the uncorrected
value):

``` r

merge(
  sm_metric_h_index(sc_corpus, "author"),
  sm_metric_h_index(sc_corpus, "author", self_corrected = TRUE),
  by = "author_id", suffixes = c("", "_corrected")
)
#>   author_id h_index h_index_corrected
#> 1        A1       3                 3
#> 2        A2       3                 3
#> 3        A3       1                 1
```

## References

- Funk, R. J. & Owen-Smith, J. (2017). A Dynamic Network Measure of
  Technological Change. *Management Science*, 63(3), 791–817.
- Hutchins, B. I. et al. (2016). Relative Citation Ratio (RCR). *PLOS
  Biology*, 14(9), e1002541.
- Waltman, L. et al. (2011). Towards a new crown indicator.
  *Scientometrics*, 87(3), 467–481.
- Uzzi, B. et al. (2013). Atypical Combinations and Scientific Impact.
  *Science*, 342(6157), 468–472.

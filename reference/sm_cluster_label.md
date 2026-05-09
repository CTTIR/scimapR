# Label clusters with representative terms

Assigns human-readable labels to clusters by extracting representative
terms. Supports TF-IDF-based extraction (default), YAKE keyword
extraction, or LLM-generated labels via the ellmer package.

## Usage

``` r
sm_cluster_label(
  corpus,
  method = c("tfidf", "yake", "llm"),
  n_terms = 5L,
  llm_provider = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object with a `cluster_id` column in `corpus$works`.

- method:

  Character; labelling method. One of `"tfidf"` (default), `"yake"`, or
  `"llm"`.

- n_terms:

  Integer; number of top terms to include in each cluster label.
  Defaults to `5L`.

- llm_provider:

  An ellmer chat provider object (e.g.,
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html)).
  Required when `method = "llm"`, ignored otherwise.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with a `cluster_label` column added to
`corpus$works`, containing a character string of representative terms
for each cluster.

## Details

**TF-IDF method**: For each cluster, concatenates titles and abstracts
of member works, tokenises into unigrams, computes TF-IDF scores where
each cluster is treated as a document, and selects the top `n_terms`.

**YAKE method**: Uses a simplified YAKE-like scoring based on term
frequency, position, and spread across works within each cluster.

**LLM method**: Sends titles and abstracts of each cluster to an LLM
with a prompt asking for a concise topical label. Requires the ellmer
package and a configured provider.

## See also

Other clustering:
[`sm_cluster_evolution()`](https://cttir.github.io/scimapR/reference/sm_cluster_evolution.md),
[`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/reference/sm_cluster_hdbscan.md),
[`sm_cluster_kmeans()`](https://cttir.github.io/scimapR/reference/sm_cluster_kmeans.md),
[`sm_cluster_leiden()`](https://cttir.github.io/scimapR/reference/sm_cluster_leiden.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus(with_embeddings = TRUE)
corpus <- sm_cluster_kmeans(corpus, k = 5)
#> ✔ K-means clustering complete.
#> ℹ 5 clusters, sizes range from 27 to 49.
corpus <- sm_cluster_label(corpus, method = "tfidf", n_terms = 3L)
#> ✔ 5 clusters labelled using "tfidf" method.
head(corpus$works[, c("work_id", "cluster_id", "cluster_label")])
#> # A tibble: 6 × 3
#>   work_id    cluster_id cluster_label                 
#>   <chr>           <int> <chr>                         
#> 1 W000000001          5 analysis; analyzed; approaches
#> 2 W000000002          3 analysis; analyzed; approaches
#> 3 W000000003          5 analysis; analyzed; approaches
#> 4 W000000004          5 analysis; analyzed; approaches
#> 5 W000000005          4 analysis; analyzed; approaches
#> 6 W000000006          1 analysis; analyzed; approaches
# }
```

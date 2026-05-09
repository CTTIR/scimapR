# Build a semantic similarity network

Constructs an undirected k-nearest-neighbour network based on work
embeddings. Each work is connected to its `k` nearest neighbours in
embedding space (cosine similarity). The edge weight is the cosine
similarity between the connected works.

## Usage

``` r
sm_network_semantic(corpus, k = 10L, call = rlang::caller_env())
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object. Must contain an `embeddings` matrix (see
  [`sm_embed_works()`](https://cttir.github.io/scimapR/reference/sm_embed_works.md)).

- k:

  Integer; number of nearest neighbours per work. Defaults to `10L`.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (undirected). Nodes carry `name` (work ID) and columns from
`corpus$works`. Edges carry a `weight` column (cosine similarity,
between 0 and 1).

## Details

Embeddings must be present in `corpus$embeddings` (a numeric matrix with
row names matching `work_id`). Use
[`sm_embed_works()`](https://cttir.github.io/scimapR/reference/sm_embed_works.md)
to compute them.

The function computes cosine similarity via matrix multiplication on
L2-normalised vectors and selects the top-`k` neighbours for each work.

Empty input or missing embeddings returns an empty undirected
`tbl_graph`.

## See also

Other networks:
[`sm_network_citation()`](https://cttir.github.io/scimapR/reference/sm_network_citation.md),
[`sm_network_cocitation()`](https://cttir.github.io/scimapR/reference/sm_network_cocitation.md),
[`sm_network_collab()`](https://cttir.github.io/scimapR/reference/sm_network_collab.md),
[`sm_network_coupling()`](https://cttir.github.io/scimapR/reference/sm_network_coupling.md),
[`sm_network_coword()`](https://cttir.github.io/scimapR/reference/sm_network_coword.md)

## Examples

``` r
corpus <- sm_example_corpus(with_embeddings = TRUE)
g <- sm_network_semantic(corpus, k = 5L)
g
#> # A tbl_graph: 200 nodes and 768 edges
#> #
#> # A bipartite simple graph with 5 components
#> #
#> # Node Data: 200 × 16 (active)
#>    name      doi   title abstract  year type  source_id cited_by_count oa_status
#>    <chr>     <chr> <chr> <chr>    <int> <chr> <chr>              <int> <chr>    
#>  1 W0000000… 10.1… Tumo… This st…  2023 jour… S0000000…              3 green    
#>  2 W0000000… 10.1… Biom… This st…  2020 jour… S0000000…              9 hybrid   
#>  3 W0000000… 10.1… Colo… This st…  2024 jour… S0000000…             28 green    
#>  4 W0000000… 10.1… Tumo… This st…  2020 revi… S0000000…             29 green    
#>  5 W0000000… 10.1… Clin… This st…  2020 jour… S0000000…             16 hybrid   
#>  6 W0000000… 10.1… Tumo… This st…  2018 jour… S0000000…             16 closed   
#>  7 W0000000… 10.1… Sing… This st…  2021 lett… S0000000…             26 bronze   
#>  8 W0000000… 10.1… Colo… This st…  2020 jour… S0000000…              7 hybrid   
#>  9 W0000000… 10.1… Gene… This st…  2024 revi… S0000000…              6 gold     
#> 10 W0000000… 10.1… Colo… This st…  2019 revi… S0000000…              5 gold     
#> # ℹ 190 more rows
#> # ℹ 7 more variables: language <chr>, pmid <chr>, arxiv_id <chr>,
#> #   openalex_id <chr>, is_retracted <lgl>, retraction_date <date>,
#> #   last_refreshed <dttm>
#> #
#> # Edge Data: 768 × 3
#>    from    to weight
#>   <int> <int>  <dbl>
#> 1     1    74  0.928
#> 2     1    92  0.926
#> 3     1   101  0.932
#> # ℹ 765 more rows
```

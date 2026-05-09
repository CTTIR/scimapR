# Build a bibliographic coupling network

Constructs an undirected bibliographic coupling network. Two works are
connected if they share at least `min_shared` cited references. The edge
weight equals the number of shared references.

## Usage

``` r
sm_network_coupling(corpus, min_shared = 1L, call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object with a populated `references` table.

- min_shared:

  Integer; minimum number of shared references to create an edge.
  Defaults to `1L`.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (undirected). Nodes carry `name` (work ID) and columns from
`corpus$works`. Edges carry a `weight` column representing the number of
shared references.

## Details

Bibliographic coupling is the mirror of co-citation: two works are
coupled if they cite the same references, suggesting intellectual
similarity.

Empty input (zero works, zero references, or no pairs above the
threshold) returns an empty undirected `tbl_graph`.

## See also

Other networks:
[`sm_network_citation()`](https://r-heller.github.io/scimapR/reference/sm_network_citation.md),
[`sm_network_cocitation()`](https://r-heller.github.io/scimapR/reference/sm_network_cocitation.md),
[`sm_network_collab()`](https://r-heller.github.io/scimapR/reference/sm_network_collab.md),
[`sm_network_coword()`](https://r-heller.github.io/scimapR/reference/sm_network_coword.md),
[`sm_network_semantic()`](https://r-heller.github.io/scimapR/reference/sm_network_semantic.md)

## Examples

``` r
corpus <- sm_example_corpus()
g <- sm_network_coupling(corpus, min_shared = 3L)
g
#> # A tbl_graph: 131 nodes and 494 edges
#> #
#> # A bipartite simple graph with 1 component
#> #
#> # Node Data: 131 × 16 (active)
#>    name      doi   title abstract  year type  source_id cited_by_count oa_status
#>    <chr>     <chr> <chr> <chr>    <int> <chr> <chr>              <int> <chr>    
#>  1 W0000000… 10.1… Biom… This st…  2020 jour… S0000000…              9 hybrid   
#>  2 W0000000… 10.1… Colo… This st…  2024 jour… S0000000…             28 green    
#>  3 W0000000… 10.1… Tumo… This st…  2020 revi… S0000000…             29 green    
#>  4 W0000000… 10.1… Clin… This st…  2020 jour… S0000000…             16 hybrid   
#>  5 W0000000… 10.1… Sing… This st…  2021 lett… S0000000…             26 bronze   
#>  6 W0000000… 10.1… Colo… This st…  2020 jour… S0000000…              7 hybrid   
#>  7 W0000000… 10.1… Colo… This st…  2019 revi… S0000000…              5 gold     
#>  8 W0000000… 10.1… Sing… This st…  2016 jour… S0000000…             12 closed   
#>  9 W0000000… 10.1… Biom… This st…  2015 revi… S0000000…              4 closed   
#> 10 W0000000… 10.1… Colo… This st…  2021 jour… S0000000…             22 closed   
#> # ℹ 121 more rows
#> # ℹ 7 more variables: language <chr>, pmid <chr>, arxiv_id <chr>,
#> #   openalex_id <chr>, is_retracted <lgl>, retraction_date <date>,
#> #   last_refreshed <dttm>
#> #
#> # Edge Data: 494 × 3
#>    from    to weight
#>   <int> <int>  <int>
#> 1     1    94      5
#> 2     1    98      3
#> 3     1   101      3
#> # ℹ 491 more rows
```

# Build a co-citation network

Constructs an undirected co-citation network. Two works (A and B) are
connected by an edge if they are both cited by a common third work. The
edge weight equals the number of works that co-cite A and B.

## Usage

``` r
sm_network_cocitation(corpus, min_weight = 2L, call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object with a populated `references` table.

- min_weight:

  Integer; minimum co-citation count to retain an edge. Defaults to `2L`
  to reduce noise.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (undirected). Nodes carry `name` (work ID) and columns from
`corpus$works`. Edges carry a `weight` column representing co-citation
frequency.

## Details

The algorithm:

1.  For every citing work, enumerate all pairs of cited works.

2.  Count how often each pair co-occurs.

3.  Filter by `min_weight`.

Empty input (zero works, zero references, or no pairs above the
threshold) returns an empty undirected `tbl_graph`.

## See also

Other networks:
[`sm_network_citation()`](https://r-heller.github.io/scimapR/reference/sm_network_citation.md),
[`sm_network_collab()`](https://r-heller.github.io/scimapR/reference/sm_network_collab.md),
[`sm_network_coupling()`](https://r-heller.github.io/scimapR/reference/sm_network_coupling.md),
[`sm_network_coword()`](https://r-heller.github.io/scimapR/reference/sm_network_coword.md),
[`sm_network_semantic()`](https://r-heller.github.io/scimapR/reference/sm_network_semantic.md)

## Examples

``` r
corpus <- sm_example_corpus()
g <- sm_network_cocitation(corpus, min_weight = 2L)
g
#> # A tbl_graph: 198 nodes and 2289 edges
#> #
#> # A bipartite simple graph with 1 component
#> #
#> # Node Data: 198 × 16 (active)
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
#> # ℹ 188 more rows
#> # ℹ 7 more variables: language <chr>, pmid <chr>, arxiv_id <chr>,
#> #   openalex_id <chr>, is_retracted <lgl>, retraction_date <date>,
#> #   last_refreshed <dttm>
#> #
#> # Edge Data: 2,289 × 3
#>    from    to weight
#>   <int> <int>  <int>
#> 1     1     7      3
#> 2     1     9      2
#> 3     1    10      2
#> # ℹ 2,286 more rows
```

# Build a direct citation network

Constructs a directed citation network from the references table of an
`sm_corpus`. Each node represents a work and a directed edge runs from
the citing work to the cited work. Only works present in the corpus
(i.e. both the citing and cited work exist in `corpus$works`) are
included as nodes unless external references are also present via
`cited_work_id`.

## Usage

``` r
sm_network_citation(corpus, call = rlang::caller_env())
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object. Must contain a non-empty `references` table with columns
  `work_id` and `cited_work_id`.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (directed). Node data contains `name` (the work ID) plus any
columns from `corpus$works`. Edge data contains `from`, `to`, and any
additional reference metadata.

## Details

Empty input (zero works or zero references) returns an empty directed
`tbl_graph` with a single `name` column on nodes and no edges.

## See also

Other networks:
[`sm_network_cocitation()`](https://cttir.github.io/scimapR/reference/sm_network_cocitation.md),
[`sm_network_collab()`](https://cttir.github.io/scimapR/reference/sm_network_collab.md),
[`sm_network_coupling()`](https://cttir.github.io/scimapR/reference/sm_network_coupling.md),
[`sm_network_coword()`](https://cttir.github.io/scimapR/reference/sm_network_coword.md),
[`sm_network_semantic()`](https://cttir.github.io/scimapR/reference/sm_network_semantic.md)

## Examples

``` r
corpus <- sm_example_corpus()
g <- sm_network_citation(corpus)
g
#> # A tbl_graph: 200 nodes and 1869 edges
#> #
#> # A bipartite simple graph with 1 component
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
#> # Edge Data: 1,869 × 2
#>    from    to
#>   <int> <int>
#> 1     1     9
#> 2     1     7
#> 3     1    47
#> # ℹ 1,866 more rows
```

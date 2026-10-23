# Build a co-citation network

Constructs an undirected co-citation network. Two works (A and B) are
connected by an edge if they are both cited by a common third work. The
edge weight equals the number of works that co-cite A and B.

## Usage

``` r
sm_network_cocitation(
  corpus,
  min_weight = 2L,
  linked_only = FALSE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object with a populated `references` table.

- min_weight:

  Integer; minimum co-citation count to retain an edge. Defaults to `2L`
  to reduce noise.

- linked_only:

  Use only references with a `cited_work_id`. Defaults to `FALSE`, which
  includes cited items outside the corpus.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (undirected). Nodes carry `name` (work ID for corpus works, else
DOI, OpenAlex id or original reference text), `in_corpus`, and columns
from `corpus$works` (missing for external items). Edges carry a `weight`
column representing co-citation frequency.

## Details

The algorithm:

1.  For every citing work, enumerate all pairs of cited works.

2.  Count how often each pair co-occurs.

3.  Filter by `min_weight`. Each work counts a cited item once;
    self-references are excluded. Items are keyed by `cited_work_id`,
    else normalised DOI, else OpenAlex id, else upper-case reference
    text with whitespace squished and final periods removed. Identifier
    kinds are kept separate, even when labels coincide.
    `linked_only = TRUE` restores the earlier behaviour and warns when
    none points to corpus works.

Empty input (zero works, zero references, or no pairs above the
threshold) returns an empty undirected `tbl_graph`.

## See also

[`sm_link_references()`](https://cttir.github.io/scimapR/dev/reference/sm_link_references.md)

Other networks:
[`sm_network_citation()`](https://cttir.github.io/scimapR/dev/reference/sm_network_citation.md),
[`sm_network_collab()`](https://cttir.github.io/scimapR/dev/reference/sm_network_collab.md),
[`sm_network_coupling()`](https://cttir.github.io/scimapR/dev/reference/sm_network_coupling.md),
[`sm_network_coword()`](https://cttir.github.io/scimapR/dev/reference/sm_network_coword.md),
[`sm_network_semantic()`](https://cttir.github.io/scimapR/dev/reference/sm_network_semantic.md)

## Examples

``` r
corpus <- sm_example_corpus()
g <- sm_network_cocitation(corpus, min_weight = 2L)
g
#> # A tbl_graph: 198 nodes and 2289 edges
#> #
#> # A bipartite simple graph with 1 component
#> #
#> # Node Data: 198 × 17 (active)
#>    name      in_corpus doi   title abstract  year type  source_id cited_by_count
#>    <chr>     <lgl>     <chr> <chr> <chr>    <int> <chr> <chr>              <int>
#>  1 W0000000… TRUE      10.1… Tumo… This st…  2023 jour… S0000000…              3
#>  2 W0000000… TRUE      10.1… Biom… This st…  2020 jour… S0000000…              9
#>  3 W0000000… TRUE      10.1… Colo… This st…  2024 jour… S0000000…             28
#>  4 W0000000… TRUE      10.1… Tumo… This st…  2020 revi… S0000000…             29
#>  5 W0000000… TRUE      10.1… Clin… This st…  2020 jour… S0000000…             16
#>  6 W0000000… TRUE      10.1… Tumo… This st…  2018 jour… S0000000…             16
#>  7 W0000000… TRUE      10.1… Sing… This st…  2021 lett… S0000000…             26
#>  8 W0000000… TRUE      10.1… Colo… This st…  2020 jour… S0000000…              7
#>  9 W0000000… TRUE      10.1… Gene… This st…  2024 revi… S0000000…              6
#> 10 W0000000… TRUE      10.1… Colo… This st…  2019 revi… S0000000…              5
#> # ℹ 188 more rows
#> # ℹ 8 more variables: oa_status <chr>, language <chr>, pmid <chr>,
#> #   arxiv_id <chr>, openalex_id <chr>, is_retracted <lgl>,
#> #   retraction_date <date>, last_refreshed <dttm>
#> #
#> # Edge Data: 2,289 × 3
#>    from    to weight
#>   <int> <int>  <int>
#> 1     1     7      3
#> 2     1     9      2
#> 3     1    10      2
#> # ℹ 2,286 more rows
```

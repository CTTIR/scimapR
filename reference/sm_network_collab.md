# Build a collaboration network

Constructs an undirected collaboration (co-authorship) network. Nodes
represent entities at the chosen `level` (authors, institutions, or
countries) and an edge connects two entities if they co-authored at
least one work. Edge weight equals the number of co-authored works.

## Usage

``` r
sm_network_collab(
  corpus,
  level = c("author", "institution", "country"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object with a populated `authorships` table.

- level:

  Character; the entity level for network nodes. One of `"author"`
  (default), `"institution"`, or `"country"`.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (undirected). Nodes carry `name` (entity ID or label) and, for
`"author"` level, columns from `corpus$authors`. Edges carry a `weight`
column.

## Details

For `level = "author"`, the `author_id` column from `authorships` is
used and author metadata is joined from `corpus$authors`.

For `level = "institution"`, the `institution_id` column is used and
institution metadata is joined from `corpus$institutions`.

For `level = "country"`, the `country_code` column is used.

Empty input returns an empty undirected `tbl_graph`.

## See also

Other networks:
[`sm_network_citation()`](https://r-heller.github.io/scimapR/reference/sm_network_citation.md),
[`sm_network_cocitation()`](https://r-heller.github.io/scimapR/reference/sm_network_cocitation.md),
[`sm_network_coupling()`](https://r-heller.github.io/scimapR/reference/sm_network_coupling.md),
[`sm_network_coword()`](https://r-heller.github.io/scimapR/reference/sm_network_coword.md),
[`sm_network_semantic()`](https://r-heller.github.io/scimapR/reference/sm_network_semantic.md)

## Examples

``` r
corpus <- sm_example_corpus()
g <- sm_network_collab(corpus, level = "author")
g
#> # A tbl_graph: 80 nodes and 1077 edges
#> #
#> # An undirected simple graph with 1 component
#> #
#> # Node Data: 80 × 7 (active)
#>    name       orcid          display_name display_name_alterna…¹ inferred_gender
#>    <chr>      <chr>          <chr>        <list>                 <chr>          
#>  1 A000000001 0000-0003-668… Elena Fisch… <chr [0]>              NA             
#>  2 A000000002 NA             Elena Sato   <chr [0]>              NA             
#>  3 A000000003 0000-0001-958… Sarah Wang   <chr [0]>              NA             
#>  4 A000000004 0000-0002-306… Anna Hassan  <chr [0]>              NA             
#>  5 A000000005 NA             Sarah Zhang  <chr [0]>              NA             
#>  6 A000000006 NA             Lars Tanaka  <chr [0]>              NA             
#>  7 A000000007 NA             Wei Johanss… <chr [0]>              NA             
#>  8 A000000008 0000-0002-788… Maria Johns… <chr [0]>              NA             
#>  9 A000000009 NA             Carlos Smith <chr [0]>              NA             
#> 10 A000000010 0000-0001-489… Erik Kumar   <chr [0]>              NA             
#> # ℹ 70 more rows
#> # ℹ abbreviated name: ¹​display_name_alternatives
#> # ℹ 2 more variables: gender_confidence <dbl>, gender_method <chr>
#> #
#> # Edge Data: 1,077 × 3
#>    from    to weight
#>   <int> <int>  <int>
#> 1     1     2      2
#> 2     1     3      2
#> 3     1     4      2
#> # ℹ 1,074 more rows
```

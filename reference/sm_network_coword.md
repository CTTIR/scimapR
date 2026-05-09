# Build a co-word (co-occurrence) network

Constructs an undirected co-word network. Nodes represent terms and an
edge connects two terms if they co-occur within the same work. Edge
weight equals the number of works in which both terms appear.

## Usage

``` r
sm_network_coword(
  corpus,
  field = c("concepts", "title", "abstract", "keywords"),
  ngram = 1L,
  min_freq = 5L,
  stopwords = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object.

- field:

  Character; the text field to extract terms from. One of `"concepts"`
  (default, uses `corpus$concepts`), `"title"`, `"abstract"`, or
  `"keywords"`.

- ngram:

  Integer; for free-text fields (`"title"`, `"abstract"`), the n-gram
  size to tokenise into. Defaults to `1L` (unigrams).

- min_freq:

  Integer; minimum document frequency a term must have to be included.
  Defaults to `5L`.

- stopwords:

  Character vector of additional stopwords to remove when tokenising
  free text. Combined with
  [tidytext::stop_words](https://juliasilge.github.io/tidytext/reference/stop_words.html).
  Set to `NULL` (default) for no additional stopwords.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (undirected). Nodes carry `name` (the term) and `freq` (document
frequency). Edges carry a `weight` column (co-occurrence count).

## Details

When `field = "concepts"`, terms come from the `concept_name` column in
`corpus$concepts` (no tokenisation needed).

When `field` is `"title"`, `"abstract"`, or `"keywords"`, the text is
tokenised with
[`tidytext::unnest_tokens()`](https://juliasilge.github.io/tidytext/reference/unnest_tokens.html)
using the chosen `ngram` size, stopwords are removed, and terms below
`min_freq` are dropped.

Empty input returns an empty undirected `tbl_graph`.

## See also

Other networks:
[`sm_network_citation()`](https://r-heller.github.io/scimapR/reference/sm_network_citation.md),
[`sm_network_cocitation()`](https://r-heller.github.io/scimapR/reference/sm_network_cocitation.md),
[`sm_network_collab()`](https://r-heller.github.io/scimapR/reference/sm_network_collab.md),
[`sm_network_coupling()`](https://r-heller.github.io/scimapR/reference/sm_network_coupling.md),
[`sm_network_semantic()`](https://r-heller.github.io/scimapR/reference/sm_network_semantic.md)

## Examples

``` r
corpus <- sm_example_corpus()
g <- sm_network_coword(corpus, field = "concepts", min_freq = 5L)
g
#> # A tbl_graph: 10 nodes and 45 edges
#> #
#> # An undirected simple graph with 1 component
#> #
#> # Node Data: 10 × 2 (active)
#>    name                     freq
#>    <chr>                   <int>
#>  1 biomarker discovery        74
#>  2 clinical outcomes          72
#>  3 colorectal cancer          82
#>  4 drug resistance            76
#>  5 gene expression            57
#>  6 immune checkpoint          79
#>  7 machine learning           66
#>  8 single-cell rna-seq        74
#>  9 spatial transcriptomics    67
#> 10 tumor microenvironment     58
#> #
#> # Edge Data: 45 × 3
#>    from    to weight
#>   <int> <int>  <int>
#> 1     1     2     21
#> 2     1     3     26
#> 3     1     4     30
#> # ℹ 42 more rows
```

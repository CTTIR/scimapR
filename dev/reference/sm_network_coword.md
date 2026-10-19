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
  vocabulary = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
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

- vocabulary:

  For `field = "keywords"` or `"concepts"`, the concept vocabularies to
  take terms from: names of vocabularies or of families of
  [`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
  such as `"author-keywords"` or `"indexer_keyword"`. `NULL` (default)
  means the author keywords for `"keywords"` (see Details) and every
  vocabulary for `"concepts"`. Must be `NULL` for `"title"` and
  `"abstract"`, whose terms come from the text.

- call:

  Caller environment for error reporting.

## Value

A
[tidygraph::tbl_graph](https://tidygraph.data-imaginist.com/reference/tbl_graph.html)
object (undirected). Nodes carry `name` (the term) and `freq` (document
frequency). Edges carry a `weight` column (co-occurrence count).

## Details

When `field = "concepts"`, terms come from the `concept_name` column in
`corpus$concepts` (no tokenisation needed), of every vocabulary or of
those named in `vocabulary`.

When `field = "keywords"`, terms are whole keywords from
`corpus$concepts`, not tokenised. By default these are the author
keywords (the `author_keyword` family: `author-keywords`,
`manual-tags`); a corpus without any falls back to the indexer keywords
(the `indexer_keyword` family: Keywords Plus, Scopus index keywords,
Zotero automatic tags and MeSH) with a message, and a corpus with
neither gives an empty network with a message. The fallback applies to
the whole corpus, not per work.

When `field` is `"title"` or `"abstract"`, the text is tokenised with
[`tidytext::unnest_tokens()`](https://juliasilge.github.io/tidytext/reference/unnest_tokens.html)
using the chosen `ngram` size and stopwords are removed.

Terms are lower-cased, and terms below `min_freq` are dropped. Empty
input returns an empty undirected `tbl_graph`.

## See also

Other networks:
[`sm_network_citation()`](https://cttir.github.io/scimapR/dev/reference/sm_network_citation.md),
[`sm_network_cocitation()`](https://cttir.github.io/scimapR/dev/reference/sm_network_cocitation.md),
[`sm_network_collab()`](https://cttir.github.io/scimapR/dev/reference/sm_network_collab.md),
[`sm_network_coupling()`](https://cttir.github.io/scimapR/dev/reference/sm_network_coupling.md),
[`sm_network_semantic()`](https://cttir.github.io/scimapR/dev/reference/sm_network_semantic.md)

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

# Keyword networks from a Web of Science file
path <- tempfile(fileext = ".txt")
writeLines(c(
  "PT J", "AU Doe, J", "TI First work",
  "DE heat illness; recruits; cooling", "ID HYPERTHERMIA; EXERCISE",
  "PY 2021", "UT WOS:000000000000001", "ER",
  "PT J", "AU Roe, R", "TI Second work",
  "DE heat illness; recruits", "ID HYPERTHERMIA; EXERCISE",
  "PY 2022", "UT WOS:000000000000002", "ER", "EF"
), path)
wos <- sm_read_wos(path, verbose = FALSE)
sm_network_coword(wos, field = "keywords", min_freq = 2L)
#> # A tbl_graph: 2 nodes and 1 edges
#> #
#> # An unrooted tree
#> #
#> # Node Data: 2 × 2 (active)
#>   name          freq
#>   <chr>        <int>
#> 1 heat illness     2
#> 2 recruits         2
#> #
#> # Edge Data: 1 × 3
#>    from    to weight
#>   <int> <int>  <int>
#> 1     1     2      2
sm_network_coword(wos, field = "keywords", vocabulary = "keywords-plus",
                  min_freq = 2L)
#> # A tbl_graph: 2 nodes and 1 edges
#> #
#> # An unrooted tree
#> #
#> # Node Data: 2 × 2 (active)
#>   name          freq
#>   <chr>        <int>
#> 1 exercise         2
#> 2 hyperthermia     2
#> #
#> # Edge Data: 1 × 3
#>    from    to weight
#>   <int> <int>  <int>
#> 1     1     2      2
```

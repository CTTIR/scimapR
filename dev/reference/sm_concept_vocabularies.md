# Controlled vocabulary for concept vocabularies

The canonical values of the `vocabulary` column of `corpus$concepts`.
Readers write these names (for example `"author-keywords"` for author
keywords and `"wos-category"` for the Web of Science categories), and
the functions that select concepts by vocabulary, such as
[`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)
(DE) and
[`sm_network_coword()`](https://cttir.github.io/scimapR/dev/reference/sm_network_coword.md)
(`field = "keywords"`), read them.

Each vocabulary belongs to a family:

- `author_keyword`: `author-keywords`, `manual-tags`;

- `indexer_keyword`: `keywords-plus`, `index-keywords`,
  `automatic-tags`, `mesh`;

- `category`: `wos-category` (WC, the Web of Science categories),
  `wos-subject-category` (SC, the research areas);

- `concept`: `openalex`, `arxiv`, `biorxiv`, `medrxiv`;

- `custom`: `custom`, for vocabularies of your own.

[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
and
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)
rename legacy and common spellings to these names, with a message: case,
white space and the separators `-`, `_`, `.` and `/` do not matter,
`"keywords-author"`, `"keyword"` and `"keywords"` become
`"author-keywords"`, `"medline"` becomes `"mesh"`, and the Web of
Science field tags `"DE"`, `"ID"`, `"WC"` and `"SC"` name their
vocabularies. Other values are kept and named in the message. The
functions that select concepts by vocabulary read these spellings too,
so saved corpora and tables assigned to `corpus$concepts` work as well.
The column stays character.

## Usage

``` r
sm_concept_vocabularies(describe = FALSE)
```

## Arguments

- describe:

  Logical; if `TRUE`, return a tibble with the factor columns `level`
  and `family` and a `description`. If `FALSE` (default), return the
  character vector of vocabularies.

## Value

A character vector (grouped by family) or a tibble of
`level`/`family`/`description`.

## See also

[`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md),
[`sm_network_coword()`](https://cttir.github.io/scimapR/dev/reference/sm_network_coword.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_build_corpus.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/dev/reference/sm_dedupe.md),
[`sm_link_references()`](https://cttir.github.io/scimapR/dev/reference/sm_link_references.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_oa_statuses()`](https://cttir.github.io/scimapR/dev/reference/sm_oa_statuses.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

## Examples

``` r
sm_concept_vocabularies()
#>  [1] "author-keywords"      "manual-tags"          "keywords-plus"       
#>  [4] "index-keywords"       "automatic-tags"       "mesh"                
#>  [7] "wos-category"         "wos-subject-category" "openalex"            
#> [10] "arxiv"                "biorxiv"              "medrxiv"             
#> [13] "custom"              
sm_concept_vocabularies(describe = TRUE)
#> # A tibble: 13 × 3
#>    level                family          description                             
#>    <fct>                <fct>           <chr>                                   
#>  1 author-keywords      author_keyword  Keywords chosen by the authors (Web of …
#>  2 manual-tags          author_keyword  Tags added by hand in Zotero.           
#>  3 keywords-plus        indexer_keyword Web of Science Keywords Plus (ID), deri…
#>  4 index-keywords       indexer_keyword Scopus index keywords, assigned by inde…
#>  5 automatic-tags       indexer_keyword Tags Zotero added automatically on impo…
#>  6 mesh                 indexer_keyword Medical Subject Headings from PubMed, D…
#>  7 wos-category         category        Web of Science categories (WC) of the j…
#>  8 wos-subject-category category        Web of Science research areas (SC), bro…
#>  9 openalex             concept         OpenAlex concepts.                      
#> 10 arxiv                concept         arXiv subject categories.               
#> 11 biorxiv              concept         bioRxiv subject categories.             
#> 12 medrxiv              concept         medRxiv subject categories.             
#> 13 custom               custom          A vocabulary defined by the user.       

corpus <- sm_example_corpus(n_works = 5, with_embeddings = FALSE)
table(corpus$concepts$vocabulary)
#> 
#> openalex 
#>       15 
```

# Controlled vocabulary for open-access statuses

Canonical values for `works$oa_status`. All levels except `closed` are
open; missing and unrecognised values are unknown. Status definitions
follow the OpenAlex taxonomy (see the link below), with `open` for
access without a known colour. When an export names several statuses,
the package uses the first recognised level in the order below: diamond,
gold, hybrid, bronze, green, open, closed.

[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
and
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)
normalise common spellings with a message. Consumers also recognise
those spellings in saved corpora. The column remains character, and
unknown strings are kept as written.

## Usage

``` r
sm_oa_statuses(describe = FALSE)
```

## Arguments

- describe:

  Logical; if `TRUE`, return a tibble with a factor `level`, logical
  `is_open` and character `description`; otherwise the character vector
  of statuses in precedence order.

## Value

A character vector or a tibble of status descriptions.

## See also

[`sm_audit_oa()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_oa.md),
[`sm_filter_works()`](https://cttir.github.io/scimapR/dev/reference/sm_filter_works.md),
<https://help.openalex.org/data/works/open-access/>

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_build_corpus.md),
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/dev/reference/sm_dedupe.md),
[`sm_link_references()`](https://cttir.github.io/scimapR/dev/reference/sm_link_references.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

## Examples

``` r
sm_oa_statuses()
#> [1] "diamond" "gold"    "hybrid"  "bronze"  "green"   "open"    "closed" 
sm_oa_statuses(describe = TRUE)
#> # A tibble: 7 × 3
#>   level   is_open description                                                   
#>   <fct>   <lgl>   <chr>                                                         
#> 1 diamond TRUE    Fully open-access journal without article processing charges. 
#> 2 gold    TRUE    Fully open-access journal.                                    
#> 3 hybrid  TRUE    Openly licensed article in a subscription journal.            
#> 4 bronze  TRUE    Publisher-hosted free text without an identified open licence.
#> 5 green   TRUE    Repository-hosted free copy of an otherwise restricted work.  
#> 6 open    TRUE    Open access with no known colour.                             
#> 7 closed  FALSE   No known open-access copy.                                    
```

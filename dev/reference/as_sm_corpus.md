# Coerce objects to sm_corpus

Generic function to convert various data types to an `sm_corpus` object.

## Usage

``` r
as_sm_corpus(x, ...)

# S3 method for class 'sm_corpus'
as_sm_corpus(x, ...)

# S3 method for class 'data.frame'
as_sm_corpus(x, source_label = "data.frame", ...)

# S3 method for class 'list'
as_sm_corpus(x, ...)

# S3 method for class 'bibliometrixDB'
as_sm_corpus(x, source_label = "bibliometrix-import", ...)
```

## Arguments

- x:

  An object to coerce.

- ...:

  Additional arguments passed to methods.

- source_label:

  Label for provenance tracking. For a bibliometrix data frame, rows
  with `DB = "ISI"` are labelled `"wos"` unless `source_label` is given.

## Value

An `sm_corpus` object.

## bibliometrix data frames

`as_sm_corpus()` reads a data frame made by
[`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)
or
[`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)
(class `bibliometrixDB`), and the file readers with
`engine = "bibliometrix"` use the same conversion:

- `works` from `TI`, `AB` (`TI_raw` and `AB_raw` where present, which
  keep the case of the file), `PY`, `DT`, `TC`, `LA`, `DI` and `PM`;

- `authors` and `authorships` from `AU` and `AF`, with one authorship
  row per author and address: the names in the brackets of `C1` (`C1raw`
  where present) link authors to addresses. An address without names, as
  in older records, belongs to every author of the work; one whose names
  designate none of the authors belongs to the author of a single-author
  work and else to nobody. Authors are told apart by the full names of
  `AF`; an entry whose given names are only initials, or that has no
  `AF`, belongs to the author with that surname and those initials when
  there is just one such author with a full name. `RP` gives
  `is_corresponding`: the authors it names before "(corresponding
  author)" or "(reprint author)", in any case, are `TRUE` on all their
  rows and the other authors of the work `FALSE`. Namesakes (the same
  surname and initials) are told apart by the address that `RP` gives
  with the name, and stay `NA` when it does not tell them apart; a work
  without `RP`, or whose `RP` designates none of its authors for
  certain, gets `NA` (unknown);

- `sources` from `SO`, `SN`, `EI`, `J9` and `JI` (`issn_l`, `issn`,
  `abbreviation`, `iso_abbreviation`);

- `references` from `CR`, with the DOI of each item that has one;

- `concepts` from `DE` (`DE_raw` where present), `ID`, `SC` and `WC`, in
  the vocabularies `author-keywords`, the indexer vocabulary of the
  source, `wos-subject-category` and `wos-category`. `ID` is read as
  `keywords-plus` for Web of Science data (`DB = "ISI"`), `mesh` for
  PubMed, Dimensions, Lens and Cochrane, `author-keywords` for BibTeX
  and RIS files (where bibliometrix stores the keywords of the file in
  `ID`) and `index-keywords` otherwise;

- `provenance` with `UT` as `source_id_external`.

## See also

Other corpus:
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_build_corpus.md),
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
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
corpus <- sm_example_corpus()
as_sm_corpus(corpus)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 200 | Authors: 80 | Institutions: 0
#> Years: 2015 - 2024
#> Sources (journals): 10
#> Embeddings: 200 x 64
#> Provenance: synthetic (200)
#> Status: Unlocked (last refreshed: 2026-10-25 19:57:44)
as_sm_corpus(corpus$works)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 200 | Authors: 0 | Institutions: 0
#> Years: 2015 - 2024
#> Sources (journals): 0
#> Embeddings: none
#> Status: Unlocked (last refreshed: never)
```

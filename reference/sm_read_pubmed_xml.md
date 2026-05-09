# Read PubMed XML files

Parse PubMed XML export files (NCBI DTD format) into an `sm_corpus`
object. Extracts article metadata from `PubmedArticle` nodes including
PMID, title, abstract, journal, authors, MeSH terms, DOI, and
publication type.

## Usage

``` r
sm_read_pubmed_xml(
  path,
  encoding = "UTF-8",
  engine = c("native", "bibliometrix", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a PubMed XML file.

- encoding:

  Character scalar. File encoding (default `"UTF-8"`).

- engine:

  Character scalar. One of `"native"` (built-in parser using
  [xml2::xml2](http://xml2.r-lib.org/reference/xml2-package.md)),
  `"bibliometrix"` (delegate to
  [`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)),
  or `"auto"` (try bibliometrix first, fall back to native).

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
object.

## Implementation

The native parser uses
[`xml2::read_xml()`](http://xml2.r-lib.org/reference/read_xml.md) to
parse the NCBI PubMed XML DTD. Each `PubmedArticle` element is processed
to extract:

- `MedlineCitation/PMID` for the PubMed identifier

- `MedlineCitation/Article/ArticleTitle` for the title

- `MedlineCitation/Article/Abstract/AbstractText` for the abstract
  (multiple sections are concatenated)

- `MedlineCitation/Article/Journal/Title` and `/ISSN` for the journal

- `MedlineCitation/Article/Journal/JournalIssue/PubDate/Year` for year

- `MedlineCitation/Article/AuthorList/Author` for authors

- `MedlineCitation/MeshHeadingList/MeshHeading` for MeSH terms

- `PubmedData/ArticleIdList/ArticleId[@IdType='doi']` for DOI

- `MedlineCitation/Article/PublicationTypeList` for document type

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959–975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## See also

Other readers:
[`sm_read_auto()`](https://cttir.github.io/scimapR/reference/sm_read_auto.md),
[`sm_read_bib()`](https://cttir.github.io/scimapR/reference/sm_read_bib.md),
[`sm_read_cochrane()`](https://cttir.github.io/scimapR/reference/sm_read_cochrane.md),
[`sm_read_dimensions()`](https://cttir.github.io/scimapR/reference/sm_read_dimensions.md),
[`sm_read_endnote()`](https://cttir.github.io/scimapR/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://cttir.github.io/scimapR/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/reference/sm_read_openalex_json.md),
[`sm_read_ris()`](https://cttir.github.io/scimapR/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://cttir.github.io/scimapR/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://cttir.github.io/scimapR/reference/sm_read_zotero.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_pubmed_xml("pubmed_result.xml")
corpus$works
} # }
```

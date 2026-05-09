# Read EndNote XML export files

Parse EndNote XML export files into an `sm_corpus` object. Uses
[xml2::xml2](http://xml2.r-lib.org/reference/xml2-package.md) to extract
record metadata from the EndNote XML format.

## Usage

``` r
sm_read_endnote(
  path,
  encoding = "UTF-8",
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to an EndNote XML file.

- encoding:

  Character scalar. File encoding (default `"UTF-8"`).

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
object.

## Implementation

The parser uses
[`xml2::read_xml()`](http://xml2.r-lib.org/reference/read_xml.md) to
read the EndNote XML format. Each `xml/records/record` element (or
`records/record`) is processed. The following fields are extracted:

- `titles/title/style` for the title

- `contributors/authors/author/style` for author names

- `dates/year/style` for year

- `periodical/full-title/style` or `secondary-title/style` for journal

- `electronic-resource-num/style` for DOI

- `abstract/style` for abstract

- `ref-type` attribute for document type

- `keywords/keyword/style` for keywords

- `accession-num/style` for record identifier

No bibliometrix engine is available since EndNote XML is not directly
supported as a format by
[`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html).

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
[`sm_read_lens()`](https://cttir.github.io/scimapR/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/reference/sm_read_openalex_json.md),
[`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://cttir.github.io/scimapR/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://cttir.github.io/scimapR/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://cttir.github.io/scimapR/reference/sm_read_zotero.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_endnote("library.xml")
corpus$works
} # }
```

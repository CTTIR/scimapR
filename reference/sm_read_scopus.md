# Read Scopus CSV files

Parse Scopus CSV export files into an `sm_corpus` object. Handles the
standard Scopus CSV format with columns for Authors, Title, Year, Source
title, DOI, Abstract, and more.

## Usage

``` r
sm_read_scopus(
  path,
  encoding = "UTF-8",
  engine = c("native", "bibliometrix", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a Scopus CSV file.

- encoding:

  Character scalar. File encoding (default `"UTF-8"`).

- engine:

  Character scalar. One of `"native"` (built-in parser),
  `"bibliometrix"` (delegate to
  [`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)),
  or `"auto"` (try bibliometrix first, fall back to native).

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An
[sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
object.

## Implementation

The native parser reads the Scopus CSV export using
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html).
Scopus CSV column names may vary between export versions; the parser
matches on known column name patterns. Key columns: Authors, Title,
Year, Source title, DOI, Abstract, Document Type, Cited by, Author
Keywords, Index Keywords, ISSN, Language of Original Document, EID.

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959–975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## See also

Other readers:
[`sm_read_auto()`](https://r-heller.github.io/scimapR/reference/sm_read_auto.md),
[`sm_read_bib()`](https://r-heller.github.io/scimapR/reference/sm_read_bib.md),
[`sm_read_cochrane()`](https://r-heller.github.io/scimapR/reference/sm_read_cochrane.md),
[`sm_read_dimensions()`](https://r-heller.github.io/scimapR/reference/sm_read_dimensions.md),
[`sm_read_endnote()`](https://r-heller.github.io/scimapR/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://r-heller.github.io/scimapR/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://r-heller.github.io/scimapR/reference/sm_read_openalex_json.md),
[`sm_read_pubmed_xml()`](https://r-heller.github.io/scimapR/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://r-heller.github.io/scimapR/reference/sm_read_ris.md),
[`sm_read_wos()`](https://r-heller.github.io/scimapR/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://r-heller.github.io/scimapR/reference/sm_read_zotero.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_scopus("scopus.csv")
corpus$works
} # }
```

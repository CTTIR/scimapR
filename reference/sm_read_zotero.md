# Read Zotero CSV export files

Parse Zotero CSV export files into an `sm_corpus` object. Handles the
standard Zotero CSV export format with columns for Key, Title, Author,
Publication Year, DOI, Publication Title, Abstract, and Item Type.

## Usage

``` r
sm_read_zotero(
  path,
  encoding = "UTF-8",
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a Zotero CSV file.

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

The parser reads the Zotero CSV export format using
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html).
Zotero CSV exports have a standard set of column names. Key columns
matched (case-insensitive): Key, Title, Author, Publication Year, DOI,
Publication Title, Abstract Note, Item Type, ISSN, Language, Manual
Tags, Automatic Tags. No bibliometrix engine is available since Zotero
CSV is not a format supported by
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
[`sm_read_endnote()`](https://cttir.github.io/scimapR/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://cttir.github.io/scimapR/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/reference/sm_read_openalex_json.md),
[`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://cttir.github.io/scimapR/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://cttir.github.io/scimapR/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/reference/sm_read_wos.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_zotero("zotero_export.csv")
corpus$works
} # }
```

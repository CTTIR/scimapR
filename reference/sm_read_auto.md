# Auto-detect bibliographic file format and read

Detect the bibliographic file format from the file extension and
content, then dispatch to the appropriate reader function.

## Usage

``` r
sm_read_auto(
  path,
  encoding = "UTF-8",
  engine = c("native", "bibliometrix", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a bibliographic file.

- encoding:

  Character scalar. File encoding (default `"UTF-8"`).

- engine:

  Character scalar. One of `"native"` (built-in parser),
  `"bibliometrix"` (delegate to
  [`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)),
  or `"auto"` (try bibliometrix first, fall back to native). Passed
  through to the selected reader. Ignored for formats without engine
  support (OpenAlex JSON, Zotero, EndNote XML).

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An
[sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
object.

## Implementation

Format detection proceeds in two stages:

1.  **Extension-based**: `.bib` (BibTeX), `.ris` (RIS), `.json`/`.jsonl`
    (OpenAlex JSON), `.xml` (PubMed XML or EndNote XML).

2.  **Content-based**: For `.csv`, `.tsv`, and `.txt` files, the first
    few lines are inspected for format-specific signatures:

    - WoS plaintext: begins with `FN ` or `PT ` tags

    - Scopus CSV: contains `EID` column header

    - Lens CSV: contains `Lens ID` column header

    - Dimensions CSV: contains `Dimensions ID` or `PubYear` header

    - Cochrane CSV: contains `Cochrane` in header or record-like
      structure

    - Zotero CSV: contains `Key` and `Item Type` columns

    - RIS-format content in non-`.ris` files

For XML files, the root element or DTD is inspected to distinguish
PubMed XML (`PubmedArticleSet` or `PubmedArticle`) from EndNote XML
(`xml/records` or `records`).

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959–975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## See also

Other readers:
[`sm_read_bib()`](https://r-heller.github.io/scimapR/reference/sm_read_bib.md),
[`sm_read_cochrane()`](https://r-heller.github.io/scimapR/reference/sm_read_cochrane.md),
[`sm_read_dimensions()`](https://r-heller.github.io/scimapR/reference/sm_read_dimensions.md),
[`sm_read_endnote()`](https://r-heller.github.io/scimapR/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://r-heller.github.io/scimapR/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://r-heller.github.io/scimapR/reference/sm_read_openalex_json.md),
[`sm_read_pubmed_xml()`](https://r-heller.github.io/scimapR/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://r-heller.github.io/scimapR/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://r-heller.github.io/scimapR/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://r-heller.github.io/scimapR/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://r-heller.github.io/scimapR/reference/sm_read_zotero.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_auto("references.bib")
corpus <- sm_read_auto("exported_data.csv")
} # }
```

# Read OpenAlex JSON files

Parse OpenAlex JSON export files into an `sm_corpus` object. Handles
both JSON arrays of works and newline-delimited JSON (JSONL) files.
Extracts fields from the OpenAlex works schema including id, doi, title,
publication year, type, cited_by_count, authorships, host venue,
concepts, open access status, and referenced works.

## Usage

``` r
sm_read_openalex_json(
  path,
  encoding = "UTF-8",
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a `.json` or `.jsonl` file.

- encoding:

  Character scalar. File encoding (default `"UTF-8"`).

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An
[sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
object.

## Implementation

The parser reads the OpenAlex works JSON schema as documented at
<https://docs.openalex.org/api-entities/works/work-object>. Both
standard JSON arrays and newline-delimited JSON (one work per line) are
supported. No bibliometrix engine is available since OpenAlex is not a
shared bibliometric export format.

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
[`sm_read_pubmed_xml()`](https://r-heller.github.io/scimapR/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://r-heller.github.io/scimapR/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://r-heller.github.io/scimapR/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://r-heller.github.io/scimapR/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://r-heller.github.io/scimapR/reference/sm_read_zotero.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_openalex_json("openalex_works.json")
corpus$works
} # }
```

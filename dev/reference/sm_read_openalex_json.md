# Read OpenAlex JSON files

Parse OpenAlex JSON export files into an `sm_corpus` object. Handles
JSON arrays of works, a saved API response (an object whose `results`
hold the works, compact or pretty-printed), a single work object and
newline-delimited JSON (JSONL, one work or one response per line).
Extracts fields from the OpenAlex works schema including id, doi, title,
publication year, type, cited_by_count, authorships, host venue,
concepts, open access status, and referenced works.

The works also keep OpenAlex's field-weighted citation impact (`fwci`),
its citation percentile (`citation_percentile`, 0 to 1, with the flags
`is_top_10pct` and `is_top_1pct`) and the day of the record's
`updated_date` (`citations_as_of`, `NA` when the file has none), all
`NA` where a record lacks them, and the corpus gets the yearly citation
counts (`counts_by_year`) as `citations_by_year` (see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)).
Each authorship's `raw_affiliation` holds its `raw_affiliation_strings`
(joined with `"; "`), else the `raw_affiliation_string` of its
`affiliations`, else the names of its institutions. Works are linked to
their source (`works$source_id`), and sources are told apart by their
OpenAlex id, else by their name.

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
[sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
object.

## Implementation

The parser reads the OpenAlex works JSON schema as documented at
<https://developers.openalex.org/api-entities/works/work-object>. The
whole file is parsed first; only when that fails is it read as
newline-delimited JSON, one value per line. No bibliometrix engine is
available since OpenAlex is not a shared bibliometric export format.

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959–975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## See also

[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md)

Other readers:
[`sm_read_auto()`](https://cttir.github.io/scimapR/dev/reference/sm_read_auto.md),
[`sm_read_bib()`](https://cttir.github.io/scimapR/dev/reference/sm_read_bib.md),
[`sm_read_cochrane()`](https://cttir.github.io/scimapR/dev/reference/sm_read_cochrane.md),
[`sm_read_dimensions()`](https://cttir.github.io/scimapR/dev/reference/sm_read_dimensions.md),
[`sm_read_endnote()`](https://cttir.github.io/scimapR/dev/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://cttir.github.io/scimapR/dev/reference/sm_read_lens.md),
[`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/dev/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://cttir.github.io/scimapR/dev/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://cttir.github.io/scimapR/dev/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://cttir.github.io/scimapR/dev/reference/sm_read_zotero.md)

## Examples

``` r
path <- system.file("extdata", "example_openalex_inverted.json",
                    package = "scimapR")
corpus <- sm_read_openalex_json(path, verbose = FALSE)
corpus$works[c("title", "year", "cited_by_count")]
#> # A tibble: 3 × 3
#>   title                                         year cited_by_count
#>   <chr>                                        <int>          <int>
#> 1 A work with a normal inverted-index abstract  2021              7
#> 2 A work with an empty inverted index           2022              0
#> 3 A work with no abstract field at all          2023              1
```

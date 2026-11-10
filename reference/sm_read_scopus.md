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

An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
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
[`sm_read_auto()`](https://cttir.github.io/scimapR/reference/sm_read_auto.md),
[`sm_read_bib()`](https://cttir.github.io/scimapR/reference/sm_read_bib.md),
[`sm_read_cochrane()`](https://cttir.github.io/scimapR/reference/sm_read_cochrane.md),
[`sm_read_dimensions()`](https://cttir.github.io/scimapR/reference/sm_read_dimensions.md),
[`sm_read_endnote()`](https://cttir.github.io/scimapR/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://cttir.github.io/scimapR/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/reference/sm_read_openalex_json.md),
[`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://cttir.github.io/scimapR/reference/sm_read_ris.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://cttir.github.io/scimapR/reference/sm_read_zotero.md)

## Examples

``` r
corpus <- sm_read_scopus(sm_example_files("example_scopus.csv"), verbose = FALSE)
corpus
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 3 | Authors: 9 | Institutions: 0
#> Years: 2022 - 2024
#> Sources (journals): 3
#> Embeddings: none
#> Provenance: scopus (3)
#> Status: Unlocked (last refreshed: never)
head(corpus$works)
#> # A tibble: 3 × 16
#>   work_id    doi   title abstract  year type  source_id cited_by_count oa_status
#>   <chr>      <chr> <chr> <chr>    <int> <chr> <chr>              <int> <chr>    
#> 1 W000000001 10.1… Spat… Spatial…  2023 Arti… S0000000…             42 NA       
#> 2 W000000002 10.1… Mach… We deve…  2022 Conf… S0000000…             18 NA       
#> 3 W000000003 10.1… Comp… This st…  2024 Revi… S0000000…              7 NA       
#> # ℹ 7 more variables: language <chr>, pmid <chr>, arxiv_id <chr>,
#> #   openalex_id <chr>, is_retracted <lgl>, retraction_date <date>,
#> #   last_refreshed <dttm>
```

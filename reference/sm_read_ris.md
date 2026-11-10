# Read RIS files

Parse RIS (Research Information Systems) tag-value format files into an
`sm_corpus` object. Supports the standard RIS specification with
two-letter tags followed by two spaces, a dash, and a space.

## Usage

``` r
sm_read_ris(
  path,
  encoding = "UTF-8",
  engine = c("native", "bibliometrix", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a `.ris` file.

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

The native parser follows the RIS format specification (Thomson
Reuters). Each record starts with `TY -` and ends with `ER -`. Tags are
two uppercase letters followed by two spaces, a hyphen, and a space.
Repeating tags (AU, KW) generate multiple values per record.

Publication year comes from the first usable year in `PY`, `Y1`, then
`DA`. Bare years and dates such as `2019/03/01/` or `2020///` are
accepted: the first isolated four-digit year from 1000 through 2999 is
used. `Y2` is never a fallback because it often holds an access or
secondary date. Unrecognised dates yield `NA` without a coercion
warning.

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
[`sm_read_scopus()`](https://cttir.github.io/scimapR/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://cttir.github.io/scimapR/reference/sm_read_zotero.md)

## Examples

``` r
corpus <- sm_read_ris(sm_example_files("example.ris"), verbose = FALSE)
corpus
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 3 | Authors: 9 | Institutions: 0
#> Years: 2022 - 2024
#> Sources (journals): 2
#> Embeddings: none
#> Provenance: ris (3)
#> Status: Unlocked (last refreshed: never)
head(corpus$works)
#> # A tibble: 3 × 16
#>   work_id    doi   title abstract  year type  source_id cited_by_count oa_status
#>   <chr>      <chr> <chr> <chr>    <int> <chr> <chr>              <int> <chr>    
#> 1 W000000001 10.1… Spat… Spatial…  2023 JOUR  S0000000…             NA NA       
#> 2 W000000002 10.1… Mach… We deve…  2022 CONF  S0000000…             NA NA       
#> 3 W000000003 10.1… Atla… This co…  2024 BOOK  NA                    NA NA       
#> # ℹ 7 more variables: language <chr>, pmid <chr>, arxiv_id <chr>,
#> #   openalex_id <chr>, is_retracted <lgl>, retraction_date <date>,
#> #   last_refreshed <dttm>
```

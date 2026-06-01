# Verify journal source coverage against an index by ISSN

Checks whether each supplied ISSN appears in a journal master list (e.g.
the Web of Science Master Journal List, a Scopus source list, or a DOAJ
export). Matching is by normalised ISSN and checks both print and
electronic ISSNs.

This function is deliberately offline and data-driven: it never scrapes
or hardcodes proprietary lists. You supply the master list via
`reference_list`, so the function is fully testable and reproducible.

## Usage

``` r
sm_journal_in_index(
  issn,
  index = c("wos", "scopus", "doaj"),
  reference_list = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- issn:

  Character vector of ISSNs to check. Hyphenation and case are
  normalised automatically (e.g. `"15452786"` and `"1545-2786"` are
  equivalent; a lowercase `x` check digit is upper-cased).

- index:

  Which index the master list represents: `"wos"` (default), `"scopus"`,
  or `"doaj"`. This is a label echoed in the output; the actual matching
  is performed entirely against `reference_list`.

- reference_list:

  A data frame master list. Expected columns (matched
  case-insensitively):

  title

  :   Journal title (aliases: `title`, `journal`, `journal_title`,
      `source_title`, `display_name`).

  ISSN columns

  :   One or more of `issn`, `issn_print`, `print_issn`,
      `issn_electronic`, `issn_online`, `eissn`, `issn_l`. Columns whose
      name indicates "electronic"/"online"/"eissn" are reported as
      `"electronic"`; print columns as `"print"`; a bare `issn`/`issn_l`
      column as `"unknown"`.

  A small synthetic example list ships at
  `system.file("extdata", "example_journal_index.csv", package = "scimapR")`.

- call:

  Caller environment for error reporting.

## Value

A tibble with one row per input `issn` and columns: `issn` (the
normalised input), `index`, `in_index` (logical), `matched_title`
(character or `NA`), `matched_issn_type`
(`"print"`/`"electronic"`/`"unknown"`/`NA`). Type-stable: an empty
`issn` vector returns a 0-row tibble with these columns.

## See also

[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)

Other coverage:
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)

## Examples

``` r
ref <- utils::read.csv(
  system.file("extdata", "example_journal_index.csv", package = "scimapR"),
  stringsAsFactors = FALSE
)
sm_journal_in_index(c("1078-8956", "1546-170X", "9999-9999"),
                    index = "doaj", reference_list = ref)
#> # A tibble: 3 × 5
#>   issn      index in_index matched_title   matched_issn_type
#>   <chr>     <chr> <lgl>    <chr>           <chr>            
#> 1 1078-8956 doaj  TRUE     Nature Medicine print            
#> 2 1546-170X doaj  TRUE     Nature Medicine electronic       
#> 3 9999-9999 doaj  FALSE    NA              NA               
```

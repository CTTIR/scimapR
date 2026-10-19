# Get paths to example data files

Returns the path to bundled example bibliographic files in the package's
`inst/extdata` directory.

## Usage

``` r
sm_example_files(name = NULL)
```

## Arguments

- name:

  Name of the example file (without path). If `NULL`, lists all
  available files.

## Value

A character string path, or a character vector of available files.

## Real-use fixture

Three files form a synthetic fixture shaped like a corpus that was built
from a Web of Science export of three military-medical units and their
civilian partners. Everything in it is invented: units, cities, people,
journals, titles and DOIs (`10.9999/...`). The script
`data-raw/realuse-fixture.R` in the package sources rebuilds the files.

- `example_realuse_corpus.rds`:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  built with
  [`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md):
  150 works from 2016 to 2026, with authors, Web of Science style
  addresses (ten of them German strings with non-ASCII letters), one
  corresponding author per work, sources, Web of Science style cited
  references and keyword and category concepts. Extra `works` columns
  are `quartile` (`NA` for every 2026 work), `fwci`, `field` (the first
  Web of Science category), `volume` and `first_page`; `work_id` holds
  the Web of Science accession number. `metadata$last_refresh` is a
  numeric time stamp in seconds since 1970-01-01 UTC.

- `example_realuse_reference.csv`:

  A reference list in the style of a publication tracker, with columns
  `id`, `doi`, `title`, `year`, `institution` (the reporting unit) and
  `category` (a publication class code). It holds 120 of the corpus
  works and 40 items that are not in the corpus.

- `example_realuse_affiliation_dict.csv`:

  An affiliation dictionary in the
  [sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md)
  format (`institution`, `pattern`, `email_domain`) for
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md):
  institutes first, the hospital patterns anchored on its city next, a
  generic fallback last. Its institution names are the `institution`
  values of the reference list.

The CSV files are UTF-8 encoded.

## See also

Other example:
[`sm_example_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_example_corpus.md)

## Examples

``` r
sm_example_files()
#>  [1] "example.bib"                         
#>  [2] "example.ris"                         
#>  [3] "example_affiliation_postcode.csv"    
#>  [4] "example_dimensions.csv"              
#>  [5] "example_journal_index.csv"           
#>  [6] "example_lens.csv"                    
#>  [7] "example_openalex.json"               
#>  [8] "example_openalex_inverted.json"      
#>  [9] "example_pubmed.xml"                  
#> [10] "example_realuse_affiliation_dict.csv"
#> [11] "example_realuse_corpus.rds"          
#> [12] "example_realuse_reference.csv"       
#> [13] "example_ror.csv"                     
#> [14] "example_scopus.csv"                  
#> [15] "example_self_citation_corpus.rds"    
#> [16] "example_sparse.bib"                  
#> [17] "example_wos.txt"                     
sm_example_files("example.bib")
#> [1] "/home/runner/work/_temp/Library/scimapR/extdata/example.bib"

# The real-use fixture
fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
ref <- readr::read_csv(sm_example_files("example_realuse_reference.csv"),
                       col_types = "cccicc")
dict <- readr::read_csv(
  sm_example_files("example_realuse_affiliation_dict.csv"),
  col_types = "ccc"
)
matched <- sm_affiliation_match(fix, dict)
#> ✔ Affiliation matching flagged 427 authorships across 4 institutions.
#> ℹ By signal: name_token: 427. See `sm_affiliation_summary()` for the full
#>   breakdown.
table(matched$authorships$institution_match, useNA = "ifany")
#> 
#>                 Armed Forces Hospital Northtown 
#>                                             176 
#>  Federal Armed Forces Institute of Microbiology 
#>                                              85 
#>         Sonstige Dienststellen der Streitkräfte 
#>                                              56 
#> Zentrales Institut des Sanitätswesens Nordstadt 
#>                                             110 
#>                                            <NA> 
#>                                             365 
```

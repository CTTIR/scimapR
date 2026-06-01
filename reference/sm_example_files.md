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

## See also

Other example:
[`sm_example_corpus()`](https://cttir.github.io/scimapR/reference/sm_example_corpus.md)

## Examples

``` r
sm_example_files()
#>  [1] "example.bib"                    "example.ris"                   
#>  [3] "example_dimensions.csv"         "example_journal_index.csv"     
#>  [5] "example_lens.csv"               "example_openalex.json"         
#>  [7] "example_openalex_inverted.json" "example_pubmed.xml"            
#>  [9] "example_ror.csv"                "example_scopus.csv"            
#> [11] "example_sparse.bib"             "example_wos.txt"               
sm_example_files("example.bib")
#> [1] "/home/runner/work/_temp/Library/scimapR/extdata/example.bib"
```

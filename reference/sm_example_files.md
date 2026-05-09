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
#> [1] "example.bib"            "example.ris"            "example_dimensions.csv"
#> [4] "example_lens.csv"       "example_openalex.json"  "example_pubmed.xml"    
#> [7] "example_scopus.csv"     "example_wos.txt"       
sm_example_files("example.bib")
#> [1] "/home/runner/work/_temp/Library/scimapR/extdata/example.bib"
```

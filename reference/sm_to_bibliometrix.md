# Convert sm_corpus to bibliometrix format

Converts an `sm_corpus` to the data frame format used by
[`bibliometrix::biblioAnalysis()`](https://rdrr.io/pkg/bibliometrix/man/biblioAnalysis.html).
This enables using bibliometrix's analysis functions on corpora built
with scimapR.

## Usage

``` r
sm_to_bibliometrix(corpus, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- ...:

  Additional arguments (currently unused).

## Value

A data frame with class `c("bibliometrixDB", "data.frame")`.

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959-975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10, n_authors = 5)
M <- sm_to_bibliometrix(corpus)
class(M)
#> [1] "bibliometrixDB" "data.frame"    
```

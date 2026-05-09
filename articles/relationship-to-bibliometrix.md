# Relationship to bibliometrix

## Acknowledgement

scimapR is inspired by and designed as a complement to the excellent
**bibliometrix** package by Massimo Aria and Corrado Cuccurullo:

> Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
> comprehensive science mapping analysis. *Journal of Informetrics*,
> 11(4), 959–975. <doi:10.1016/j.joi.2017.08.007>

bibliometrix is the foundational R package for science mapping. It
pioneered many of the analyses that scimapR also provides, and its
Biblioshiny app set the standard for interactive bibliometric
exploration in R.

**scimapR is not a fork, not a derivative, and contains no code copied
or adapted from bibliometrix.** Where the two packages handle the same
bibliographic formats (WoS, Scopus, Cochrane, Lens, Dimensions, PubMed),
scimapR ships clean-room parsers written from the public format
specifications – never from reading bibliometrix source code.

## When to use which?

| Feature                       | bibliometrix  |      scimapR      |
|-------------------------------|:-------------:|:-----------------:|
| Classical bibliometrics       |    Mature     |     Available     |
| File parsing (WoS, Scopus, …) | Comprehensive | Clean-room native |
| Interactive app               |  Biblioshiny  |   scimapR Shiny   |
| Provenance tracking           |       –       |    First-class    |
| Embedding-based clustering    |       –       |     Built-in      |
| Research question objects     |       –       |    First-class    |
| LLM-grounded screening        |       –       |     Built-in      |
| Corpus certificates           |       –       |     Built-in      |
| Author trajectory             |       –       |     Built-in      |
| Equity auditing               |       –       |     Built-in      |
| LLM corpus chat               |       –       |     Built-in      |

**Recommendation:** If you are already using bibliometrix and it meets
your needs, continue using it. If you need embedding-native analysis,
provenance tracking, reproducible certificates, equity auditing, or LLM
features, scimapR adds those capabilities.

## Round-trip interop

scimapR provides first-class interop with bibliometrix:

``` r

library(scimapR)
corpus <- sm_example_corpus(n_works = 20, seed = 42)
```

### scimapR to bibliometrix

``` r

# Convert to bibliometrix format
M <- sm_to_bibliometrix(corpus)
class(M)

# Use with bibliometrix analysis functions
bibliometrix::biblioAnalysis(M)
```

### bibliometrix to scimapR

``` r

# Convert bibliometrix data frame to sm_corpus
corpus2 <- as_sm_corpus(M)
is_sm_corpus(corpus2)
```

### Round-trip preservation

The round-trip preserves DOI, title, year, and author count:

``` r

M <- sm_to_bibliometrix(corpus)
corpus_rt <- as_sm_corpus(M)

# Check preservation
all(corpus$works$doi %in% corpus_rt$works$doi, na.rm = TRUE)
```

## Engine delegation

For shared formats, scimapR readers accept `engine = "bibliometrix"` to
delegate parsing to bibliometrix:

``` r

# Use scimapR's native parser (default)
corpus1 <- sm_read_wos("data.txt", engine = "native")

# Delegate to bibliometrix
corpus2 <- sm_read_wos("data.txt", engine = "bibliometrix")
```

## Citation guidance

When using scimapR, please cite **both** packages:

``` r

citation("scimapR")
```

# Gender representation audit

Audits the inferred gender distribution of authors in a corpus. Gender
is inferred from first names using the specified method. Results include
the overall distribution, authorship-position breakdown, and a coverage
metric.

**This function infers a binary gender proxy from names, which has
well-documented limitations.** See the Limitations section in the
printed output and the details below.

## Usage

``` r
sm_audit_gender(
  corpus,
  method = c("genderize", "ssa", "manual"),
  api_key = Sys.getenv("GENDERIZE_API_KEY"),
  cache_dir = tools::R_user_dir("scimapR", "cache"),
  call = rlang::caller_env()
)

# S3 method for class 'sm_audit_gender'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- method:

  Character. Gender inference method:

  - `"genderize"`: Uses the genderize.io API (requires API key for high
    volume).

  - `"ssa"`: Uses US Social Security Administration frequency tables (no
    API needed, but US-centric).

  - `"manual"`: Uses pre-existing `inferred_gender` column in the
    authors table (no inference performed).

- api_key:

  Character. API key for genderize.io. Read from the `GENDERIZE_API_KEY`
  environment variable by default.

- cache_dir:

  Character. Directory for caching API results.

- call:

  Caller environment for error reporting.

- x:

  An audit object to print.

- ...:

  Ignored.

## Value

An `sm_audit_gender` S3 object containing:

- distribution:

  Tibble with columns `inferred_gender`, `count`, `pct`.

- by_position:

  Tibble breaking down gender by authorship position.

- coverage:

  Proportion of authors with an inferred gender.

- method:

  The method used.

- confidence_summary:

  Summary statistics for gender confidence scores.

## Details

**Known limitations of automated gender inference:**

- Name-based methods assign a binary gender proxy, which does not
  capture the full spectrum of gender identity.

- Accuracy varies dramatically by cultural context: names from East
  Asian, South Asian, and many African cultures are poorly served by
  Western-trained models.

- Non-binary, transgender, and gender-diverse individuals are
  systematically misclassified.

- The method cannot account for name changes, pen names, or initialised
  first names.

## See also

Other audit:
[`print.sm_audit_summary()`](https://cttir.github.io/scimapR/reference/sm_audit_summary.md),
[`sm_audit_funding()`](https://cttir.github.io/scimapR/reference/sm_audit_funding.md),
[`sm_audit_geographic()`](https://cttir.github.io/scimapR/reference/sm_audit_geographic.md),
[`sm_audit_oa()`](https://cttir.github.io/scimapR/reference/sm_audit_oa.md)

## Examples

``` r
corpus <- sm_example_corpus()
# Using manual method (no API call needed for examples):
gender_audit <- sm_audit_gender(corpus, method = "manual")
print(gender_audit)
#> 
#> ── <sm_audit_gender> ───────────────────────────────────────────────────────────
#> Method: manual
#> Coverage: 0% of authors have inferred gender
#> 
#> 
#> ── Overall distribution 
#> unknown: 80 (100%)
#> 
#> 
#> ── By authorship position 
#> first: NA: 233 (100%)
#> middle/last: NA: 522 (100%)
#> 
#> 
#> ── Limitations 
#> • Gender is INFERRED from first names using a binary proxy. This does not
#> capture the full spectrum of gender identity.
#> • Name-based methods have variable accuracy across cultures. East Asian, South
#> Asian, and many African names are poorly served by Western-trained models.
#> • Non-binary, transgender, and gender-diverse individuals are systematically
#> misclassified by these methods.
#> • Initialised first names (e.g., 'J. Smith') cannot be classified and reduce
#> coverage.
#> • These results should be reported with confidence intervals and
#> method-specific caveats in any publication.
#> • We recommend against using these results to make claims about individual
#> researchers' gender identity.
```

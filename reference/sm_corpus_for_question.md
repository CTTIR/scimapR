# Build a corpus from a research question

Takes a structured
[`sm_question()`](https://cttir.github.io/scimapR/reference/sm_question.md)
object, translates its fields into database-specific query strings,
fetches results from the requested bibliographic sources, deduplicates
on DOI, and returns an `sm_corpus` with `metadata$question_id` linked to
the question.

This function requires the appropriate API-client packages to be
installed for each source (`openalexR` for OpenAlex, `rcrossref` for
Crossref, `rentrez` for PubMed).

## Usage

``` r
sm_corpus_for_question(
  question,
  sources = c("pubmed", "openalex", "crossref"),
  n_max = 1000L,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- question:

  An `sm_question` object created with
  [`sm_question()`](https://cttir.github.io/scimapR/reference/sm_question.md).

- sources:

  Character vector of sources to query. Subset of `"pubmed"`,
  `"openalex"`, `"crossref"`.

- n_max:

  Integer. Maximum total number of works to retrieve (across all
  sources, before deduplication). Default `1000`.

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` with `metadata$question_id` set to the question's
content-hash ID.

## See also

Other question:
[`is_sm_question()`](https://cttir.github.io/scimapR/reference/is_sm_question.md),
[`sm_question()`](https://cttir.github.io/scimapR/reference/sm_question.md),
[`sm_screen_against_question()`](https://cttir.github.io/scimapR/reference/sm_screen_against_question.md),
[`sm_screen_regex()`](https://cttir.github.io/scimapR/reference/sm_screen_regex.md),
[`sm_screen_summary()`](https://cttir.github.io/scimapR/reference/sm_screen_summary.md)

## Examples

``` r
q <- sm_question(
  text = "Does immunotherapy improve survival in melanoma?",
  framework = "PICO",
  population = "melanoma",
  intervention = "immunotherapy",
  outcome = "survival"
)
# Would query live APIs:
# corpus <- sm_corpus_for_question(q)
```

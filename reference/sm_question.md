# Create a structured research question

Constructs an `sm_question` S3 object encoding a structured research
question using a recognised framework (PICO, PECO, PICOS, SPIDER, or
free-form). The object carries all structured fields, auto-generated
query strings suitable for bibliographic databases, and a prompt
template for LLM-based screening.

The question receives a content-addressable ID (SHA-256 hash of all
input fields), ensuring that identical questions always produce the same
identifier regardless of when they are created.

## Usage

``` r
sm_question(
  text,
  framework = c("PICO", "PECO", "PICOS", "SPIDER", "free"),
  population = NULL,
  intervention = NULL,
  comparison = NULL,
  outcome = NULL,
  exposure = NULL,
  design = NULL,
  timeframe = NULL,
  include_terms = NULL,
  exclude_terms = NULL,
  languages = "en",
  notes = NULL
)

# S3 method for class 'sm_question'
print(x, ...)

# S3 method for class 'sm_question'
format(x, ...)
```

## Arguments

- text:

  Character. The full research question in natural language.

- framework:

  Character. The structuring framework. One of `"PICO"` (Population,
  Intervention, Comparison, Outcome), `"PECO"` (Population, Exposure,
  Comparison, Outcome), `"PICOS"` (adds Study design), `"SPIDER"`
  (Sample, Phenomenon of Interest, Design, Evaluation, Research type),
  or `"free"` for unstructured questions.

- population:

  Character. The population or sample under study.

- intervention:

  Character. The intervention or phenomenon of interest.

- comparison:

  Character. The comparator or control condition.

- outcome:

  Character. The outcome(s) of interest.

- exposure:

  Character. The exposure (for PECO framework).

- design:

  Character. Study design (for PICOS/SPIDER frameworks).

- timeframe:

  Character. Optional time restriction.

- include_terms:

  Character vector. Additional terms that must appear in relevant works.

- exclude_terms:

  Character vector. Terms whose presence disqualifies a work.

- languages:

  Character vector. ISO 639-1 language codes to restrict the search.
  Default `"en"`.

- notes:

  Character. Free-text notes about the question.

- x:

  An `sm_question` object.

- ...:

  Ignored.

## Value

An `sm_question` S3 object with fields:

- id:

  Content-hash identifier.

- text:

  The research question text.

- framework:

  The structuring framework.

- created:

  POSIXct creation timestamp.

- population, intervention, comparison, outcome, exposure, design,
  timeframe:

  Structured facets (may be `NULL`).

- include_terms, exclude_terms:

  Term filters.

- languages:

  Language filter.

- notes:

  Free-text notes.

- query_strings:

  Named list of database-specific query strings.

- prompt_template:

  A prompt template for LLM screening.

&nbsp;

- [`print()`](https://rdrr.io/r/base/print.html): `x` invisibly.

- [`format()`](https://rdrr.io/r/base/format.html): A single character
  string.

## See also

Other question:
[`is_sm_question()`](https://cttir.github.io/scimapR/reference/is_sm_question.md),
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/reference/sm_corpus_for_question.md),
[`sm_screen_against_question()`](https://cttir.github.io/scimapR/reference/sm_screen_against_question.md),
[`sm_screen_regex()`](https://cttir.github.io/scimapR/reference/sm_screen_regex.md),
[`sm_screen_summary()`](https://cttir.github.io/scimapR/reference/sm_screen_summary.md)

## Examples

``` r
q <- sm_question(
  text = "Does immunotherapy improve survival in metastatic melanoma?",
  framework = "PICO",
  population = "adults with metastatic melanoma",
  intervention = "immune checkpoint inhibitors",
  comparison = "chemotherapy",
  outcome = "overall survival"
)
print(q)
#> 
#> ── <sm_question> ───────────────────────────────────────────────────────────────
#> ID: Q-c4c29fe2ebe4f3d3
#> Framework: PICO
#> Created: 2026-06-01 12:24:51
#> 
#> Question:
#> Does immunotherapy improve survival in metastatic melanoma?
#> 
#> 
#> ── Structured fields 
#> Population: adults with metastatic melanoma
#> Intervention: immune checkpoint inhibitors
#> Comparison: chemotherapy
#> Outcome: overall survival
#> 
#> Languages: en
#> 
#> ── Query strings 
#> generic: (adults with metastatic melanoma) AND (immune checkpoint inhibitors)
#> AND (che...
#> pubmed: (adults with metastatic melanoma[tiab]) AND (immune checkpoint
#> inhibitors[tia...
#> openalex: (adults with metastatic melanoma) AND (immune checkpoint inhibitors)
#> AND (che...
#> crossref: (adults with metastatic melanoma) AND (immune checkpoint inhibitors)
#> AND (che...
```

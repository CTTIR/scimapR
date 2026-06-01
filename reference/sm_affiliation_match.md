# Match author affiliations to institutions

A tested, extensible institution matcher for the `authorships` table. It
tags each authorship with the institution it belongs to, using a
dictionary of name variants (multilingual and synonym-aware) and an
optional email-domain fallback for records whose affiliation string is
missing.

Because the matcher operates per authorship row, it naturally handles
secondary / multiple affiliations per author (each authorship row is
matched independently).

## Usage

``` r
sm_affiliation_match(
  corpus,
  patterns = sm_affiliation_dict,
  fields = NULL,
  email_domain_fallback = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- patterns:

  A dictionary of institution name variants. Either:

  - a named list mapping each canonical institution name to a character
    vector of case-insensitive regex variant patterns, or

  - a data frame with columns `institution`, `pattern`, and an optional
    `email_domain` (the form of the bundled
    [sm_affiliation_dict](https://cttir.github.io/scimapR/reference/sm_affiliation_dict.md)).

  Defaults to
  [sm_affiliation_dict](https://cttir.github.io/scimapR/reference/sm_affiliation_dict.md).

- fields:

  Character vector of `authorships` columns to search for affiliation
  text. Defaults to `"raw_affiliation"` (plus `"email"` if such a column
  exists). Values across multiple fields are concatenated per row.

- email_domain_fallback:

  Logical; if `TRUE` (default) and an authorship has no pattern match
  but does have an email address (in an `email` column), match the
  email's domain against the dictionary's `email_domain` entries.

- call:

  Caller environment for error reporting.

## Value

The `corpus` with its `authorships` table gaining (or having updated)
two columns:

- institution_match:

  Canonical institution name, or `NA`.

- match_method:

  `"pattern"`, `"email_domain"`, or `"none"`.

Type-stable: a corpus with no authorships is returned unchanged with the
two columns present and 0 rows.

## Details

To extend the dictionary, append rows to
[sm_affiliation_dict](https://cttir.github.io/scimapR/reference/sm_affiliation_dict.md)
(or build your own data frame with the same columns) and pass it as
`patterns`. For example
`rbind(sm_affiliation_dict, tibble::tibble(institution = "My Uni", pattern = "my university", email_domain = "myuni.edu"))`.

## See also

[`sm_attribute_institution()`](https://cttir.github.io/scimapR/reference/sm_attribute_institution.md),
[sm_affiliation_dict](https://cttir.github.io/scimapR/reference/sm_affiliation_dict.md)

Other affiliation:
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/reference/sm_attribute_institution.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
matched <- sm_affiliation_match(corpus)
matched$authorships$institution_match[1]
#> [1] "Bundeswehr Hospital"
```

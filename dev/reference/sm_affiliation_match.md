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
  postcode_signal = FALSE,
  unicode = TRUE,
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
    [sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md)).

  Defaults to
  [sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md).

- fields:

  Character vector of `authorships` columns to search for affiliation
  text. Defaults to `"raw_affiliation"` (plus `"email"` if such a column
  exists). Values across multiple fields are concatenated per row.

- email_domain_fallback:

  Logical; if `TRUE` (default) and an authorship has no pattern match
  but does have an email address (in an `email` column), match the
  email's domain against the dictionary's `email_domain` entries.

- postcode_signal:

  Logical (default `FALSE`). When `TRUE` and the dictionary carries a
  `postcode` column, a postcode match is attempted as a last resort
  (lowest priority, after name tokens and email domains) so existing
  matches do not shift. Off by default.

- unicode:

  Logical (default `TRUE`). Match the patterns in Unicode mode, so `\w`,
  `\b`, `\d`, `\s` and POSIX classes such as `[[:alpha:]]` know
  non-ASCII letters, digits and spaces (see Details). `FALSE` gives the
  ASCII-only classes of scimapR 0.4.0 and earlier, to reproduce earlier
  results.

- call:

  Caller environment for error reporting.

## Value

The `corpus` with its `authorships` table gaining (or having updated)
four columns:

- institution_match:

  Canonical institution name, or `NA`.

- match_method:

  `"pattern"`, `"email_domain"`, `"postcode"`, or `"none"`.

- match_signal:

  The signal that fired: `"name_token"`, `"email_domain"`, `"postcode"`,
  or `"none"`. Precedence (highest first): name token, email domain,
  postcode.

- match_evidence:

  The actual substring / domain / postcode that triggered the match (an
  audit trail), or `NA`.

Type-stable: a corpus with no authorships is returned unchanged with the
four columns present and 0 rows. See
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md)
for a tidy breakdown.

## Details

Dictionary patterns are case-insensitive Perl-compatible regular
expressions (PCRE) with Unicode-aware `\w`, `\b`, `\d` and `\s`, matched
against the affiliation text of each authorship. The rows are tried in
dictionary order and the first pattern that matches wins, so list
specific patterns before generic ones.
[`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_unmatched.md)
lists the most frequent affiliation strings that nothing matched.

In Unicode mode (`unicode = TRUE`, the default) each pattern is prefixed
with the PCRE item `(*UCP)` unless its leading items already include it.
Umlauts, accented letters and the sharp s are then word characters: `\w`
consumes them, `\b` finds the edge of a word that starts or ends with
one, and POSIX classes such as `[[:alpha:]]` are Unicode-aware too. In
ASCII mode (`unicode = FALSE`) every non-ASCII letter is a non-word
character, like punctuation: a pattern such as `sanit\w+wesens` cannot
match the German word spelled with an a-umlaut, and `\b` finds no edge
between a space and a word that starts with an umlaut. Unicode mode can
therefore also lose matches. A pattern that used `\W`, `\S`, `\D` or
`\B` to stand for a non-ASCII letter no longer matches it, and `\b` no
longer finds an edge between an ASCII letter and a non-ASCII letter next
to it: the shipped pattern `\bnato\b` does not match "NATO" directly
followed by an umlaut, as in a German compound word. To keep ASCII
semantics in one place, write the class out, for example `[A-Za-z0-9_]`
instead of `\w`.

`unicode = FALSE` gives the matches of scimapR 0.4.0.
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
calls `sm_affiliation_match()` with its defaults, and so matches in
Unicode mode, when the corpus has no `institution_match` column; running
`sm_affiliation_match(unicode = FALSE)` first gives its earlier results.
`sm_count(level = "institution")` no longer matches affiliations itself:
it counts each authorship by its institution label, `institution_match`
first, and by its raw affiliation string when it has none (see
[`sm_count()`](https://cttir.github.io/scimapR/dev/reference/sm_count.md)).

The optional `postcode` column (used with `postcode_signal = TRUE`) is
matched case-sensitively as a whole word, in the same mode: it is
wrapped in `\b`, any run of whitespace in it matches any amount of
whitespace (including none), and it is used as a regular expression
without escaping.

To extend the dictionary, append rows to
[sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md)
(or build your own data frame with the same columns) and pass it as
`patterns`. For example
`rbind(sm_affiliation_dict, tibble::tibble(institution = "My Uni", pattern = "my university", email_domain = "myuni.edu"))`.

## See also

[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md),
[sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md),
[`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_unmatched.md)

Other affiliation:
[`sm_affiliation_methods()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_methods.md),
[`sm_affiliation_signals()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_signals.md),
[`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md),
[`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_unmatched.md),
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
matched <- sm_affiliation_match(corpus)
#> ✔ Affiliation matching flagged 1 authorship across 1 institution.
#> ℹ By signal: name_token: 1. See `sm_affiliation_summary()` for the full
#>   breakdown.
matched$authorships$institution_match[1]
#> [1] "Bundeswehr Hospital"

# In Unicode mode \w consumes the umlaut of a German unit name
corpus$authorships$raw_affiliation[2] <-
  "Zentrales Institut des Sanit\u00e4tswesens Nordstadt"
dict <- list("Central Medical Institute" = "sanit\\w+wesens")
matched <- sm_affiliation_match(corpus, patterns = dict)
#> ✔ Affiliation matching flagged 1 authorship across 1 institution.
#> ℹ By signal: name_token: 1. See `sm_affiliation_summary()` for the full
#>   breakdown.
matched$authorships$institution_match[2]
#> [1] "Central Medical Institute"
ascii <- sm_affiliation_match(corpus, patterns = dict, unicode = FALSE)
ascii$authorships$institution_match[2]
#> [1] NA
```

# Read BibTeX files

Parse standard BibTeX (`.bib`) files into an `sm_corpus` object.
Extracts entry type, title, author, year, DOI, journal, abstract,
volume, pages, and keywords from each `@type{key, ...}` entry.

## Usage

``` r
sm_read_bib(
  path,
  encoding = "UTF-8",
  engine = c("native", "bibliometrix", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a `.bib` file.

- encoding:

  Character scalar. File encoding (default `"UTF-8"`).

- engine:

  Character scalar. One of `"native"` (built-in parser),
  `"bibliometrix"` (delegate to
  [`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)),
  or `"auto"` (try bibliometrix first, fall back to native).

- verbose:

  Logical. Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An
[sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
object.

## Implementation

The native parser follows the BibTeX format specification as described
in the original BibTeX documentation (Patashnik, 1988). Field values may
be enclosed in braces or double-quotes and may span multiple lines.
String concatenation with `#` is not supported; `@string` and
`@preamble` entries are skipped.

Protective braces are removed from titles, journals, abstracts, keywords
and DOIs; escaped braces remain literal. Common LaTeX accent commands
(`\"`, `\'`, `\^`, `\~`, `\=`, `\.`, `\c`, `\v`, `\u`, `\H`, `\k`, `\r`,
and backslash followed by a grave accent) decode to precomposed letters
where available, else the bare letter. Letter commands `\ss`, `\o`,
`\O`, `\aa`, `\AA`, `\ae`, `\AE`, `\oe`, `\OE`, `\l`, `\L` and `\i` also
decode, as do `\&`, `\%`, `\$`, `\#` and `\_`. DOI cleaning only removes
braces and decodes those five escapes. Ties (`~`), `--` and math
expressions remain as written. Whitespace outside math is collapsed and
trimmed.

Only a lowercase `and` outside braces separates authors; a comma outside
braces flips a name from surname-first to given-name-first. Braced
corporate names stay together, and a trailing `and others` is retained.
Quoted field values end only at a quote outside braces. The first
isolated four-digit year (1000–2999) in `year` is used, falling back to
the BibLaTeX `date` field when no such year is present.

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959–975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## See also

Other readers:
[`sm_read_auto()`](https://cttir.github.io/scimapR/dev/reference/sm_read_auto.md),
[`sm_read_cochrane()`](https://cttir.github.io/scimapR/dev/reference/sm_read_cochrane.md),
[`sm_read_dimensions()`](https://cttir.github.io/scimapR/dev/reference/sm_read_dimensions.md),
[`sm_read_endnote()`](https://cttir.github.io/scimapR/dev/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://cttir.github.io/scimapR/dev/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/dev/reference/sm_read_openalex_json.md),
[`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/dev/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://cttir.github.io/scimapR/dev/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://cttir.github.io/scimapR/dev/reference/sm_read_scopus.md),
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md),
[`sm_read_zotero()`](https://cttir.github.io/scimapR/dev/reference/sm_read_zotero.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_bib("references.bib")
corpus$works
} # }
```

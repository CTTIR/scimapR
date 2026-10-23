# Read Web of Science export files

Parse Web of Science (WoS) plaintext or tab-delimited export files into
an `sm_corpus` object, preserving authors, fields and cited references.

## Usage

``` r
sm_read_wos(
  path,
  encoding = "UTF-8",
  engine = c("native", "bibliometrix", "auto"),
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character scalar. Path to a plaintext or tab-delimited export.

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

The native parser follows the Web of Science Core Collection export
format. Tab-delimited files have a header containing PT, AU, TI and UT
and one record per line. Cells are unquoted, so quotes in titles are
preserved. Both layouts share field, author and reference-linking rules.
Tab-delimited input always uses the native path with `engine = "native"`
or `"auto"`; `engine = "bibliometrix"` rejects it. UTF-8 BOMs are
accepted; UTF-16 exports can be read with `encoding = "UTF-16LE"`.

A file whose records all lack a title, accession number and author is an
error. Such records among readable ones are dropped with one warning,
including when `verbose = FALSE`. Files without any PT record still
return an empty corpus.

Each record begins with `PT ` (publication type) and ends with `ER`.
Field tags are two uppercase letters followed by a single space.
Continuation lines begin with three spaces. Tags parsed: AU or AF
(authors), TI (title), SO (source), SN and EI (ISSN and electronic
ISSN), J9 and JI (source abbreviations), AB (abstract), DI (DOI), PY
(year), DT (document type), LA (language), TC (times cited), UT
(accession number, kept in `provenance`), PM (PubMed ID), C1
(addresses), RP (corresponding authors), CR (cited references), DE
(author keywords), ID (Keywords Plus), WC (Web of Science categories)
and SC (research areas). Other tags are not read.

Each distinct SO becomes a row of `sources`, with `issn_l` from SN (EI
when SN is missing), `issn` holding SN and EI, and the abbreviations J9
and JI in the columns `abbreviation` and `iso_abbreviation`.

DE, ID, WC and SC become `concepts`, one row per `;`-separated term, in
the vocabularies `"author-keywords"`, `"keywords-plus"`,
`"wos-category"` and `"wos-subject-category"` of
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md).
Terms keep the case of the file.

Author names are stored in the AU form, such as "J Smith" for "Smith,
J", and `authors$display_name_alternatives` keeps the name as the file
writes it, which tells a surname of several words such as "Garcia Lopez"
from the initials.

Both parsers write one authorship row per author and address. The names
in the brackets of C1 link authors to addresses: each name belongs to
the author with the same full name (from AF), else to the one with the
same surname and initials, else to the one with the same surname and
first initial, so a short surname such as "He" never takes the address
of "Chen". An address that C1 lists without names, as older records do,
belongs to every author of the record, so each of them gets a row for
it. An address whose names designate none of the authors belongs to the
author of a single-author record and else to nobody.

The corresponding authors come from RP, which names them before
"(corresponding author)" ("(reprint author)" in older files), in any
case, with each name and its address on a line of its own or on one
line. The authors these names designate, matched like the names of C1,
get `is_corresponding = TRUE` on all their rows and the other authors
`FALSE`. When a name fits several authors equally (namesakes with the
same surname and initials), the one whose C1 addresses include the
address RP gives with the name is meant; if that does not tell them
apart, they get `NA`. A record without RP, or whose RP designates none
of its authors for certain, gets `NA` (unknown) for all its authors; the
native parser reports the number of such records when `verbose = TRUE`.

The `"bibliometrix"` engine (also used by `"auto"` when bibliometrix can
read the file) converts the data frame of
[`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)
as
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md)
does: it reads the same tags into `sources`, `references` and
`concepts`, tells authors apart by the full names of AF and links C1 and
RP to the authors by the same rule.

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959–975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## See also

Other readers:
[`sm_read_auto()`](https://cttir.github.io/scimapR/dev/reference/sm_read_auto.md),
[`sm_read_bib()`](https://cttir.github.io/scimapR/dev/reference/sm_read_bib.md),
[`sm_read_cochrane()`](https://cttir.github.io/scimapR/dev/reference/sm_read_cochrane.md),
[`sm_read_dimensions()`](https://cttir.github.io/scimapR/dev/reference/sm_read_dimensions.md),
[`sm_read_endnote()`](https://cttir.github.io/scimapR/dev/reference/sm_read_endnote.md),
[`sm_read_lens()`](https://cttir.github.io/scimapR/dev/reference/sm_read_lens.md),
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/dev/reference/sm_read_openalex_json.md),
[`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/dev/reference/sm_read_pubmed_xml.md),
[`sm_read_ris()`](https://cttir.github.io/scimapR/dev/reference/sm_read_ris.md),
[`sm_read_scopus()`](https://cttir.github.io/scimapR/dev/reference/sm_read_scopus.md),
[`sm_read_zotero()`](https://cttir.github.io/scimapR/dev/reference/sm_read_zotero.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_read_wos("savedrecs.txt")
corpus$works
} # }
```

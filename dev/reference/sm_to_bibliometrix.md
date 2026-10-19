# Convert sm_corpus to bibliometrix format

Converts an `sm_corpus` to the data frame format used by
[`bibliometrix::biblioAnalysis()`](https://rdrr.io/pkg/bibliometrix/man/biblioAnalysis.html)
and the other functions of bibliometrix: one row per work and one column
per Web of Science field tag. This enables using bibliometrix's analysis
functions on corpora built with scimapR.

## Usage

``` r
sm_to_bibliometrix(
  corpus,
  keep_extra = TRUE,
  db = c("auto", "ISI", "scimapR"),
  ...
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- keep_extra:

  Logical. If `TRUE` (default), the columns without a field tag follow
  the tag columns, as in earlier versions: the other `works` columns
  (such as `work_id` and `source_id`), `country_code` and `SO_ISSN`.
  `FALSE` returns the tag columns only.

- db:

  Value of the `DB` column. `"auto"` (default) writes `"ISI"` when every
  work comes from Web of Science and `"scimapR"` otherwise; `"ISI"` and
  `"scimapR"` write that value. See Details.

- ...:

  Additional arguments (currently unused).

## Value

A data frame with class `c("bibliometrixDB", "data.frame")`, one row per
work in the order of `corpus$works`, with `SR` as row names. Every tag
column is present, `NA` where the corpus holds no data.

## Details

### Field tags

- `AU`: authors as `SURNAME INITIALS`, `AF`: full names as
  `SURNAME, GIVEN NAMES`; one entry per author of the work, in
  `position` order and separated by `;`, from `authors$display_name`
  through `authorships`. An author with several address rows appears
  once; authors without a name are left out.

- `TI`, `AB`: `works$title`, `works$abstract`; `TI_raw` and `AB_raw`
  hold them in their stored case, as
  [`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)
  does.

- `SO`, `J9`, `JI`: `sources$display_name`, and the optional columns
  `sources$abbreviation` and `sources$iso_abbreviation`.

- `SN`, `EI`: `sources$issn_l` (else the first value of `sources$issn`)
  and the next distinct value of `sources$issn`.

- `C1`: one segment per distinct address of the work,
  `[AUTHOR A; AUTHOR B] ADDRESS`, with the authors (`AF` form) in
  `position` order, joined by `; `; from `authorships$raw_affiliation`.

- `RP`: one segment per corresponding author
  (`authorships$is_corresponding`),
  `SURNAME, INITIALS (CORRESPONDING AUTHOR), ADDRESS` with the author's
  first address, joined by `; `.

- `EM`: the e-mail addresses of the optional column `authorships$email`.

- `CR`: `references$cited_raw` in `ref_index` order, separated by `;`;
  `NR`: the number of items in `CR`.

- `DE`: author keywords, see below; `DE_raw` holds them in their stored
  case. `ID`: the concepts of the `indexer_keyword` family of
  [`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md)
  (such as Keywords Plus or MeSH). `WC`: the vocabulary `wos-category`
  (Web of Science categories); `SC`: the vocabulary
  `wos-subject-category` (research areas). Terms are joined by `; `.

- `DT`, `LA`, `PY`, `TC`, `DI`, `PM`: `works$type`, `language`, `year`,
  `cited_by_count`, `doi` and `pmid`.

- `UT`: the Web of Science accession number,
  `provenance$source_id_external` of the work's first provenance row
  with `source == "wos"`, else a `work_id` that starts with `WOS:`.

- `DB`: see below. `SR`: the short reference `FIRST AUTHOR, YEAR, J9`
  (with `SO` where `J9` is missing), made unique by appending `-a`,
  `-b`, ... to repeats; `SR_FULL` keeps it without the suffixes.

With `keep_extra = TRUE`, `country_code` holds the country codes of
`authorships$country_code`, one per authorship row (author and address),
and `SO_ISSN` holds `sources$issn_l`. The export has no `AU_CO` column,
as data from
[`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)
has none: `bibliometrix::metaTagExtraction(M, "AU_CO")` adds the country
names that bibliometrix reads from `C1` and uses for its country
analyses.

### Conventions

Like
[`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)
for Web of Science files, the export upper-cases `AU`, `AF`, `TI`, `SO`,
`J9`, `JI`, `AB`, `C1`, `RP`, `EM`, `CR` (including the DOIs in it),
`DE`, `ID`, `WC`, `SC`, `DT` and `LA`. `DI`, `UT`, `SN`, `EI` and `PM`
are written as stored, so `DI` keeps the lower-case DOIs of the scimapR
readers. Upper-casing uses
[`toupper()`](https://rdrr.io/r/base/chartr.html), whose result for
non-ASCII letters depends on the locale.

Names: a `display_name` with a comma is read as `Surname, Given names`.
Otherwise an entry of `authors$display_name_alternatives` in that form
that agrees with the name gives the surname, so a surname of several
words such as "Garcia Lopez" stays whole;
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
keeps the names of the file there. Else initials at the end of the name
(single letters, or capitals with periods, as in "Chen W." from
[`sm_read_scopus()`](https://cttir.github.io/scimapR/dev/reference/sm_read_scopus.md))
follow the surname, and otherwise the last word is the surname, together
with the lower-case particles before it ("Anna van der Berg" gives
`VAN DER BERG A`). Particles never become initials. Without such a
spelling, a surname of several words without particles ("Maria Garcia
Lopez") keeps only its last word, and a name such as "SMITH JA" is read
as given names followed by the surname. The given names of `AF` are the
longest spelling at hand, the initials of `AU` the shortest. Corpora
read by
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
store the `AU` form of a name (such as "J Smith"), so their `AF` holds
initials.

`CR` items are written in the Web of Science form
`SURNAME INITIALS, YEAR, SOURCE, ...`: an item `Surname, IN, YEAR, ...`
(with a comma after the surname, as some exports write it) becomes
`SURNAME IN, YEAR, ...`. Other items, such as titles or OpenAlex IDs,
are only upper-cased. Because `;` separates the items of `AU`, `AF`,
`C1`, `RP`, `CR`, `DE`, `ID`, `WC` and `SC`, a `;` inside an item
becomes `,`.

`DE` holds the author keywords of each work: the concepts of the
`author_keyword` family of
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md)
(`author-keywords`, `manual-tags`). A work without author keywords gets
its OpenAlex concepts (`openalex`) instead, so corpora built from
OpenAlex keep their `DE`; other vocabularies (Keywords Plus, MeSH,
categories, arXiv and bioRxiv subjects) never enter `DE`. A work with
neither has `DE = NA`.

`DB`: with `db = "auto"`, a corpus whose works all come from Web of
Science (each has a provenance row with `source == "wos"`, or a
`work_id` that starts with `WOS:`) gets `"ISI"`, the value
[`bibliometrix::convert2df()`](https://rdrr.io/pkg/bibliometrix/man/convert2df.html)
writes for Web of Science files, so that
[`bibliometrix::histNetwork()`](https://rdrr.io/pkg/bibliometrix/man/histNetwork.html)
and
[`bibliometrix::rpys()`](https://rdrr.io/pkg/bibliometrix/man/rpys.html)
accept it. Other corpora get `"scimapR"`, because bibliometrix reads
`"ISI"` data as Web of Science records; `db = "ISI"` declares a corpus
whose `CR` items are in Web of Science form anyway.

`RP` follows `authorships$is_corresponding`: it names the authors
flagged `TRUE` and is `NA` for a work without one.
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
takes the corresponding authors from the RP field of the file,
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/dev/reference/sm_read_openalex_json.md)
and
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md)
from the OpenAlex records,
[`sm_read_dimensions()`](https://cttir.github.io/scimapR/dev/reference/sm_read_dimensions.md)
from the Corresponding Authors column,
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_biorxiv.md)
from the bioRxiv API and
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md)
from `RP`. The other readers and fetchers record the corresponding
author as unknown (`NA`), so their corpora export `RP = NA`. Corpora
built from tables keep the flags of their tables.

[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md)
reads the result back: the round trip keeps the works, their DOIs and
years, the authors of each work, their addresses and the corresponding
authors.

## References

Aria, M. & Cuccurullo, C. (2017). bibliometrix: An R-tool for
comprehensive science mapping analysis. *Journal of Informetrics*,
11(4), 959-975.
[doi:10.1016/j.joi.2017.08.007](https://doi.org/10.1016/j.joi.2017.08.007)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10, n_authors = 5,
                            with_embeddings = FALSE)
M <- sm_to_bibliometrix(corpus, keep_extra = FALSE)
class(M)
#> [1] "bibliometrixDB" "data.frame"    
M[1:3, c("AU", "PY", "SO", "DB")]
#>                                                                      AU   PY
#> ZHANG M, 2023, PLOS ONE   ZHANG M;PETROVA D;SMITH C;JOHNSON H;FISCHER R 2023
#> JOHNSON H, 2019, PNAS                         JOHNSON H;SMITH C;ZHANG M 2019
#> FISCHER R, 2018, PLOS ONE           FISCHER R;SMITH C;ZHANG M;JOHNSON H 2018
#>                                 SO      DB
#> ZHANG M, 2023, PLOS ONE   PLOS ONE scimapR
#> JOHNSON H, 2019, PNAS         PNAS scimapR
#> FISCHER R, 2018, PLOS ONE PLOS ONE scimapR

# a corpus from Web of Science records
fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
M <- sm_to_bibliometrix(fix)
unique(M$DB)
#> [1] "ISI"
M$C1[1]
#> [1] "[VAHRENKAMP, SVENJA] ZENT INST SANITATSWESENS NORDSTADT, DEPT OCCUPAT MED, D-99003 NORDSTADT, GERMANY.; [HOEKSTRA, PRIYA] LAKESIDE UNIV, DEPT EPIDEMIOL, LAKESIDE, MA 02999 USA.; [PIEPER, CLARA; NOLTING, MATTHIAS; LUTTERBECK, MARIE] ZENT INST SANITATSWESENS NORDSTADT, DEPT HYG, D-99003 NORDSTADT, GERMANY.; [ENGELKE, CLARA] FED ARMED FORCES INST MICROBIOL, DEPT VIROL, D-99002 SOUTHCITY, GERMANY.; [ENGELKE, CLARA] UNIV NORTHTOWN, DEPT MICROBIOL, NORTHTOWN, GERMANY.; [PETROVIC, HANNAH] SOUTHCITY MED SCH, DEPT INFECT DIS, D-99012 SOUTHCITY, GERMANY."
# \donttest{
if (requireNamespace("bibliometrix", quietly = TRUE)) {
  results <- bibliometrix::biblioAnalysis(M, sep = ";")
}
# }
```

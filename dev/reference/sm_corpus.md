# Create an sm_corpus object

Build a typed, tibble-of-tibbles corpus container for bibliometric
analysis. The corpus is the central data structure in scimapR, holding
works, authors, authorships, institutions, sources, references,
concepts, embeddings, provenance, screening decisions, and metadata.

## Usage

``` r
sm_corpus(
  works,
  authors = NULL,
  authorships = NULL,
  institutions = NULL,
  sources = NULL,
  references = NULL,
  concepts = NULL,
  embeddings = NULL,
  provenance = NULL,
  screening = NULL,
  metadata = list()
)

# S3 method for class 'sm_corpus'
x[i, ...]

# S3 method for class 'sm_corpus'
length(x)

# S3 method for class 'sm_corpus'
dim(x)

# S3 method for class 'sm_corpus'
as_tibble(x, ...)

# S3 method for class 'sm_corpus'
as.data.frame(x, ...)

# S3 method for class 'sm_corpus'
print(x, ...)

# S3 method for class 'sm_corpus'
format(x, ...)

# S3 method for class 'sm_corpus'
summary(object, ...)

# S3 method for class 'sm_corpus'
str(object, ...)
```

## Arguments

- works:

  A tibble of works (publications). See Details for schema.

- authors:

  A tibble of authors. If `NULL`, constructed from `works`.

- authorships:

  A tibble linking works to authors. If `NULL`, empty.

- institutions:

  A tibble of institutions. If `NULL`, empty.

- sources:

  A tibble of publication sources/journals. If `NULL`, empty.

- references:

  A tibble of cited references. If `NULL`, empty.

- concepts:

  A tibble of concepts/keywords. If `NULL`, empty. Legacy and common
  spellings in its `vocabulary` column (such as `"keywords-author"`) are
  renamed to the names of
  [`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
  with a message. Values that name no known vocabulary are kept as
  written and listed in the same message, each time a corpus is built
  from them; name a vocabulary of your own `"custom"`.

- embeddings:

  A numeric matrix of work embeddings, or `NULL`.

- provenance:

  A tibble tracking data lineage. If `NULL`, empty.

- screening:

  A tibble of screening decisions. If `NULL`, empty.

- metadata:

  A list of corpus-level metadata.

- x, object:

  An `sm_corpus` object.

- i:

  Row index for subsetting.

- ...:

  Ignored.

## Value

An `sm_corpus` S3 object.

- `[`: An `sm_corpus` with the selected works.

- [`length()`](https://rdrr.io/r/base/length.html): Number of works
  (integer).

- [`dim()`](https://rdrr.io/r/base/dim.html): Integer vector of length 2
  (rows, columns of works table).

&nbsp;

- `as_tibble()`: The works tibble.

- [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html): The
  works table as a data frame.

&nbsp;

- [`print()`](https://rdrr.io/r/base/print.html): `x` invisibly.

- [`format()`](https://rdrr.io/r/base/format.html): A single character
  string.

- [`summary()`](https://rdrr.io/r/base/summary.html): A named list of
  summary statistics.

- [`str()`](https://rdrr.io/r/utils/str.html): `object` invisibly.

## Details

A corpus is a list of tables that share identifiers: `work_id` links
every table to `works`, `author_id` links `authorships` to `authors`,
`institution_id` links them to `institutions` and `source_id` links
`works` to `sources`. The tables below list, for each element, the
required columns, which the readers and fetchers always write (a value
may be `NA`), and the optional columns that some readers and functions
write or read. `sm_corpus()` adds the missing required columns of
`works` (mostly `NA`); it takes the other tables as given.

**`works`**: one row per work. Required:

|  |  |  |
|----|----|----|
| Column | Type | Content |
| `work_id` | character | Identifier, unique within the corpus |
| `doi` | character | DOI, lower case, without `https://doi.org/` |
| `title`, `abstract` | character | Title and abstract |
| `year` | integer | Publication year |
| `type` | character | Document type, as the source names it |
| `source_id` | character | The journal or other source (`sources`) |
| `cited_by_count` | integer | Citations, as the source counts them |
| `oa_status` | character | Open-access status |
| `language` | character | Language |
| `pmid`, `arxiv_id`, `openalex_id` | character | Other identifiers |
| `is_retracted` | logical | Retraction flag |
| `retraction_date` | Date | Date of the retraction |
| `last_refreshed` | POSIXct | When the record was read or fetched |

Optional: `quartile`, `jif_quartile` or `sjr_quartile` (journal
quartiles such as `"Q1"`, for `sm_its(outcome = "share_q1")`); `cnci`,
`fnci`, `rcr` and other impact columns (see
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md));
`field` (for `sm_metric_fnci(classification = "manual")`);
`citation_mature` and `cnci_provisional`
([`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md));
`cluster_id` and `cluster_label` (the clustering functions).

**`authors`**: one row per author. Required:

|  |  |  |
|----|----|----|
| Column | Type | Content |
| `author_id` | character | Identifier, unique within the corpus |
| `orcid` | character | ORCID iD |
| `display_name` | character | Name |
| `display_name_alternatives` | list of character | Other spellings |
| `inferred_gender`, `gender_method` | character | Gender and its method |
| `gender_confidence` | double | Confidence of `inferred_gender` |

`display_name_alternatives` holds, for example, the names as a Web of
Science file writes them, and `sm_audit_gender(method = "manual")` reads
the gender columns. Optional: none so far.

**`authorships`**: one row per work, author and affiliation, so an
author with several addresses in a work has several rows, which share
`position` and `is_corresponding`. Required:

|  |  |  |
|----|----|----|
| Column | Type | Content |
| `work_id`, `author_id` | character | The work and the author |
| `position` | integer | Place in the author list, from 1 (`NA`: unknown) |
| `is_corresponding` | logical | Corresponding author: see below |
| `institution_id` | character | The institution (`institutions`) |
| `raw_affiliation` | character | The address as the source writes it |
| `country_code` | character | ISO 3166-1 alpha-2 country code |

`is_corresponding` is `TRUE` for the authors the source names as
corresponding, `FALSE` for the other authors of such a work and `NA`
when the source does not say who the corresponding author is.
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
and
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md)
read it from the RP field,
[`sm_read_openalex_json()`](https://cttir.github.io/scimapR/dev/reference/sm_read_openalex_json.md)
and
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md)
from OpenAlex (a work whose authors are all marked `false` takes its
corresponding authors from `corresponding_author_ids`, and counts as
unknown when that lists none of them),
[`sm_read_dimensions()`](https://cttir.github.io/scimapR/dev/reference/sm_read_dimensions.md)
from its Corresponding Authors column and
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_biorxiv.md)
from the bioRxiv API; the other readers and fetchers write `NA`. Up to
scimapR 0.4.0 they flagged the first author instead. A name that fits
several authors of a work equally (namesakes with the same surname and
initials) and that the source does not tell apart leaves them `NA`.
Functions that select corresponding authors take `TRUE` only, and the
leadership outcome of
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
leaves works whose corresponding author is unknown out of its shares.

Optional: `institution_match`, `match_method`, `match_signal` and
`match_evidence`
([`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md));
`institution_name`
([`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md));
`email` (exported as `EM` by
[`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)).

**`institutions`**: one row per institution. Required:

|  |  |  |
|----|----|----|
| Column | Type | Content |
| `institution_id` | character | Identifier, as in `authorships` |
| `ror` | character | ROR id |
| `display_name` | character | Name |
| `country_code` | character | ISO 3166-1 alpha-2 country code |
| `region`, `income_tier` | character | World region and income group |
| `type` | character | Kind of institution, such as education or healthcare |

Optional: none so far.

**`sources`**: one row per journal or other source. Required:

|  |  |  |
|----|----|----|
| Column | Type | Content |
| `source_id` | character | Identifier, as in `works` |
| `issn_l` | character | Linking ISSN |
| `issn` | list of character | All ISSNs of the source |
| `display_name` | character | Name |
| `type` | character | Kind of source, such as journal |
| `is_oa` | logical | Open-access source |
| `publisher`, `publisher_country` | character | Publisher and its country |

Optional: `abbreviation` and `iso_abbreviation` (character; the Web of
Science abbreviations J9 and JI, written by
[`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
and the bibliometrix conversion and exported by
[`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)).

**`references`**: one row per cited reference. Required:

|                 |           |                                       |
|-----------------|-----------|---------------------------------------|
| Column          | Type      | Content                               |
| `work_id`       | character | The citing work                       |
| `ref_index`     | integer   | Place in the work's reference list    |
| `cited_work_id` | character | The cited work, when it is in `works` |
| `cited_doi`     | character | DOI of the cited work                 |
| `cited_raw`     | character | The reference as the source writes it |

Optional: none so far.

**`concepts`**: one row per keyword, category or concept of a work.
Required:

|  |  |  |
|----|----|----|
| Column | Type | Content |
| `work_id` | character | The work |
| `concept_id` | character | Identifier in its vocabulary |
| `concept_name` | character | The keyword, category or concept |
| `level` | integer | Level in the hierarchy of the vocabulary |
| `score` | double | Weight given by the source |
| `vocabulary` | character | One of [`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md) |

For MeSH headings `score` is 1 for a major topic and 0 otherwise.
Optional: none so far.

**`embeddings`**: `NULL` or a numeric matrix with one row per work,
named by `work_id`.

**`provenance`**: one row per work and source. Required:

|  |  |  |
|----|----|----|
| Column | Type | Content |
| `work_id` | character | The work |
| `source` | character | Where the record comes from, such as `"wos"` |
| `source_id_external` | character | Its identifier at the source |
| `fetch_date` | POSIXct | When it was read or fetched |
| `query` | character | The query or file it came from |
| `engine` | character | The parser or client that read it |
| `scimapR_version` | character | The scimapR version that read it |
| `prompt_hash` | character | Hash of a prompt behind the record |

`source_id_external` is, for example, the Web of Science accession
number (UT); `prompt_hash` is `NA` for records that no prompt produced.
Optional: none so far.

**`screening`**: one row per screening decision. Required:

|              |           |                                                    |
|--------------|-----------|----------------------------------------------------|
| Column       | Type      | Content                                            |
| `work_id`    | character | The work                                           |
| `stage`      | character | Stage, such as `"title-abstract"` or `"full-text"` |
| `decision`   | character | `"include"`, `"exclude"` or `"unclear"`            |
| `reason`     | character | Reason for the decision                            |
| `confidence` | double    | Confidence of the decision                         |
| `source`     | character | Who or what decided                                |
| `decided_at` | POSIXct   | When                                               |

Optional: none so far.

**`metadata`**: a list. Required:

|  |  |  |
|----|----|----|
| Entry | Type | Content |
| `scimapR_version` | character | The scimapR version that built the corpus |
| `build_date` | POSIXct | When the corpus was built |
| `corpus_hash` | character | Hash of the content ([`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md)) |
| `is_locked` | logical | Whether [`sm_lock()`](https://cttir.github.io/scimapR/dev/reference/sm_lock.md) locked the corpus |
| `last_refresh` | POSIXct | When [`sm_refresh()`](https://cttir.github.io/scimapR/dev/reference/sm_refresh.md) last ran |
| `question_id` | character | Id of its [`sm_question()`](https://cttir.github.io/scimapR/dev/reference/sm_question.md) |

`question_id` is set by
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_for_question.md).
Optional: entries the readers add, such as `source_file` and `reader`.
`build_date` and `last_refresh` may also be numbers of seconds since
1970-01-01 UTC, as corpora restored from tables store them, ISO 8601
text or dates;
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
and the citation-maturity cut-offs read all of these.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_build_corpus.md),
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/dev/reference/sm_dedupe.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/dev/reference/sm_materialise.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/dev/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- sm_corpus(
  works = tibble::tibble(
    work_id = "W000000001",
    doi = "10.1234/example",
    title = "Example Work",
    abstract = "An example abstract.",
    year = 2024L,
    type = "journal-article",
    source_id = NA_character_,
    cited_by_count = 0L,
    oa_status = "closed",
    language = "en",
    pmid = NA_character_,
    arxiv_id = NA_character_,
    openalex_id = NA_character_,
    is_retracted = FALSE,
    retraction_date = NA_real_,
    last_refreshed = Sys.time()
  )
)
print(corpus)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 1 | Authors: 0 | Institutions: 0
#> Years: 2024 - 2024
#> Sources (journals): 0
#> Embeddings: none
#> Status: Unlocked (last refreshed: never)
```

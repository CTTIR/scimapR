# scimapR (development version)

- New synthetic example files shaped like a Web of Science export of three
  invented military-medical units and their civilian partners:
  `example_realuse_corpus.rds` (150 works), `example_realuse_reference.csv`
  (a publication-tracker reference list) and
  `example_realuse_affiliation_dict.csv` (an affiliation dictionary). See
  the "Real-use fixture" section of `?sm_example_files`.
- The examples of `sm_audit_funding()` and `sm_audit_summary()` run
  offline: they no longer send one Crossref request per DOI of the example
  corpus when `R CMD check --as-cran` runs `\donttest{}` code. The live
  lookup is shown in an example that runs only in interactive sessions.
- `sm_audit_summary()` no longer sends web requests by default. Its new
  `online` argument controls the funding audit, which looks up every DOI on
  Crossref: with the default `online = FALSE` that audit is reported as not
  run unless a precomputed `sm_audit_funding()` result is passed, and
  `online = TRUE` runs it as before.
- `sm_certificate()`, `sm_cite_corpus()` and citation-maturity cut-offs
  (`sm_citation_maturity()`, `sm_its(outcome = "cnci")`) accept numeric,
  character, Date and POSIXct timestamps in `metadata$build_date` and
  `metadata$last_refresh`. Numbers are read as seconds since 1970-01-01 UTC,
  as corpora restored from tables store them, and implausible numbers (such
  as milliseconds) are ignored with a message. Text is read as ISO 8601 (a
  date, or a date and time with an optional `Z` or `+hh`, `+hhmm` or
  `+hh:mm` offset); other text counts as missing. Certificates write their
  timestamps in UTC, for example `2026-10-17T11:45:00Z`, still read the
  older form, and print the creation time in UTC.
- `sm_metric_fnci()` gains `min_cell` and `by_type` (opt-in fallback
  baselines) and informs when many works sit in tiny cells;
  `sm_its(outcome = "cnci")` and `sm_metric_summary(metric = "cnci")` show
  that message too. With `min_cell`, a work whose field-year cell is too
  small falls back to its field in the neighbouring years and then to its
  year, `field` may list several `;`-separated categories, and the result
  reports `n_cell` and `baseline`. `by_type = TRUE` gives articles and
  reviews baselines of their own.
- `sm_metric_fnci(classification = "manual")` reports a factor `field` by
  its labels instead of its integer codes.
- `sm_metric_fnci(classification = "mesh")` never uses a MeSH check tag
  (such as Humans, Female or Adult) or a descriptor of study design or
  statistics (such as Retrospective Studies, Risk Factors or Treatment
  Outcome) as a work's field. `sm_fetch_pubmed()`, `sm_read_pubmed_xml()`
  and `sm_enrich_concepts(source = "mesh")` now record each MeSH heading's
  major-topic flag as its concept `score` (1 for a major topic, 0
  otherwise; before, always `NA`), so the field is a major topic of the
  work. Headings without scores, as from other sources, give the work's
  heading that is most frequent in the corpus instead of the first one
  listed, with a message.
- `sm_cluster_evolution(link_by = "cluster_id")` follows a global clustering
  across windows; snapshots gain `share`. Each cluster present in two
  consecutive windows gives one transition, except the noise cluster named
  by the new `noise` argument (default `0L`).
- `sm_affiliation_match()` matches dictionary patterns in Unicode mode, so
  `\w` and `\b` work on non-ASCII names; new `sm_affiliation_unmatched()`
  lists unmatched affiliation strings. Unicode mode is the new default, for
  the postcode signal too: `\w`, `\b`, `\d`, `\s` and POSIX classes such as
  `[[:alpha:]]` now treat umlauts, accented letters and other non-ASCII
  letters, digits and spaces like ASCII ones. A pattern can stop matching
  if it used `\W`, `\S`, `\D` or `\B` to stand for a non-ASCII letter, or
  if it relied on `\b` between an ASCII and a non-ASCII letter: the shipped
  pattern `\bnato\b` no longer matches "NATO" directly followed by an
  umlaut. The new argument `unicode = FALSE` restores the earlier
  ASCII-only matching. `sm_attribute_institution()` has no such argument
  and matches in Unicode mode when it runs `sm_affiliation_match()` itself;
  the Details of `?sm_affiliation_match` show how to get its earlier
  results.
- `sm_screen_regex()` matches its terms as written, case-insensitively and
  in Unicode mode like `sm_affiliation_match()`, so a term can stop
  matching in the same ways (new argument `unicode`, default `TRUE`). It no
  longer lowercases the patterns, which turned `\W`, `\S`, `\D` and `\B`
  into `\w`, `\s`, `\d` and `\b`, and a corpus with a single work now gets
  one screening row instead of several.
- `sm_its()` no longer fails when a year has no finite outcome, `sm_did()`
  no longer fits silently on fewer years, and `sm_synth()` no longer passes
  such years to tidysynth; these years are dropped with a warning and
  reported (`dropped_years`). `sm_did()` drops them per group, and
  `sm_synth()` for every unit so that its panel stays balanced. For
  `outcome = "cnci"`, works with an infinite impact value are left out of
  the yearly mean, and a year without usable impact counts as dropped even
  when it is citation-immature, so `dropped_years` and `provisional_years`
  never share a year.
- The confidence intervals of `sm_its()` and `sm_did()` use the t
  distribution with the residual degrees of freedom when the model
  estimates its dispersion, as their p-values already did: the default
  Gaussian fits of `sm_did()` and of `sm_its()` for `"share_q1"`, `"cnci"`
  and `"leadership"`, and quasi families. These intervals are wider than
  before and agree with the p-values. Poisson fits (the `sm_its()` default
  for `"count"`) keep normal intervals and now warn when the counts are
  overdispersed, suggesting `family = "quasipoisson"`.
- With `outcome = "count"`, `sm_its()`, `sm_did()` and `sm_synth()` count a
  year without works as 0, over every year from the first to the last
  publication year of the corpus, instead of leaving the year out; filter
  the corpus to the analysis window first. `sm_synth()` aborts when a unit
  has no works.
- `sm_its()` checks the years that remain after all exclusions (years
  without a usable value and, for `"cnci"`, citation-immature years)
  instead of before the citation-immature cut. It needs at least 4 years, 2
  or more before `intervention_year` and 2 or more from it on, and aborts
  otherwise, or when a level or slope change cannot be estimated, instead
  of silently fitting a model without those terms. On exactly 4 years a
  Gaussian or quasi-family fit has no residual degrees of freedom, and
  `sm_its()` now warns that its standard errors, intervals and p-values
  are `NaN`. `sm_did()` needs 4 years per group, with years before and
  from `intervention_year`, and `sm_synth()` 4 panel years, 2 of them
  before it.
- `sm_its()`, `sm_did()` and `sm_synth()` check `intervention_year` the
  same way and abort unless it is one whole year, given as a number or as
  text such as `"2020"`. Before, `sm_did()` and `sm_synth()` truncated a
  year such as 2020.5 and read `TRUE` as the year 1, and all three read a
  factor or a date by its internal number.
- Concept vocabularies are now a controlled set (`sm_concept_vocabularies()`);
  `sm_to_bibliometrix()` DE and keyword co-word networks work for file-based
  corpora. `sm_corpus()` and `sm_corpus_from_tables()` rename legacy and
  common spellings such as `"keywords-author"`, `"keyword"` or `"MEDLINE"`
  to these names, with a message, and the functions that select concepts by
  vocabulary read every one of these spellings. Values that name no known
  vocabulary are kept as written and listed in the same message, so a
  corpus built from such tables now reports them each time; name a
  vocabulary of your own `"custom"`. DE holds each work's author keywords;
  a work without any falls back to its OpenAlex concepts, so corpora built
  from OpenAlex keep their DE, and arXiv and bioRxiv categories stay out of
  it as before. `sm_network_coword()` gains `vocabulary`:
  `field = "keywords"` uses the author keywords by default and, in a corpus
  without any, the indexer keywords (such as Keywords Plus or MeSH) with a
  message; a corpus with neither gives an empty network, now with a
  message. With `field = "concepts"`, `vocabulary` keeps only the
  vocabularies named.
- `sm_read_wos()` reads the Web of Science categories (WC) into the new
  vocabulary `wos-category`; `wos-subject-category` keeps the research areas
  (SC). Corpora read from Web of Science files therefore have more concept
  rows, which changes the results of functions that use every concept
  whatever its vocabulary: `sm_network_coword(field = "concepts")`,
  `sm_plot_thematic_map()`, `sm_author_trajectory()` and the corpus hash
  (`sm_hash_corpus()`). `sm_author_trajectory()` now counts a concept name
  once per work in its dominant topics and novelty (before, a name that a
  work had in two vocabularies counted twice), so a category with the same
  name as a research area of the work leaves the trajectory unchanged.
- `sm_to_bibliometrix()` exports C1, RP, ID, WC, SC, UT, SN/EI, J9/JI, EM,
  AF, one AU entry per author, CR in Web of Science form and `DB = "ISI"`
  for corpora from Web of Science, so `bibliometrix::histNetwork()` and
  `bibliometrix::rpys()` run; C1 round-trips through `as_sm_corpus()`.
  Every tag column is present, `NA` where the corpus has no data. New
  arguments: `keep_extra = FALSE` drops the columns without a field tag,
  and `db` sets `DB`. `sm_read_wos()` now reads the ISSNs and journal
  abbreviations (SN, EI, J9, JI) into `sources` (`issn_l`, `issn` and the
  new columns `abbreviation` and `iso_abbreviation`), so ISSN lookups now
  work for corpora read from Web of Science files. It also keeps each
  author name as the file writes it (such as "Garcia Lopez, M") in
  `authors$display_name_alternatives`, so the export keeps surnames of
  several words whole, and cited-reference DOIs lose a trailing period.
  Because of these changes the corpus hash (`sm_hash_corpus()`) of corpora
  read from Web of Science files changes too.
- `sm_to_bibliometrix()` now upper-cases the text fields that bibliometrix
  keeps upper-case (as `convert2df()` does); `DI` stays as stored. Its
  default output changes in a few more ways: `AU` holds names as
  `SURNAME INITIALS` (such as `VALDEZ P`) instead of the stored display
  names, `SR` is built as `convert2df()` builds it (first author, year and
  journal abbreviation, made unique) and gives the row names, `NR` counts
  the items of `CR` instead of the reference rows, `DE` separates its terms
  with `; `, and the tag columns come first. `AU_CO` is no longer written,
  so bibliometrix reads the countries from `C1`
  (`bibliometrix::metaTagExtraction(M, "AU_CO")`) as it does for
  `convert2df()` data. With the default `keep_extra = TRUE` the other
  columns stay, and the ISO country codes that `AU_CO` held are in the new
  column `country_code`.
- The `"bibliometrix"` and `"auto"` engines of the file readers and
  `as_sm_corpus()` for bibliometrix data frames now share one conversion,
  which also reads the cited references (CR, with the DOI of each reference
  that has one), the sources (SO, SN, EI, J9, JI), the keywords and
  categories (DE, ID, WC, SC), the Web of Science accession numbers (UT)
  and the PubMed IDs; before, these corpora had no references, sources or
  concepts. Authors keep their full names from AF and get one authorship
  row per address, linked through the names in C1, and titles and
  abstracts keep the case of the file. Authors are now told apart by
  their full names in AF instead of their AU form, so author counts can
  change; an entry with initials only, or without AF, belongs to the
  author with the same surname and initials when there is just one.
  `as_sm_corpus()` labels the provenance of Web of Science data
  (`DB = "ISI"`) `"wos"`.

- `sm_coverage_audit(by =)` accepts any reference or works column;
  corpus-side affiliation uses institution matches before country codes.
  A name is either one of the named dimensions `"year"`, `"source"` and
  `"affiliation"` or a column of the reference data frame (matched
  case-insensitively) or of `works`; a dimension found on one side only
  gets `NA` for the other side, and a name found on neither side is an
  error listing the available columns. The affiliation levels of a corpus
  come from the first of `institution_match`, `institution_name`,
  `institution_id` and `country_code` that has a value, with a message
  naming the column on each side and a warning when a side falls back to
  country codes. A work counts in every institution of its authors, so
  per-level counts can add up to more than the total; the overall recall
  and precision count each record once. In a data-frame reference,
  `"affiliation"` now takes an `affiliation`, `affiliations` or
  `institution` column before a `country` or `country_code` column, and
  `"source"` a source name before `source_id`, whatever their order, and
  the values of each row stay with that row.
- `sm_coverage_audit()` and `sm_reconcile()` identify the rows of a data
  frame by its `UT` column (Web of Science accession numbers) or an `id`,
  `work_id`, `reference_id` or `ref_id` column only when its values are
  unique and none is missing; otherwise rows are identified by their
  position (`R000001`, ...), with a warning. A column named `ID` next to
  Web of Science field tags holds the Keywords Plus and is never used.
  Before, missing or repeated identifiers, such as those of the `ID` column
  that `sm_to_bibliometrix()` writes, made the recall, the breakdowns,
  `n_reference_only` and `matches$reference_id` disagree.
- `sm_coverage_audit()` looks up each reference row on its own for recall,
  so an item that two rows report (one paper reported by two units) counts
  as found for both instead of only for the first; precision still pairs
  each corpus record with at most one reference row. `n_matched` counts the
  reference rows found and the new element `n_corpus_matched` the corpus
  records paired, which `print()` shows for precision and `summary()` adds
  as its last column; the two differ only when reference rows share a
  corpus record. The new element `reference_matches` shows for each
  reference row the corpus record it was found in, as `matches` does for
  the corpus records. When a DOI repeats on both sides, its records now
  pair in order instead of leaving the later ones to the title fallback.
- The title fallback of `sm_coverage_audit()` and `sm_reconcile()` pairs
  two records only when their publication years differ by at most one
  (or a year is missing) and never when both have a DOI and the DOIs
  differ, so serial titles such as annual reports and generic titles such
  as "Editorial" no longer match across years. A `Date` or date-time year
  column of a data frame counts by its calendar year, and a year outside
  1000-2999 (such as a day count) as missing.
- Title matching in `sm_coverage_audit()` and `sm_reconcile()`, and the ROR
  lookup of `sm_attribute_institution()`, keep the letters and digits of
  every script when they normalise text. Before, they dropped every
  non-ASCII letter, so titles in Cyrillic, Greek or other non-Latin scripts
  never matched and words with umlauts or accents lost letters.
- `sm_count(level = "institution")` no longer applies the shipped
  dictionary `sm_affiliation_dict` on its own, which credited any
  "military hospital" or "army hospital" to "Bundeswehr Hospital". This
  changes its default counts: each authorship row now takes the first of
  `institution_match`, `institution_name` and `institution_id` (named by
  `corpus$institutions` when listed) that has a value in that row, and
  otherwise its raw affiliation string, with a warning. Before, one column
  served every row, so the rows without a value in it were left out, and
  `entity_id` was the `institution_id` whenever any row had one; now it is
  the label, except for rows labelled through `institution_id`. After
  `sm_attribute_institution()`, which keeps `institution_match`, the
  counts therefore follow the dictionary matches instead of their roll-up
  to ROR ids and names; to count by the vocabulary, replace
  `institution_match` by `institution_name` where that is set (see
  `?sm_count`). Run `sm_affiliation_match()` with a dictionary of your
  institutions first to count them.
- The shipped dictionary `sm_affiliation_dict` no longer credits a bare
  "military hospital", "army hospital" or "armed forces hospital", which
  can be a hospital of any country, to "Bundeswehr Hospital". Its rows for
  that hospital now need "Bundeswehr", "German Armed Forces", "German
  Army" or "German Military" before "hospital", or the German name, so
  `sm_affiliation_match()` with its default patterns, and
  `sm_attribute_institution()` on a corpus that was not matched first,
  leave other military hospitals unmatched; an English name with
  "Bundeswehr", such as "Bundeswehr Hospital", now matches as well.
- The WoS reader (both engines), the bibliometrix import and both OpenAlex
  readers take the corresponding author from the RP field or the OpenAlex
  `is_corresponding` flag instead of assuming the first author; the
  readers of sources without this information record it as unknown
  (`NA`). `sm_audit_geographic(weight = "corresponding")` and the gender
  audit now find corresponding authors (they used `isTRUE()` on a
  column). RP is read in any case, with the older "(reprint author)" and
  with its names on one line or several, in both engines; namesakes with
  the same surname and initials are told apart by the address RP gives,
  and stay unknown when it does not tell them apart. A work whose RP
  names none of its authors counts as unknown, and so does an OpenAlex
  work whose authors are all marked `false` unless its
  `corresponding_author_ids` lists one of them. This changes default
  results: `sm_read_lens()`, `sm_read_ris()`, `sm_read_scopus()`,
  `sm_read_bib()`, `sm_read_pubmed_xml()`, `sm_fetch_pubmed()`,
  `sm_fetch_crossref()` and the other readers and fetchers without
  corresponding-author data now give `NA` instead of `TRUE` for the first
  author, so `sm_to_bibliometrix()` exports `RP = NA` for their corpora,
  and `sm_audit_geographic(weight = "corresponding")` reports the
  countries of the corresponding authors instead of an empty table with
  coverage 0.
- Leadership outcomes can be restricted to focal institutions and author
  roles (`institutions`, `lead_role`; `institution_aware` in `sm_did()` and
  `sm_synth()`); works with an unknown corresponding author, and works
  without any authorship rows (before counted as not led), leave the
  default leadership denominator. A work counts as led when an authorship
  in the role (`"corresponding"`, `"first"`, `"last"`, `"first_or_last"` or
  `"any_lead"`) carries one of the institution labels in
  `institution_match`, `institution_name` or `institution_id`, or the name
  of that id in `corpus$institutions`; a label that no authorship carries
  gives a warning naming the nearest labels. The denominator change
  applies to `sm_its()`, `sm_did()` and `sm_synth()` alike and changes
  their default `"leadership"` results for corpora with unknown
  corresponding authors, which now include most corpora from readers
  other than the WoS and OpenAlex readers: a year without a known
  corresponding author is dropped with a warning, and when no work has
  one the functions abort and suggest `lead_role = "first"` or `"last"`
  with focal institutions. The print methods state the definition used,
  which the results keep in `leadership`.
- `sm_read_wos()` links the addresses of C1 to the authors by their whole
  names, as the bibliometrix engine does: the full name of AF, else the
  surname and initials, else the surname and first initial. It now writes
  one authorship row per author and address. Before, it gave each author
  the first C1 line whose bracket contained the author's surname anywhere,
  so a short surname such as "He" or "Li" took the address of "Chen" or
  "Lin", an author with several addresses kept only the first, and lines
  without names linked nobody. In both engines and in `as_sm_corpus()`,
  an address that C1 lists without names, as older records do, now
  belongs to every author of the record, and the bibliometrix engine keeps
  such a line apart from the address before it. Authorship rows,
  address-based counts and the corpus hash of corpora read from Web of
  Science files change.
- `sm_fetch_biorxiv()` takes the corresponding author from the
  `author_corresponding` field of the bioRxiv API, and
  `sm_read_dimensions()` from a Corresponding Authors column, matching the
  names to the authors by surname and given names or initials; a name
  that fits two authors equally leaves both unknown.
  `sm_fetch_orcid()` records the ORCID holder's `position` and
  corresponding-author flag as unknown (`NA`); before, the holder was
  first and corresponding author of every work, which counted as first
  authorship in the geographic and gender audits.
- `sm_did()` reports the works that belong to both the treated and the
  control group, such as works co-authored by both, which pull the two
  series together and the estimate toward 0: with a warning when the new
  argument `shared` is not set, and in the new element `shared_works`.
  `shared = "exclude"` leaves them out of both series and `"lead"` gives
  each to the group of its lead author (`lead_role`); the default
  `"keep"` keeps them in both, as before. `sm_did()` aborts when `treated`
  and `control` share a label. `sm_did()` and `sm_synth()` gain `lag` and,
  for `outcome = "cnci"`, now leave out the citation-immature years as
  `sm_its()` does and list them in `provisional_years`, which changes
  their default `"cnci"` results.
- `sm_attribute_institution()` keeps the `institution_id` and
  `institution_name` of the authorships it does not match, such as the
  OpenAlex institution ids of a fetched corpus. Before, it set them to
  `NA`, so institution counts, the institution h-index and the regional
  audit lost every institution outside the vocabulary.
- `sm_summary_authors()`, `sm_summary_period()` and the position breakdown
  of `sm_audit_gender()` count each author once per work, however many
  address rows the author has in it, as `sm_metric_collab_index()` does.
  Before, an author with two address rows counted twice, so a
  single-author work did not count as single-authored and the authors per
  work disagreed with `sm_metric_collab_index()`.
- OpenAlex fetches and `sm_read_openalex_json()` keep FWCI, citation
  percentiles and yearly citation counts (new corpus element
  `citations_by_year`); new `sm_enrich_openalex_impact()` adds them to any
  corpus by identifier and stops cleanly on HTTP 429; new
  `sm_citation_window()`. The works gain the columns `fwci`,
  `citation_percentile`, `is_top_10pct`, `is_top_1pct` and
  `citations_as_of` (the date of these values); the openalexR engine has
  no percentile. `sm_fetch_openalex()` now stops with the same message on
  HTTP 429, naming the reset time, the remaining budget and the
  `OPENALEX_API_KEY` setting, instead of a generic error (native engine) or
  an empty corpus (openalexR engine), and its openalexR engine now uses
  `OPENALEX_API_KEY` too and needs openalexR 3.1.1 or later.
  `sm_enrich_openalex_impact()` sends identifiers only, joins nothing when
  a request fails, and records its step in provenance with the source
  `"openalex_impact"` and the kind `"enrichment"`, which
  `sm_rebuild_from_cert()` never replays; certificates record the kind of
  each step. `sm_corpus()`, `sm_corpus_from_tables()`, subsetting,
  `sm_bind_corpora()`, `sm_dedupe()`, `sm_export_csv()`, `sm_validate()`
  and `sm_hash_corpus()` carry `citations_by_year`; corpora without it keep
  their hash.
- `sm_metric_summary(metric = "cnci")` resolves impact like `sm_its()` and
  reports its source as an attribute; both now use `works$fwci` when
  `works$cnci` is absent (ahead of other impact columns and
  `corpus$metrics`), which changes `sm_its()`, `sm_did()` and `sm_synth()`
  results with `outcome = "cnci"` for such corpora. The attribute
  `impact_source` is `NA` on the `n = 0` row, which a corpus without usable
  impact data still gives; a message names the source for `"cnci"` and the
  new `metric = "fwci"`, and the results of `sm_its()`, `sm_did()` and
  `sm_synth()` keep it as `impact_source` and print it. `sm_its()`,
  `sm_did()`, `sm_synth()` and `sm_metric_summary()` gain `min_cell`,
  passed to `sm_metric_fnci()` when they derive impact from citation
  counts (default `NULL`, as before). The error for a corpus without impact
  data has the class `scimapR_no_impact_data`.
- `sm_fetch_openalex()` and `sm_read_openalex_json()` fill
  `authorships$raw_affiliation` from OpenAlex's `raw_affiliation_strings`
  (joined with `"; "`), else from `affiliations[].raw_affiliation_string`,
  else from the institution names. Before, `sm_fetch_openalex()` read a
  field OpenAlex no longer has, so `raw_affiliation` was `NA` for every
  fetched authorship and `sm_affiliation_match()` matched nothing, and
  `sm_read_openalex_json()` kept only the name of the first institution,
  without the department and unit text that dictionaries match.
- `sm_read_openalex_json()` links works to their source (`works$source_id`).
  Before, it was `NA` for every work, so source counts, the source plots
  and h-index, ISSN lookups in `sm_coverage_audit()` and `SO` in
  `sm_to_bibliometrix()` came out empty. Sources with the same name but
  different OpenAlex ids now stay apart.
- `sm_read_openalex_json()` reads a saved API response (an object whose
  `results` hold the works, compact or pretty-printed), a single work
  object and newline-delimited files whose lines are responses; before, a
  saved response gave one empty work or a parse error. It also reads
  abstracts from `abstract_inverted_index` when a record has no plain
  `abstract`; before, such a record stopped the reader with an error.
- `sm_fetch_openalex()` stores ORCIDs without the `https://orcid.org/`
  prefix, as the other readers do, and `sm_author_trajectory(orcid =)`
  accepts an ORCID in either form, so `sm_researcher_profile()` finds its
  researcher; before, it aborted with "No author found with ORCID" for
  every researcher with 5 or more works. `sm_researcher_profile()` gains
  `n_max` (default 200, as before).
- Timestamps given as ISO 8601 text with more than three decimals of a
  second, such as `2026-10-01T04:12:33.123456` (the form of OpenAlex's
  `updated_date`), are read, for example in `metadata$last_refresh`;
  before, they counted as missing.
- `sm_embed_works()` with the default model `specter2` loads the SPECTER2
  adapter through the Python `adapters` package as the model card
  describes; it previously failed in `SentenceTransformer()`. This model
  needs the Python packages `torch`, `transformers` and `adapters`
  (`install_deps = TRUE` installs `torch` and `adapters`), the other models
  need `sentence-transformers` as before, and the error for a missing
  package names it. A model that does not load now stops with an error
  that names the model and gives the Python error.
- `sm_embed_works()` gains multilingual models (`multilingual-mpnet`,
  `multilingual-e5`), informs when an English-only model meets a
  multilingual corpus, warns about works without text, and records the
  model in the corpus metadata and certificate. Texts for
  `multilingual-e5` start with `"query: "`, the prefix its model card gives
  for clustering. The message appears when more than 10% of the works with
  a known language are not in English; it reads language names such as
  `"German"`, ISO 639-1 codes such as `"de"` and ISO 639-2 codes such as
  `"ger"`. `corpus$metadata$embedding` records the model, its Hugging Face
  id and snapshot revision, the text and prefix used, the versions of the
  Python packages and the time (see `?sm_corpus`). `sm_certificate()`
  reports them in `embedding_info`, whose `method` now names the package or
  service that made the embeddings, or is `"unknown"` for embeddings
  without such a record (before: `"recorded"`).
- `sm_embed_works()` leaves works without text out of the embeddings, with
  a warning giving their number: with the default `text = "title_abstract"`
  the works with neither a title nor an abstract, with `"title"` or
  `"abstract"` the works without that field (blank text counts as none).
  Before, they were all embedded as the same empty text, so they became
  each other's nearest neighbours, formed a cluster of their own and
  stopped `sm_plot_landscape(reducer = "tsne")`. The row names of
  `corpus$embeddings` are the embedded works, and the clustering functions
  give the other works no cluster (`NA`), as they do for works missing from
  a cache loaded with `sm_embed_load()`.
- `sm_embed_works()` works on a corpus with a single work; before, it
  failed with "length of 'dimnames' [1] not equal to array extent".
- `sm_enrich_specter()` fetches the SPECTER v2 vectors of Semantic Scholar
  instead of the API's default SPECTER v1 and records them in
  `metadata$embedding`. It fills gaps only in embeddings from the same
  source: for embeddings of another model, or of a model that is not
  recorded, it stops unless you set `replace = TRUE` (replace them by
  SPECTER v2 vectors for every work with a DOI) or `mix_models = TRUE`
  (keep them and add SPECTER v2 vectors for the other works, recorded as a
  mix). Before, it silently mixed the vectors of two models when their
  widths matched, and discarded every existing embedding, with only a
  warning, when they did not. It now warns about failed requests also with
  `verbose = FALSE`, tries a request once more after a short wait when
  Semantic Scholar answers HTTP 429, and records its provenance rows as an
  enrichment, which `sm_rebuild_from_cert()` does not replay.
- `sm_bind_corpora()` and `sm_build_corpus()` gain `mix_models`. They stop
  when the embeddings of two corpora record different models in
  `metadata$embedding`, or when only one of them records its model, unless
  `mix_models = TRUE`, which binds them and records a mix; embeddings of
  corpora that record no model bind as before. `sm_embed_save()` keeps the record with the cache and
  `sm_embed_load()` restores it, or leaves the model unrecorded for a cache
  without one, and `sm_fetch_semantic_scholar(include_embeddings = TRUE)`
  records its SPECTER v1 vectors.
- Certificates record local input files with SHA-256
  (`sm_register_input()`, `sm_corpus_from_tables(inputs =)`);
  `sm_verify_certificate()` checks them (`base_dir`), reports a `status` per
  check and warns about inputs it could not find; `sm_rebuild_from_cert()`
  names the local inputs it cannot replay. The `checks` of a verification
  gain the columns `status` (`"pass"`, `"fail"` or `"not checked"`) and
  `location`, and the result gains `n_not_checked`: a check that was not
  made has `pass = NA`, and the overall result passes unless a check
  failed. A relative input path is looked for in `base_dir`, in the folder
  of the certificate file, in the working directory and last at the
  absolute path recorded at registration. Printing a verification now shows
  a symbol for each check, and printing a certificate the number of local
  inputs. `sm_bind_corpora()` keeps the local inputs of both corpora.
- `sm_rebuild_from_cert()` replays only the searches of OpenAlex, PubMed and
  Crossref, through `sm_fetch_openalex()`, `sm_fetch_pubmed()` or
  `sm_fetch_crossref()` with the engine, filter and `n_max` they were made
  with. Before, it cut every search at 1,000 works and sent the file paths
  of file reads and the placeholder queries of enrichments to the APIs as
  search text. `sm_fetch_openalex()`, `sm_fetch_pubmed()`,
  `sm_fetch_crossref()` and `sm_corpus_for_question()` now record `kind`,
  `filter` and `n_max` in provenance, and `sm_corpus_for_question()`
  records the client package that ran each search (`"openalexR"`,
  `"rentrez"` or `"rcrossref"`) as its `engine` instead of `"native"`, and
  for Crossref an `n_max` of at most 1,000, the most its single request
  returns; the file readers record the kind `"file"` and the file relative
  to the working directory, or its name, instead of the path as given; the
  enrichers record the kind `"enrichment"`; and certificates write file
  steps without absolute paths. A message names the steps and local inputs
  that were not replayed. When a certificate has no search to replay but
  records file reads or local inputs, the rebuild stops with an error that
  names them instead of returning an empty corpus; a certificate of only
  synthetic records, enrichments, refreshes or searches of other sources
  still gives an empty corpus. A search without a recorded `n_max`, as in
  certificates of earlier versions, fetches up to the number of works of
  the certified corpus. The rebuilt corpus holds the works of the searches
  and their provenance only.
- `sm_hash_corpus()` no longer depends on the order of the columns of a
  table or of the rows of the embeddings (hash version 2; new argument
  `version`), so hashes of new certificates and snapshots differ from
  earlier ones for the same content. Certificates and snapshots record
  `hash_version`, and those written without it are checked with the earlier
  algorithm (`version = 1`), so they stay verifiable. The documentation now
  says that the hash leaves out the provenance table, which records fetch
  dates, and the metadata, the local inputs included.

# scimapR 0.4.0

Stability contracts, an enrichment materializer, and self-citation-corrected
metrics, plus a verify-and-harden pass on three v0.3.0 fixes that recurred in
heavy use. All new behaviour is opt-in; no breaking changes.

## Accessor stability contract (A1)

- New `?scimapR-stability` topic documents the package's accessor return-type
  contract: a documented accessor's column set changes only via a `lifecycle`
  deprecation and a `NEWS.md` entry. The audited accessors and their stable
  shapes are listed there.
- `sm_coverage_breakdowns()` gains `tidy = TRUE` (default): a guaranteed long
  tibble (`dimension`, `level`, `n_reference`, `n_matched`, `recall`,
  `n_corpus`, `precision`, `f1`). `tidy = FALSE` returns the legacy recall-only
  shape. (The silent list -> tibble change between 0.2.0 and 0.3.0 motivated
  this contract.)

## Controlled vocabularies (B1)

- Exported `sm_affiliation_signals()`, `sm_affiliation_methods()`, and
  `sm_match_types()` (with `describe = TRUE` for level + description). The
  `match_signal`, `match_method`, and coverage `match_type` columns are now
  factors with these exact levels, so downstream filtering cannot drift.

## Verify-and-harden (re-reported v0.3.0 fixes)

These were reported again on a real corpus; each now has a regression test
reproducing the recurrence.

- **C1** `sm_its(outcome = "cnci")`: the resolver now also searches documented
  impact *side columns* on `works` (`fnci`, `rcr`, `ncs`, `mncs`,
  `field_citation_ratio`) and a `corpus$metrics` table, in addition to
  `works$cnci` and `works$cited_by_count`. With no impact anywhere it errors
  naming every column inspected. (v0.3 only checked `works$cnci` /
  `cited_by_count`, so impact in a side column still produced "0 observations".)
- **C2** `sm_count(level = "institution")`: when structured IDs are absent it
  now *clusters* `raw_affiliation` via `sm_affiliation_match()` (canonical names
  where matched, raw string otherwise) with a warning, instead of counting raw
  strings verbatim. Absent raw affiliation -> 0-row tibble + warning.
- **C3** network plot `precompute = TRUE` confirmed; the `max_nodes` cap is now
  **opt-in** (`NULL` default) so large renders are unchanged unless a cap is
  requested. A ~2,000-node graph builds with `precompute = TRUE` and re-prints
  without recomputing layout.

## Enrichment materializer (D1)

- `sm_materialise(corpus, sources, .by = NULL, overwrite = FALSE)` joins cached
  enrichment (named list of tibbles / RDS / parquet paths, or a cache dir) into
  the matching sub-tibbles by key, returning a validated `sm_corpus`. Missing
  keys warn (not error); overlapping columns fill `NA` unless `overwrite = TRUE`.
- Added an internal type-safe row-bind helper (`.sm_bind_rows`) that returns a
  typed template instead of a logical-column degenerate when all parts are
  `NULL`/empty; audited the package's existing `bind_rows()` sites (found safe,
  guarded behind length checks with typed tibbles).

## Self-citation-corrected metrics (E1, E2, F1)

- `sm_self_citation(corpus, level = c("author", "institution"))` computes
  self-citation from the corpus reference network (quota-light reference
  overlap; no per-citation API calls), returning `by_entity`, `by_work`, and a
  **provenance** tibble (`citing_work_id`, `cited_work_id`,
  `shared_author_id`/`shared_institution_id`) (F1). Empty references ->
  warning + typed empty result (no spin).
- `sm_metric_h_index()`, `sm_metric_g_index()`, `sm_metric_m_index()` gain
  `self_corrected = FALSE`; with `TRUE` the index is recomputed after removing
  self-citations (author/institution levels). The corrected index is always
  `<=` the uncorrected one.

## Provenance (F2)

- `sm_affiliation_summary()` now includes `example_evidence` (a representative
  matched-evidence string per institution x signal) alongside the factorised
  `match_signal`, so a reader can see which signal matched and on what evidence.

## Fixtures

- `inst/extdata/example_self_citation_corpus.rds`: a small references-bearing
  synthetic corpus for self-citation examples/tests.

# scimapR 0.3.0

Real-use refinements from running v0.2.0 on a ~6,853-work corpus: robustness
fixes, friendlier API shapes, two new capabilities, and vignettes that ship in
the installed binary. The public API is preserved (deprecation paths only).

## Bug fixes

- **A1** `sm_its(outcome = "cnci")` no longer fails with a cryptic "Too few
  yearly observations: 0" when impact lives outside `cited_by_count`. The
  resolver now searches, in order, `works$cnci`, a `corpus$metrics` table, then
  `works$cited_by_count` (deriving FNCI); if none is populated it raises an
  informative error naming the columns it inspected.
- **A2** `sm_count(level = "institution")` falls back to
  `authorships$raw_affiliation` (with a `cli` warning that results are
  un-disambiguated) when structured institution IDs are absent, and warns
  rather than returning a silent empty result when no institution data exists.
- **A3** `sm_metric_disruption()` and `sm_metric_novelty()` fast-exit with a
  warning when the reference network is empty/absent instead of spinning; the
  disruption index was rewritten with O(1) adjacency lookups (no longer
  O(n^2)) and now shows a `cli` progress bar. `sm_audit_summary()` shows a
  progress bar across its sub-audits.
- **A4** Network plots (`sm_plot_citation_network()`, `sm_plot_collab()`) gain
  `precompute = TRUE` (eager layout -> a self-contained plain `ggplot` that
  prints cheaply in knitr/`callr`/workflowr subprocesses) and a `max_nodes`
  cap (default 200) for very large graphs.

## Ergonomics

- **B1** `sm_coverage_audit()$breakdowns` is now a single flat tibble
  (`dimension`, `level`, `n_reference`, `n_matched`, `recall`). The previous
  nested list remains available under `$breakdowns_nested` for one release.
  New accessor `sm_coverage_breakdowns()` returns/filters the flat tibble.
- **B2** `sm_affiliation_match()` documents its added columns and gains
  `sm_affiliation_summary()` — a tidy works/authorships breakdown by
  institution and match signal, also surfaced as a `cli` summary on completion.
- **B3** `sm_corpus_from_tables()` is promoted in the ingestion vignette as the
  recommended "bring your own relational data" entry point.

## New capabilities

- **C1** `sm_coverage_audit(..., index_table = )` additionally assesses journal
  **indexability** (reusing `sm_journal_in_index()`), adding `issn`/`indexable`
  columns to `$matches` and an `$indexability` summary. Output is unchanged when
  `index_table` is `NULL`.
- **C2** `sm_affiliation_match()` returns `match_signal`
  (`name_token`/`email_domain`/`postcode`) and `match_evidence` (the matched
  substring/domain/code) for an audit trail, plus an opt-in
  `postcode_signal = TRUE` matcher (off by default so existing matches are
  stable).

## Packaging

- **D1** Vignettes now ship in the installed binary; browse them offline with
  `vignette(package = "scimapR")` / `browseVignettes("scimapR")`, or online at
  the pkgdown site. New `inst/extdata/` fixtures: `example_affiliation_postcode.csv`.

# scimapR 0.2.0

A new capability layer for research-coverage, affiliation-attribution, and
policy-evaluation analyses, plus four reproducible bug fixes. All existing
functionality, the `sm_corpus` schema, bibliometrix interop, and the Shiny app
are preserved.

## New features

### Coverage & completeness auditing

- `sm_coverage_audit()` computes recall, precision, and F1 of a corpus against
  a ground-truth reference (manual tracker, ORCID set, repository export, or
  another `sm_corpus`), with per-`year`/`source`/`affiliation` breakdowns and
  full match provenance. Returns an `sm_coverage` object with `print`,
  `summary`, and `autoplot` methods.
- `sm_journal_in_index()` verifies source coverage against a user-supplied
  journal master list by normalised ISSN (print and electronic), fully offline.
- `sm_reconcile()` performs a content-based symmetric diff (DOI then fuzzy
  title) returning an `sm_reconciliation` (`in_both`/`only_a`/`only_b` +
  provenance), with `print`/`summary`/`autoplot`. `sm_diff_corpora()` is now
  marked superseded in favour of it (and continues to work unchanged).

### Affiliation disambiguation & attribution

- `sm_affiliation_match()` tags authorships with institutions using a
  multilingual / synonym-aware dictionary and an email-domain fallback, handling
  multiple affiliations per author.
- `sm_attribute_institution()` rolls matches up to a controlled vocabulary
  (ROR-backed via an offline ROR table, or a custom vocabulary).
- `sm_affiliation_dict`: a default, documented, user-overridable dictionary.

### Causal / policy evaluation

- `sm_its()`: turnkey interrupted time series (level + slope terms,
  counterfactual, `autoplot`), with automatic exclusion of citation-immature
  years for citation-based outcomes.
- `sm_did()`: difference-in-differences for treated vs control institution sets.
- `sm_synth()`: synthetic-control helper (optional `tidysynth`, graceful error
  when absent).

### Correctness: citation maturity & counting

- `sm_citation_maturity()` flags citation-immature recent years
  (`citation_mature` / `cnci_provisional`), wired into `sm_its()`.
- `sm_count()`: full vs fractional counting at institution / author / source
  level (output credit and fractionally-weighted impact).

### Robust impact summaries

- `sm_metric_summary(robust = TRUE)` reports medians with bootstrap CIs and
  %PP(top-10%) alongside means (base-R resampling by default; `boot` optional;
  reproducible via `seed`).

### Reproducible reporting glue

- `sm_figure_manifest()` scans a figure directory into a captions / alt-text /
  dimensions manifest (optional `magick`/`png`, sidecar caption files, CSV/YAML
  output).
- `sm_corpus_from_tables()`: a documented, validating constructor from a
  relational set of data frames — the recommended ingestion path for arbitrary
  tabular sources.

## Bug fixes

- **G1** `sm_fetch_openalex(engine = "native")`: abstract reconstruction from the
  OpenAlex inverted index is now type-stable and never aborts a fetch on an
  empty/`NULL`/malformed record (and no longer passes an invalid `.default` to
  `purrr::map_chr()`).
- **G2** `sm_fetch_openalex(engine = "openalexR")`: long DOI (or other ID) lists
  are auto-batched under the API's OR-filter limit via the new `batch_size`
  argument, then row-bound and de-duplicated.
- **G3** `sm_read_bib(engine = "bibliometrix")`: a field-sparse `@article` no
  longer triggers "undefined columns selected"; the scimapR wrapper catches the
  failure and falls back to the native parser (clean-room rule preserved).
- **G4** native BibTeX engine performance: the parser was rewritten from
  per-character `substr()`/`grepl()` scanning and per-entry tibble construction
  to linear character-vector scanning with single-pass column assembly. Parsing
  ~7,000 entries dropped from ~100 s to ~17 s on R 4.5.2 / Windows.

## New data & fixtures

- `inst/extdata/`: `example_sparse.bib`, `example_openalex_inverted.json`,
  `example_journal_index.csv`, `example_ror.csv`.

# scimapR 0.1.0

## Initial release

`scimapR` is a comprehensive R toolkit for bibliometric and scientometric
analysis: the reproducible, equity-aware, question-driven, AI-assisted
toolkit for working biomedical researchers. Designed as a complement to
the foundational `bibliometrix` package (Aria & Cuccurullo, 2017) with
first-class round-trip interop.

### Distinctive features

- **Live corpus refresh.** `sm_refresh()`, `sm_staleness()`, `sm_lock()`.
- **Research questions as objects.** `sm_question()`,
  `sm_corpus_for_question()`, `sm_screen_against_question()` with optional
  LLM grounding.
- **Reproducible-by-construction corpus certificates.** `sm_certificate()`,
  `sm_rebuild_from_cert()`, `sm_verify_certificate()`.
- **Author trajectory analysis.** `sm_author_trajectory()` with topic pivots,
  collaborator turnover, emerging-collaborator detection.
- **Equity and representation audit.** `sm_audit_geographic()`,
  `sm_audit_gender()`, `sm_audit_funding()`, `sm_audit_oa()` with built-in
  confidence reporting and limitation caveats.
- **LLM-grounded corpus chat.** `sm_chat()` with retrieval-constrained
  citations.

### Core modules

- Corpus class (`sm_corpus`) with provenance and screening tables
- Clean-room native parsers for 12 bibliographic formats
- API fetchers for 8 scholarly data sources
- 8 enrichment functions
- Bibliometrix round-trip interop
- 6 network builders (citation, co-citation, coupling, collaboration,
  co-word, semantic)
- Embedding and clustering (HDBSCAN, Leiden, k-means)
- Modern indicators (h/g/m-index, CD index, RCR, FNCI, Uzzi novelty)
- Viridis-themed publication-ready visualization
- Multi-format export (PNG 300/600 dpi, PDF, SVG, TIFF, XLSX, ZIP bundles)
- Comprehensive 13-tab Shiny application
- Systematic review bridge (PRISMA, Rayyan, Covidence)

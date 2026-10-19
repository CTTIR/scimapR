# Changelog

## scimapR (development version)

- New synthetic example files shaped like a Web of Science export of
  three invented military-medical units and their civilian partners:
  `example_realuse_corpus.rds` (150 works),
  `example_realuse_reference.csv` (a publication-tracker reference list)
  and `example_realuse_affiliation_dict.csv` (an affiliation
  dictionary). See the “Real-use fixture” section of
  [`?sm_example_files`](https://cttir.github.io/scimapR/dev/reference/sm_example_files.md).

- The examples of
  [`sm_audit_funding()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_funding.md)
  and
  [`sm_audit_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_summary.md)
  run offline: they no longer send one Crossref request per DOI of the
  example corpus when `R CMD check --as-cran` runs `\donttest{}` code.
  The live lookup is shown in an example that runs only in interactive
  sessions.

- [`sm_audit_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_summary.md)
  no longer sends web requests by default. Its new `online` argument
  controls the funding audit, which looks up every DOI on Crossref: with
  the default `online = FALSE` that audit is reported as not run unless
  a precomputed
  [`sm_audit_funding()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_funding.md)
  result is passed, and `online = TRUE` runs it as before.

- [`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md),
  [`sm_cite_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_cite_corpus.md)
  and citation-maturity cut-offs
  ([`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md),
  `sm_its(outcome = "cnci")`) accept numeric, character, Date and
  POSIXct timestamps in `metadata$build_date` and
  `metadata$last_refresh`. Numbers are read as seconds since 1970-01-01
  UTC, as corpora restored from tables store them, and implausible
  numbers (such as milliseconds) are ignored with a message. Text is
  read as ISO 8601 (a date, or a date and time with an optional `Z` or
  `+hh`, `+hhmm` or `+hh:mm` offset); other text counts as missing.
  Certificates write their timestamps in UTC, for example
  `2026-10-17T11:45:00Z`, still read the older form, and print the
  creation time in UTC.

- [`sm_metric_fnci()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_fnci.md)
  gains `min_cell` and `by_type` (opt-in fallback baselines) and informs
  when many works sit in tiny cells; `sm_its(outcome = "cnci")` and
  `sm_metric_summary(metric = "cnci")` show that message too. With
  `min_cell`, a work whose field-year cell is too small falls back to
  its field in the neighbouring years and then to its year, `field` may
  list several `;`-separated categories, and the result reports `n_cell`
  and `baseline`. `by_type = TRUE` gives articles and reviews baselines
  of their own.

- `sm_metric_fnci(classification = "manual")` reports a factor `field`
  by its labels instead of its integer codes.

- `sm_metric_fnci(classification = "mesh")` never uses a MeSH check tag
  (such as Humans, Female or Adult) or a descriptor of study design or
  statistics (such as Retrospective Studies, Risk Factors or Treatment
  Outcome) as a work’s field.
  [`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md),
  [`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/dev/reference/sm_read_pubmed_xml.md)
  and `sm_enrich_concepts(source = "mesh")` now record each MeSH
  heading’s major-topic flag as its concept `score` (1 for a major
  topic, 0 otherwise; before, always `NA`), so the field is a major
  topic of the work. Headings without scores, as from other sources,
  give the work’s heading that is most frequent in the corpus instead of
  the first one listed, with a message.

- `sm_cluster_evolution(link_by = "cluster_id")` follows a global
  clustering across windows; snapshots gain `share`. Each cluster
  present in two consecutive windows gives one transition, except the
  noise cluster named by the new `noise` argument (default `0L`).

- [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  matches dictionary patterns in Unicode mode, so `\w` and `\b` work on
  non-ASCII names; new
  [`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_unmatched.md)
  lists unmatched affiliation strings. Unicode mode is the new default,
  for the postcode signal too: `\w`, `\b`, `\d`, `\s` and POSIX classes
  such as `[[:alpha:]]` now treat umlauts, accented letters and other
  non-ASCII letters, digits and spaces like ASCII ones. A pattern can
  stop matching if it used `\W`, `\S`, `\D` or `\B` to stand for a
  non-ASCII letter, or if it relied on `\b` between an ASCII and a
  non-ASCII letter: the shipped pattern `\bnato\b` no longer matches
  “NATO” directly followed by an umlaut. The new argument
  `unicode = FALSE` restores the earlier ASCII-only matching.
  [`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
  has no such argument and matches in Unicode mode when it runs
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  itself; the Details of
  [`?sm_affiliation_match`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  show how to get its earlier results.

- [`sm_screen_regex()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_regex.md)
  matches its terms as written, case-insensitively and in Unicode mode
  like
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md),
  so a term can stop matching in the same ways (new argument `unicode`,
  default `TRUE`). It no longer lowercases the patterns, which turned
  `\W`, `\S`, `\D` and `\B` into `\w`, `\s`, `\d` and `\b`, and a corpus
  with a single work now gets one screening row instead of several.

- [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
  no longer fails when a year has no finite outcome,
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  no longer fits silently on fewer years, and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  no longer passes such years to tidysynth; these years are dropped with
  a warning and reported (`dropped_years`).
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  drops them per group, and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  for every unit so that its panel stays balanced. For
  `outcome = "cnci"`, works with an infinite impact value are left out
  of the yearly mean, and a year without usable impact counts as dropped
  even when it is citation-immature, so `dropped_years` and
  `provisional_years` never share a year.

- The confidence intervals of
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
  and
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  use the t distribution with the residual degrees of freedom when the
  model estimates its dispersion, as their p-values already did: the
  default Gaussian fits of
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  and of
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
  for `"share_q1"`, `"cnci"` and `"leadership"`, and quasi families.
  These intervals are wider than before and agree with the p-values.
  Poisson fits (the
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
  default for `"count"`) keep normal intervals and now warn when the
  counts are overdispersed, suggesting `family = "quasipoisson"`.

- With `outcome = "count"`,
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  count a year without works as 0, over every year from the first to the
  last publication year of the corpus, instead of leaving the year out;
  filter the corpus to the analysis window first.
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  aborts when a unit has no works.

- [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
  checks the years that remain after all exclusions (years without a
  usable value and, for `"cnci"`, citation-immature years) instead of
  before the citation-immature cut. It needs at least 4 years, 2 or more
  before `intervention_year` and 2 or more from it on, and aborts
  otherwise, or when a level or slope change cannot be estimated,
  instead of silently fitting a model without those terms. On exactly 4
  years a Gaussian or quasi-family fit has no residual degrees of
  freedom, and
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
  now warns that its standard errors, intervals and p-values are `NaN`.
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  needs 4 years per group, with years before and from
  `intervention_year`, and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  4 panel years, 2 of them before it.

- [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  check `intervention_year` the same way and abort unless it is one
  whole year, given as a number or as text such as `"2020"`. Before,
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  truncated a year such as 2020.5 and read `TRUE` as the year 1, and all
  three read a factor or a date by its internal number.

- Concept vocabularies are now a controlled set
  ([`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md));
  [`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)
  DE and keyword co-word networks work for file-based corpora.
  [`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  and
  [`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)
  rename legacy and common spellings such as `"keywords-author"`,
  `"keyword"` or `"MEDLINE"` to these names, with a message, and the
  functions that select concepts by vocabulary read every one of these
  spellings. Values that name no known vocabulary are kept as written
  and listed in the same message, so a corpus built from such tables now
  reports them each time; name a vocabulary of your own `"custom"`. DE
  holds each work’s author keywords; a work without any falls back to
  its OpenAlex concepts, so corpora built from OpenAlex keep their DE,
  and arXiv and bioRxiv categories stay out of it as before.
  [`sm_network_coword()`](https://cttir.github.io/scimapR/dev/reference/sm_network_coword.md)
  gains `vocabulary`: `field = "keywords"` uses the author keywords by
  default and, in a corpus without any, the indexer keywords (such as
  Keywords Plus or MeSH) with a message; a corpus with neither gives an
  empty network, now with a message. With `field = "concepts"`,
  `vocabulary` keeps only the vocabularies named.

- [`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
  reads the Web of Science categories (WC) into the new vocabulary
  `wos-category`; `wos-subject-category` keeps the research areas (SC).
  Corpora read from Web of Science files therefore have more concept
  rows, which changes the results of functions that use every concept
  whatever its vocabulary: `sm_network_coword(field = "concepts")`,
  [`sm_plot_thematic_map()`](https://cttir.github.io/scimapR/dev/reference/sm_plot_thematic_map.md),
  [`sm_author_trajectory()`](https://cttir.github.io/scimapR/dev/reference/sm_author_trajectory.md)
  and the corpus hash
  ([`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md)).
  [`sm_author_trajectory()`](https://cttir.github.io/scimapR/dev/reference/sm_author_trajectory.md)
  now counts a concept name once per work in its dominant topics and
  novelty (before, a name that a work had in two vocabularies counted
  twice), so a category with the same name as a research area of the
  work leaves the trajectory unchanged.

- [`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)
  exports C1, RP, ID, WC, SC, UT, SN/EI, J9/JI, EM, AF, one AU entry per
  author, CR in Web of Science form and `DB = "ISI"` for corpora from
  Web of Science, so
  [`bibliometrix::histNetwork()`](https://rdrr.io/pkg/bibliometrix/man/histNetwork.html)
  and
  [`bibliometrix::rpys()`](https://rdrr.io/pkg/bibliometrix/man/rpys.html)
  run; C1 round-trips through
  [`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md).
  Every tag column is present, `NA` where the corpus has no data. New
  arguments: `keep_extra = FALSE` drops the columns without a field tag,
  and `db` sets `DB`.
  [`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
  now reads the ISSNs and journal abbreviations (SN, EI, J9, JI) into
  `sources` (`issn_l`, `issn` and the new columns `abbreviation` and
  `iso_abbreviation`), so ISSN lookups now work for corpora read from
  Web of Science files. It also keeps each author name as the file
  writes it (such as “Garcia Lopez, M”) in
  `authors$display_name_alternatives`, so the export keeps surnames of
  several words whole, and cited-reference DOIs lose a trailing period.
  Because of these changes the corpus hash
  ([`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md))
  of corpora read from Web of Science files changes too.

- [`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)
  now upper-cases the text fields that bibliometrix keeps upper-case (as
  `convert2df()` does); `DI` stays as stored. Its default output changes
  in a few more ways: `AU` holds names as `SURNAME INITIALS` (such as
  `VALDEZ P`) instead of the stored display names, `SR` is built as
  `convert2df()` builds it (first author, year and journal abbreviation,
  made unique) and gives the row names, `NR` counts the items of `CR`
  instead of the reference rows, `DE` separates its terms with `;`, and
  the tag columns come first. `AU_CO` is no longer written, so
  bibliometrix reads the countries from `C1`
  (`bibliometrix::metaTagExtraction(M, "AU_CO")`) as it does for
  `convert2df()` data. With the default `keep_extra = TRUE` the other
  columns stay, and the ISO country codes that `AU_CO` held are in the
  new column `country_code`.

- The `"bibliometrix"` and `"auto"` engines of the file readers and
  [`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md)
  for bibliometrix data frames now share one conversion, which also
  reads the cited references (CR, with the DOI of each reference that
  has one), the sources (SO, SN, EI, J9, JI), the keywords and
  categories (DE, ID, WC, SC), the Web of Science accession numbers (UT)
  and the PubMed IDs; before, these corpora had no references, sources
  or concepts. Authors keep their full names from AF and get one
  authorship row per address, linked through the names in C1, and titles
  and abstracts keep the case of the file. Authors are now told apart by
  their full names in AF instead of their AU form, so author counts can
  change; an entry with initials only, or without AF, belongs to the
  author with the same surname and initials when there is just one.
  [`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md)
  labels the provenance of Web of Science data (`DB = "ISI"`) `"wos"`.

- `sm_coverage_audit(by =)` accepts any reference or works column;
  corpus-side affiliation uses institution matches before country codes.
  A name is either one of the named dimensions `"year"`, `"source"` and
  `"affiliation"` or a column of the reference data frame (matched
  case-insensitively) or of `works`; a dimension found on one side only
  gets `NA` for the other side, and a name found on neither side is an
  error listing the available columns. The affiliation levels of a
  corpus come from the first of `institution_match`, `institution_name`,
  `institution_id` and `country_code` that has a value, with a message
  naming the column on each side and a warning when a side falls back to
  country codes. A work counts in every institution of its authors, so
  per-level counts can add up to more than the total; the overall recall
  and precision count each record once. In a data-frame reference,
  `"affiliation"` now takes an `affiliation`, `affiliations` or
  `institution` column before a `country` or `country_code` column, and
  `"source"` a source name before `source_id`, whatever their order, and
  the values of each row stay with that row.

- [`sm_coverage_audit()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md)
  and
  [`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md)
  identify the rows of a data frame by its `UT` column (Web of Science
  accession numbers) or an `id`, `work_id`, `reference_id` or `ref_id`
  column only when its values are unique and none is missing; otherwise
  rows are identified by their position (`R000001`, …), with a warning.
  A column named `ID` next to Web of Science field tags holds the
  Keywords Plus and is never used. Before, missing or repeated
  identifiers, such as those of the `ID` column that
  [`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)
  writes, made the recall, the breakdowns, `n_reference_only` and
  `matches$reference_id` disagree.

- [`sm_coverage_audit()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md)
  looks up each reference row on its own for recall, so an item that two
  rows report (one paper reported by two units) counts as found for both
  instead of only for the first; precision still pairs each corpus
  record with at most one reference row. `n_matched` counts the
  reference rows found and the new element `n_corpus_matched` the corpus
  records paired, which [`print()`](https://rdrr.io/r/base/print.html)
  shows for precision and
  [`summary()`](https://rdrr.io/r/base/summary.html) adds as its last
  column; the two differ only when reference rows share a corpus record.
  The new element `reference_matches` shows for each reference row the
  corpus record it was found in, as `matches` does for the corpus
  records. When a DOI repeats on both sides, its records now pair in
  order instead of leaving the later ones to the title fallback.

- The title fallback of
  [`sm_coverage_audit()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md)
  and
  [`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md)
  pairs two records only when their publication years differ by at most
  one (or a year is missing) and never when both have a DOI and the DOIs
  differ, so serial titles such as annual reports and generic titles
  such as “Editorial” no longer match across years. A `Date` or
  date-time year column of a data frame counts by its calendar year, and
  a year outside 1000-2999 (such as a day count) as missing.

- Title matching in
  [`sm_coverage_audit()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md)
  and
  [`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md),
  and the ROR lookup of
  [`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md),
  keep the letters and digits of every script when they normalise text.
  Before, they dropped every non-ASCII letter, so titles in Cyrillic,
  Greek or other non-Latin scripts never matched and words with umlauts
  or accents lost letters.

- `sm_count(level = "institution")` no longer applies the shipped
  dictionary `sm_affiliation_dict` on its own, which credited any
  “military hospital” or “army hospital” to “Bundeswehr Hospital”. This
  changes its default counts: each authorship row now takes the first of
  `institution_match`, `institution_name` and `institution_id` (named by
  `corpus$institutions` when listed) that has a value in that row, and
  otherwise its raw affiliation string, with a warning. Before, one
  column served every row, so the rows without a value in it were left
  out, and `entity_id` was the `institution_id` whenever any row had
  one; now it is the label, except for rows labelled through
  `institution_id`. After
  [`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md),
  which keeps `institution_match`, the counts therefore follow the
  dictionary matches instead of their roll-up to ROR ids and names; to
  count by the vocabulary, replace `institution_match` by
  `institution_name` where that is set (see
  [`?sm_count`](https://cttir.github.io/scimapR/dev/reference/sm_count.md)).
  Run
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  with a dictionary of your institutions first to count them.

- The shipped dictionary `sm_affiliation_dict` no longer credits a bare
  “military hospital”, “army hospital” or “armed forces hospital”, which
  can be a hospital of any country, to “Bundeswehr Hospital”. Its rows
  for that hospital now need “Bundeswehr”, “German Armed Forces”,
  “German Army” or “German Military” before “hospital”, or the German
  name, so
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  with its default patterns, and
  [`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
  on a corpus that was not matched first, leave other military hospitals
  unmatched; an English name with “Bundeswehr”, such as “Bundeswehr
  Hospital”, now matches as well.

- The WoS reader (both engines), the bibliometrix import and both
  OpenAlex readers take the corresponding author from the RP field or
  the OpenAlex `is_corresponding` flag instead of assuming the first
  author; the readers of sources without this information record it as
  unknown (`NA`). `sm_audit_geographic(weight = "corresponding")` and
  the gender audit now find corresponding authors (they used
  [`isTRUE()`](https://rdrr.io/r/base/Logic.html) on a column). RP is
  read in any case, with the older “(reprint author)” and with its names
  on one line or several, in both engines; namesakes with the same
  surname and initials are told apart by the address RP gives, and stay
  unknown when it does not tell them apart. A work whose RP names none
  of its authors counts as unknown, and so does an OpenAlex work whose
  authors are all marked `false` unless its `corresponding_author_ids`
  lists one of them. This changes default results:
  [`sm_read_lens()`](https://cttir.github.io/scimapR/dev/reference/sm_read_lens.md),
  [`sm_read_ris()`](https://cttir.github.io/scimapR/dev/reference/sm_read_ris.md),
  [`sm_read_scopus()`](https://cttir.github.io/scimapR/dev/reference/sm_read_scopus.md),
  [`sm_read_bib()`](https://cttir.github.io/scimapR/dev/reference/sm_read_bib.md),
  [`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/dev/reference/sm_read_pubmed_xml.md),
  [`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md),
  [`sm_fetch_crossref()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_crossref.md)
  and the other readers and fetchers without corresponding-author data
  now give `NA` instead of `TRUE` for the first author, so
  [`sm_to_bibliometrix()`](https://cttir.github.io/scimapR/dev/reference/sm_to_bibliometrix.md)
  exports `RP = NA` for their corpora, and
  `sm_audit_geographic(weight = "corresponding")` reports the countries
  of the corresponding authors instead of an empty table with coverage
  0.

- Leadership outcomes can be restricted to focal institutions and author
  roles (`institutions`, `lead_role`; `institution_aware` in
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md));
  works with an unknown corresponding author, and works without any
  authorship rows (before counted as not led), leave the default
  leadership denominator. A work counts as led when an authorship in the
  role (`"corresponding"`, `"first"`, `"last"`, `"first_or_last"` or
  `"any_lead"`) carries one of the institution labels in
  `institution_match`, `institution_name` or `institution_id`, or the
  name of that id in `corpus$institutions`; a label that no authorship
  carries gives a warning naming the nearest labels. The denominator
  change applies to
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  alike and changes their default `"leadership"` results for corpora
  with unknown corresponding authors, which now include most corpora
  from readers other than the WoS and OpenAlex readers: a year without a
  known corresponding author is dropped with a warning, and when no work
  has one the functions abort and suggest `lead_role = "first"` or
  `"last"` with focal institutions. The print methods state the
  definition used, which the results keep in `leadership`.

- [`sm_read_wos()`](https://cttir.github.io/scimapR/dev/reference/sm_read_wos.md)
  links the addresses of C1 to the authors by their whole names, as the
  bibliometrix engine does: the full name of AF, else the surname and
  initials, else the surname and first initial. It now writes one
  authorship row per author and address. Before, it gave each author the
  first C1 line whose bracket contained the author’s surname anywhere,
  so a short surname such as “He” or “Li” took the address of “Chen” or
  “Lin”, an author with several addresses kept only the first, and lines
  without names linked nobody. In both engines and in
  [`as_sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/as_sm_corpus.md),
  an address that C1 lists without names, as older records do, now
  belongs to every author of the record, and the bibliometrix engine
  keeps such a line apart from the address before it. Authorship rows,
  address-based counts and the corpus hash of corpora read from Web of
  Science files change.

- [`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_biorxiv.md)
  takes the corresponding author from the `author_corresponding` field
  of the bioRxiv API, and
  [`sm_read_dimensions()`](https://cttir.github.io/scimapR/dev/reference/sm_read_dimensions.md)
  from a Corresponding Authors column, matching the names to the authors
  by surname and given names or initials; a name that fits two authors
  equally leaves both unknown.
  [`sm_fetch_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_orcid.md)
  records the ORCID holder’s `position` and corresponding-author flag as
  unknown (`NA`); before, the holder was first and corresponding author
  of every work, which counted as first authorship in the geographic and
  gender audits.

- [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  reports the works that belong to both the treated and the control
  group, such as works co-authored by both, which pull the two series
  together and the estimate toward 0: with a warning when the new
  argument `shared` is not set, and in the new element `shared_works`.
  `shared = "exclude"` leaves them out of both series and `"lead"` gives
  each to the group of its lead author (`lead_role`); the default
  `"keep"` keeps them in both, as before.
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  aborts when `treated` and `control` share a label.
  [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)
  and
  [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)
  gain `lag` and, for `outcome = "cnci"`, now leave out the
  citation-immature years as
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
  does and list them in `provisional_years`, which changes their default
  `"cnci"` results.

- [`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
  keeps the `institution_id` and `institution_name` of the authorships
  it does not match, such as the OpenAlex institution ids of a fetched
  corpus. Before, it set them to `NA`, so institution counts, the
  institution h-index and the regional audit lost every institution
  outside the vocabulary.

- [`sm_summary_authors()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_authors.md),
  [`sm_summary_period()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_period.md)
  and the position breakdown of
  [`sm_audit_gender()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_gender.md)
  count each author once per work, however many address rows the author
  has in it, as
  [`sm_metric_collab_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_collab_index.md)
  does. Before, an author with two address rows counted twice, so a
  single-author work did not count as single-authored and the authors
  per work disagreed with
  [`sm_metric_collab_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_collab_index.md).

## scimapR 0.4.0

Stability contracts, an enrichment materializer, and
self-citation-corrected metrics, plus a verify-and-harden pass on three
v0.3.0 fixes that recurred in heavy use. All new behaviour is opt-in; no
breaking changes.

### Accessor stability contract (A1)

- New `?scimapR-stability` topic documents the package’s accessor
  return-type contract: a documented accessor’s column set changes only
  via a `lifecycle` deprecation and a `NEWS.md` entry. The audited
  accessors and their stable shapes are listed there.
- [`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_breakdowns.md)
  gains `tidy = TRUE` (default): a guaranteed long tibble (`dimension`,
  `level`, `n_reference`, `n_matched`, `recall`, `n_corpus`,
  `precision`, `f1`). `tidy = FALSE` returns the legacy recall-only
  shape. (The silent list -\> tibble change between 0.2.0 and 0.3.0
  motivated this contract.)

### Controlled vocabularies (B1)

- Exported
  [`sm_affiliation_signals()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_signals.md),
  [`sm_affiliation_methods()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_methods.md),
  and
  [`sm_match_types()`](https://cttir.github.io/scimapR/dev/reference/sm_match_types.md)
  (with `describe = TRUE` for level + description). The `match_signal`,
  `match_method`, and coverage `match_type` columns are now factors with
  these exact levels, so downstream filtering cannot drift.

### Verify-and-harden (re-reported v0.3.0 fixes)

These were reported again on a real corpus; each now has a regression
test reproducing the recurrence.

- **C1** `sm_its(outcome = "cnci")`: the resolver now also searches
  documented impact *side columns* on `works` (`fnci`, `rcr`, `ncs`,
  `mncs`, `field_citation_ratio`) and a `corpus$metrics` table, in
  addition to `works$cnci` and `works$cited_by_count`. With no impact
  anywhere it errors naming every column inspected. (v0.3 only checked
  `works$cnci` / `cited_by_count`, so impact in a side column still
  produced “0 observations”.)
- **C2** `sm_count(level = "institution")`: when structured IDs are
  absent it now *clusters* `raw_affiliation` via
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  (canonical names where matched, raw string otherwise) with a warning,
  instead of counting raw strings verbatim. Absent raw affiliation -\>
  0-row tibble + warning.
- **C3** network plot `precompute = TRUE` confirmed; the `max_nodes` cap
  is now **opt-in** (`NULL` default) so large renders are unchanged
  unless a cap is requested. A ~2,000-node graph builds with
  `precompute = TRUE` and re-prints without recomputing layout.

### Enrichment materializer (D1)

- `sm_materialise(corpus, sources, .by = NULL, overwrite = FALSE)` joins
  cached enrichment (named list of tibbles / RDS / parquet paths, or a
  cache dir) into the matching sub-tibbles by key, returning a validated
  `sm_corpus`. Missing keys warn (not error); overlapping columns fill
  `NA` unless `overwrite = TRUE`.
- Added an internal type-safe row-bind helper (`.sm_bind_rows`) that
  returns a typed template instead of a logical-column degenerate when
  all parts are `NULL`/empty; audited the package’s existing
  `bind_rows()` sites (found safe, guarded behind length checks with
  typed tibbles).

### Self-citation-corrected metrics (E1, E2, F1)

- `sm_self_citation(corpus, level = c("author", "institution"))`
  computes self-citation from the corpus reference network (quota-light
  reference overlap; no per-citation API calls), returning `by_entity`,
  `by_work`, and a **provenance** tibble (`citing_work_id`,
  `cited_work_id`, `shared_author_id`/`shared_institution_id`) (F1).
  Empty references -\> warning + typed empty result (no spin).
- [`sm_metric_h_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_h_index.md),
  [`sm_metric_g_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_g_index.md),
  [`sm_metric_m_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_m_index.md)
  gain `self_corrected = FALSE`; with `TRUE` the index is recomputed
  after removing self-citations (author/institution levels). The
  corrected index is always `<=` the uncorrected one.

### Provenance (F2)

- [`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md)
  now includes `example_evidence` (a representative matched-evidence
  string per institution x signal) alongside the factorised
  `match_signal`, so a reader can see which signal matched and on what
  evidence.

### Fixtures

- `inst/extdata/example_self_citation_corpus.rds`: a small
  references-bearing synthetic corpus for self-citation examples/tests.

## scimapR 0.3.0

Real-use refinements from running v0.2.0 on a ~6,853-work corpus:
robustness fixes, friendlier API shapes, two new capabilities, and
vignettes that ship in the installed binary. The public API is preserved
(deprecation paths only).

### Bug fixes

- **A1** `sm_its(outcome = "cnci")` no longer fails with a cryptic “Too
  few yearly observations: 0” when impact lives outside
  `cited_by_count`. The resolver now searches, in order, `works$cnci`, a
  `corpus$metrics` table, then `works$cited_by_count` (deriving FNCI);
  if none is populated it raises an informative error naming the columns
  it inspected.
- **A2** `sm_count(level = "institution")` falls back to
  `authorships$raw_affiliation` (with a `cli` warning that results are
  un-disambiguated) when structured institution IDs are absent, and
  warns rather than returning a silent empty result when no institution
  data exists.
- **A3**
  [`sm_metric_disruption()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_disruption.md)
  and
  [`sm_metric_novelty()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_novelty.md)
  fast-exit with a warning when the reference network is empty/absent
  instead of spinning; the disruption index was rewritten with O(1)
  adjacency lookups (no longer O(n^2)) and now shows a `cli` progress
  bar.
  [`sm_audit_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_summary.md)
  shows a progress bar across its sub-audits.
- **A4** Network plots
  ([`sm_plot_citation_network()`](https://cttir.github.io/scimapR/dev/reference/sm_plot_citation_network.md),
  [`sm_plot_collab()`](https://cttir.github.io/scimapR/dev/reference/sm_plot_collab.md))
  gain `precompute = TRUE` (eager layout -\> a self-contained plain
  `ggplot` that prints cheaply in knitr/`callr`/workflowr subprocesses)
  and a `max_nodes` cap (default 200) for very large graphs.

### Ergonomics

- **B1** `sm_coverage_audit()$breakdowns` is now a single flat tibble
  (`dimension`, `level`, `n_reference`, `n_matched`, `recall`). The
  previous nested list remains available under `$breakdowns_nested` for
  one release. New accessor
  [`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_breakdowns.md)
  returns/filters the flat tibble.
- **B2**
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  documents its added columns and gains
  [`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md)
  — a tidy works/authorships breakdown by institution and match signal,
  also surfaced as a `cli` summary on completion.
- **B3**
  [`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)
  is promoted in the ingestion vignette as the recommended “bring your
  own relational data” entry point.

### New capabilities

- **C1** `sm_coverage_audit(..., index_table = )` additionally assesses
  journal **indexability** (reusing
  [`sm_journal_in_index()`](https://cttir.github.io/scimapR/dev/reference/sm_journal_in_index.md)),
  adding `issn`/`indexable` columns to `$matches` and an `$indexability`
  summary. Output is unchanged when `index_table` is `NULL`.
- **C2**
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  returns `match_signal` (`name_token`/`email_domain`/`postcode`) and
  `match_evidence` (the matched substring/domain/code) for an audit
  trail, plus an opt-in `postcode_signal = TRUE` matcher (off by default
  so existing matches are stable).

### Packaging

- **D1** Vignettes now ship in the installed binary; browse them offline
  with `vignette(package = "scimapR")` / `browseVignettes("scimapR")`,
  or online at the pkgdown site. New `inst/extdata/` fixtures:
  `example_affiliation_postcode.csv`.

## scimapR 0.2.0

A new capability layer for research-coverage, affiliation-attribution,
and policy-evaluation analyses, plus four reproducible bug fixes. All
existing functionality, the `sm_corpus` schema, bibliometrix interop,
and the Shiny app are preserved.

### New features

#### Coverage & completeness auditing

- [`sm_coverage_audit()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md)
  computes recall, precision, and F1 of a corpus against a ground-truth
  reference (manual tracker, ORCID set, repository export, or another
  `sm_corpus`), with per-`year`/`source`/`affiliation` breakdowns and
  full match provenance. Returns an `sm_coverage` object with `print`,
  `summary`, and `autoplot` methods.
- [`sm_journal_in_index()`](https://cttir.github.io/scimapR/dev/reference/sm_journal_in_index.md)
  verifies source coverage against a user-supplied journal master list
  by normalised ISSN (print and electronic), fully offline.
- [`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md)
  performs a content-based symmetric diff (DOI then fuzzy title)
  returning an `sm_reconciliation` (`in_both`/`only_a`/`only_b` +
  provenance), with `print`/`summary`/`autoplot`.
  [`sm_diff_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_diff_corpora.md)
  is now marked superseded in favour of it (and continues to work
  unchanged).

#### Affiliation disambiguation & attribution

- [`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
  tags authorships with institutions using a multilingual /
  synonym-aware dictionary and an email-domain fallback, handling
  multiple affiliations per author.
- [`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
  rolls matches up to a controlled vocabulary (ROR-backed via an offline
  ROR table, or a custom vocabulary).
- `sm_affiliation_dict`: a default, documented, user-overridable
  dictionary.

#### Causal / policy evaluation

- [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md):
  turnkey interrupted time series (level + slope terms, counterfactual,
  `autoplot`), with automatic exclusion of citation-immature years for
  citation-based outcomes.
- [`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md):
  difference-in-differences for treated vs control institution sets.
- [`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md):
  synthetic-control helper (optional `tidysynth`, graceful error when
  absent).

#### Correctness: citation maturity & counting

- [`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md)
  flags citation-immature recent years (`citation_mature` /
  `cnci_provisional`), wired into
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).
- [`sm_count()`](https://cttir.github.io/scimapR/dev/reference/sm_count.md):
  full vs fractional counting at institution / author / source level
  (output credit and fractionally-weighted impact).

#### Robust impact summaries

- `sm_metric_summary(robust = TRUE)` reports medians with bootstrap CIs
  and %PP(top-10%) alongside means (base-R resampling by default; `boot`
  optional; reproducible via `seed`).

#### Reproducible reporting glue

- [`sm_figure_manifest()`](https://cttir.github.io/scimapR/dev/reference/sm_figure_manifest.md)
  scans a figure directory into a captions / alt-text / dimensions
  manifest (optional `magick`/`png`, sidecar caption files, CSV/YAML
  output).
- [`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md):
  a documented, validating constructor from a relational set of data
  frames — the recommended ingestion path for arbitrary tabular sources.

### Bug fixes

- **G1** `sm_fetch_openalex(engine = "native")`: abstract reconstruction
  from the OpenAlex inverted index is now type-stable and never aborts a
  fetch on an empty/`NULL`/malformed record (and no longer passes an
  invalid `.default` to
  [`purrr::map_chr()`](https://purrr.tidyverse.org/reference/map.html)).
- **G2** `sm_fetch_openalex(engine = "openalexR")`: long DOI (or other
  ID) lists are auto-batched under the API’s OR-filter limit via the new
  `batch_size` argument, then row-bound and de-duplicated.
- **G3** `sm_read_bib(engine = "bibliometrix")`: a field-sparse
  `@article` no longer triggers “undefined columns selected”; the
  scimapR wrapper catches the failure and falls back to the native
  parser (clean-room rule preserved).
- **G4** native BibTeX engine performance: the parser was rewritten from
  per-character
  [`substr()`](https://rdrr.io/r/base/substr.html)/[`grepl()`](https://rdrr.io/r/base/grep.html)
  scanning and per-entry tibble construction to linear character-vector
  scanning with single-pass column assembly. Parsing ~7,000 entries
  dropped from ~100 s to ~17 s on R 4.5.2 / Windows.

### New data & fixtures

- `inst/extdata/`: `example_sparse.bib`,
  `example_openalex_inverted.json`, `example_journal_index.csv`,
  `example_ror.csv`.

## scimapR 0.1.0

### Initial release

`scimapR` is a comprehensive R toolkit for bibliometric and
scientometric analysis: the reproducible, equity-aware, question-driven,
AI-assisted toolkit for working biomedical researchers. Designed as a
complement to the foundational `bibliometrix` package (Aria &
Cuccurullo, 2017) with first-class round-trip interop.

#### Distinctive features

- **Live corpus refresh.**
  [`sm_refresh()`](https://cttir.github.io/scimapR/dev/reference/sm_refresh.md),
  [`sm_staleness()`](https://cttir.github.io/scimapR/dev/reference/sm_staleness.md),
  [`sm_lock()`](https://cttir.github.io/scimapR/dev/reference/sm_lock.md).
- **Research questions as objects.**
  [`sm_question()`](https://cttir.github.io/scimapR/dev/reference/sm_question.md),
  [`sm_corpus_for_question()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_for_question.md),
  [`sm_screen_against_question()`](https://cttir.github.io/scimapR/dev/reference/sm_screen_against_question.md)
  with optional LLM grounding.
- **Reproducible-by-construction corpus certificates.**
  [`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md),
  [`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md),
  [`sm_verify_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md).
- **Author trajectory analysis.**
  [`sm_author_trajectory()`](https://cttir.github.io/scimapR/dev/reference/sm_author_trajectory.md)
  with topic pivots, collaborator turnover, emerging-collaborator
  detection.
- **Equity and representation audit.**
  [`sm_audit_geographic()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_geographic.md),
  [`sm_audit_gender()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_gender.md),
  [`sm_audit_funding()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_funding.md),
  [`sm_audit_oa()`](https://cttir.github.io/scimapR/dev/reference/sm_audit_oa.md)
  with built-in confidence reporting and limitation caveats.
- **LLM-grounded corpus chat.**
  [`sm_chat()`](https://cttir.github.io/scimapR/dev/reference/sm_chat.md)
  with retrieval-constrained citations.

#### Core modules

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
- Multi-format export (PNG 300/600 dpi, PDF, SVG, TIFF, XLSX, ZIP
  bundles)
- Comprehensive 13-tab Shiny application
- Systematic review bridge (PRISMA, Rayyan, Covidence)

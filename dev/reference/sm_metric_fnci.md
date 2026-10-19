# Calculate Field-Normalized Citation Impact

Computes the Field-Normalized Citation Impact (FNCI) for each work in
the corpus. FNCI normalises a work's citation count by the average
citation count of all works in the same field and publication year.

## Usage

``` r
sm_metric_fnci(
  corpus,
  classification = c("openalex_concepts", "mesh", "manual"),
  min_cell = NULL,
  by_type = FALSE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object.

- classification:

  Character; the classification system used to assign works to fields.
  One of `"openalex_concepts"` (default), `"mesh"`, or `"manual"`.

- min_cell:

  `NULL` (default) or a positive integer. When set, a baseline needs at
  least `min_cell` works with a known citation count; works in smaller
  cells fall back to larger baselines (see Details), and the result
  gains the columns `n_cell` and `baseline`.

- by_type:

  Logical. If `TRUE`, baseline cells are also split by document type,
  normalised from `works$type`: articles and reviews get cells of their
  own and all other types get `fnci = NA`. Adds the column `doc_type`.
  Default `FALSE`.

- call:

  Caller environment for error reporting.

## Value

A tibble with one row per work and the columns `work_id`, `field`,
`year`, `cited_by_count`, `field_mean` (the baseline: the mean citation
count of the work's cell) and `fnci`. The column set depends on the
arguments: `by_type = TRUE` adds `doc_type` (`"article"`, `"review"` or
`NA`), and `min_cell` adds `n_cell` (integer; the number of works with a
known citation count in the baseline cell) and `baseline` (a factor with
the levels `field_year`, `field_year_pm1`, `year` and `none`; the level
the baseline comes from). An empty corpus gives a 0-row tibble with the
same columns.

## Details

FNCI is defined as:

\$\$FNCI_i = \frac{C_i}{\bar{C}\_{f,y}}\$\$

Where \\C_i\\ is the citation count of work *i* and \\\bar{C}\_{f,y}\\
is the mean citation count of all works in field *f* published in year
*y*.

An FNCI of 1.0 means the work is cited at the corpus average of its
baseline cell (by default its field and year). Values \> 1.0 indicate
above-average impact.

For `"openalex_concepts"`, the highest-scoring level-0 concept from the
concepts table is used. For `"mesh"`, MeSH headings are used (requires
MeSH data in concepts; see below). For `"manual"`, a `field` column must
already exist in `corpus$works`.

## Small cells

A cell with few works gives an unstable baseline, and a work alone in
its cell gets FNCI = 1 by construction. When `min_cell` is `NULL` and
more than 25% of the works with a citation count sit in cells with fewer
than 10 such works, a message (class `scimapR_fnci_small_cells`) gives
that share.
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)
(`outcome = "cnci"`) and
[`sm_metric_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_summary.md)
(`metric = "cnci"`) show it too when they derive impact from citation
counts.

## Fallback baselines

With `min_cell` set, each work gets the most specific baseline that has
at least `min_cell` works with a known citation count, the work itself
included:

1.  `field_year`: its field and publication year;

2.  `field_year_pm1`: its field in the pooled years y - 1 to y + 1
    (truncated at the edges of the corpus);

3.  `year`: all works of its publication year.

If even the year has fewer than `min_cell` such works, `fnci` and
`field_mean` are `NA`, `baseline` is `"none"` and `n_cell` gives the
size of the year cell. Works without a field (`"unclassified"`) start at
the `year` level, and works without a year get `NA` throughout.

In this mode `field` may list several categories separated by `;`, as
the Web of Science WC field does. A work belongs to the cell of each of
its categories. For each category the most specific level that reaches
`min_cell` is found, and the work's baseline is the average of the
category baselines at the most specific level any of them reached:
`baseline` names that level and `n_cell` is the smallest of the averaged
cells. The baselines are averaged (\\C_i / mean(e_k)\\), not the ratios
(\\mean(C_i / e_k)\\). `field` keeps the original string. Without
`min_cell` the string is one field, as before.

## Document types

With `by_type = TRUE`, `works$type` is normalised: lower-cased, its
first `;`-separated part, trimmed. `"article"` covers article,
journal-article, jour and research-article; `"review"` covers review and
review article. Works of any other or a missing type get `fnci = NA`
(and `baseline = NA`), with one message (class
`scimapR_fnci_other_types`). The type stays part of the cell at every
fallback level. The PubMed and Semantic Scholar fetchers record every
work as `"journal-article"`, so their reviews count as articles.

## MeSH fields

MeSH check tags (Humans, Animals, Male, Female, Pregnancy, the age
groups, common laboratory and farm animals, and the historical periods)
describe who or what was studied, and common descriptors of study
design, statistics and laboratory material (such as Retrospective
Studies, Risk Factors, Treatment Outcome or Cells, Cultured) describe
how it was studied. Neither is ever used as a field.

[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md),
[`sm_read_pubmed_xml()`](https://cttir.github.io/scimapR/dev/reference/sm_read_pubmed_xml.md)
and
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_concepts.md)
(`source = "mesh"`) record each heading's major-topic flag as its score:
1 for a major topic of the article (starred in PubMed) and 0 otherwise.
A work gets its highest-scoring heading; among several, the one that
most works of the corpus carry (ties in alphabetical order). A work
whose headings carry no scores, as with MeSH terms from other sources,
gets its heading that is most frequent in the corpus, with one message
(class `scimapR_fnci_mesh_unscored`). A work with no other headings is
unclassified.

## References

Waltman, L., van Eck, N. J., van Leeuwen, T. N., Visser, M. S., & van
Raan, A. F. J. (2011). Towards a New Crown Indicator: Some Theoretical
Considerations. *Journal of Informetrics*, 5(1), 37–47.
[doi:10.1016/j.joi.2010.08.001](https://doi.org/10.1016/j.joi.2010.08.001)

## See also

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_disruption.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_h_index.md),
[`sm_metric_m_index()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_novelty.md),
[`sm_metric_rcr()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_rcr.md),
[`sm_self_citation()`](https://cttir.github.io/scimapR/dev/reference/sm_self_citation.md),
[`sm_summary_authors()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://cttir.github.io/scimapR/dev/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
fnci <- sm_metric_fnci(corpus, classification = "openalex_concepts")
#> ℹ 100% of the works sit in field-year cells with fewer than 10 works, so their
#>   FNCI baselines rest on very few citation counts.
#> ℹ Set `min_cell` of `sm_metric_fnci()` to fall back to larger baselines for
#>   small cells.
head(fnci)
#> # A tibble: 6 × 6
#>   work_id    field                    year cited_by_count field_mean  fnci
#>   <chr>      <chr>                   <int>          <int>      <dbl> <dbl>
#> 1 W000000001 clinical outcomes        2023              3       10.2 0.293
#> 2 W000000002 colorectal cancer        2020              9       12.2 0.738
#> 3 W000000003 gene expression          2024             28       11.3 2.47 
#> 4 W000000004 spatial transcriptomics  2020             29       27.5 1.05 
#> 5 W000000005 immune checkpoint        2020             16       16   1    
#> 6 W000000006 immune checkpoint        2018             16       16   1    

# Fall back to larger baselines for cells with fewer than 5 works, with
# articles and reviews normalised separately
fnci <- sm_metric_fnci(corpus, min_cell = 5, by_type = TRUE)
#> ℹ 14 works of a type other than article or review get no FNCI with `by_type =
#>   TRUE`.
#> ℹ Type: "letter".
table(fnci$baseline, useNA = "ifany")
#> 
#>     field_year field_year_pm1           year           none           <NA> 
#>              5             34            132             15             14 
```

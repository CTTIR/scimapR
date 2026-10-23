# Label clusters with representative terms

Assigns human-readable labels to clusters by extracting representative
terms. Supports TF-IDF-based extraction (default), labels from the
author and indexer keywords of the corpus, YAKE keyword extraction, or
labels from a chat provider via the ellmer package.

## Usage

``` r
sm_cluster_label(
  corpus,
  method = c("tfidf", "keywords", "yake", "llm"),
  n_terms = 5L,
  llm_provider = NULL,
  min_works = NULL,
  ngram = 1:2,
  stop_terms = NULL,
  noise = 0L,
  seed = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object with a `cluster_id` column in `corpus$works`.

- method:

  Character; labelling method. One of `"tfidf"` (default), `"keywords"`,
  `"yake"`, or `"llm"`.

- n_terms:

  Integer; number of top terms to include in each cluster label.
  Defaults to `5L`.

- llm_provider:

  An ellmer chat provider object (e.g.,
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html)).
  Required when `method = "llm"`, ignored otherwise. Each request uses a
  fresh copy; earlier turns and the object's system prompt are not used,
  and the object stays unchanged.

- min_works:

  For `"tfidf"` and `"keywords"`: the number of a cluster's works a term
  must occur in to enter its label. `NULL` (default) takes 3 or 5% of
  the cluster's works, whichever is more. When no term of a cluster
  reaches it, terms that occur in 2 of its works are used instead, as
  `cluster_label_basis` records.

- ngram:

  For `"tfidf"`: the lengths of the terms it scores, in words, as whole
  numbers from 1 to 3. The default `1:2` scores single words and pairs
  of adjacent words; `1` gives labels of single words. Two terms that
  overlap can be shown as the longer phrase they form (see Details).
  `"keywords"` uses it for the titles it falls back to.

- stop_terms:

  Character vector of terms to leave out of the labels, such as generic
  words that every cluster shares; `NULL` (default) leaves out none.
  Each is compared with whole terms, ignoring case and the difference
  between singular and plural. Not used by `"llm"`.

- noise:

  The `cluster_id` that marks noise, the works no cluster claims: `0L`
  by default, as
  [`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_hdbscan.md)
  assigns. Noise gets no label and does not count for the labels of the
  other clusters. `NULL` labels every id as a cluster; set it for
  clusterings that use another noise label or a real cluster 0.

- seed:

  Optional seed for sampling titles with a chat provider. The session
  random state is restored afterwards. `NULL` uses the session random
  stream as before. Used only by `method = "llm"`.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with two columns added to `corpus$works`, in place of
earlier ones:

- `cluster_label`:

  The terms of the work's cluster joined with `"; "`, the best first;
  `NA` for noise, for works without a cluster and for clusters that got
  no label.

- `cluster_label_basis`:

  How the label was made: `"tfidf"` or `"keywords"` when every term
  occurs in at least `min_works` of the cluster's works;
  `"tfidf (relaxed)"` or `"keywords (relaxed)"` when no term reached
  `min_works`, so that the terms occur in at least 2 works;
  `"tfidf (fallback)"` or `"tfidf (fallback, relaxed)"` when
  `method = "keywords"` found no keyword in 2 or more of the cluster's
  works and took the terms of its titles; `"yake"` or `"llm"` for these
  methods; `NA` where `cluster_label` is `NA`.

## Details

**Noise and clusters without a label**: works whose `cluster_id` is `NA`
or `noise` get no label from any method, and the `"tfidf"` and
`"keywords"` methods leave them out of the works that make a term common
or rare in the corpus. A cluster whose works share no term, such as a
cluster of a single work, gets no label either, with a message.

**TF-IDF method**: Splits the titles and abstracts of the works into
terms of `ngram` words. A term's score in a cluster is the share of the
cluster's works that contain it times `log(N / n)`, where `N` is the
number of clustered works and `n` the number of them that contain the
term. As the score counts works, not occurrences, and a term must occur
in at least `min_works` works of the cluster, a term that one paper
repeats cannot name a cluster. The `n_terms` terms with the highest
scores form the label; ties go to the term that occurs more often in the
cluster, then to the first in alphabetical order. A longer term takes
the place of a shorter one it contains when it occurs in at least 40% of
the shorter term's works ("cancer" gives way to "testicular cancer", and
to "metastatic testicular cancer" only if that also occurs in 40% of the
works with "cancer"), and a term contained in one already chosen is
skipped. When a term overlaps one already chosen, as "heat illness"
overlaps "exertional heat", the phrase they form ("exertional heat
illness") counts as a longer term that contains both, also beyond the
lengths in `ngram`, if it occurs in enough of the cluster's works to be
a term of the label; so one phrase does not fill two places of a label.

Words of fewer than 3 characters, numbers and stop words are left out,
and no term spans one of them, the end of a sentence or clause, or the
border between title and abstract. The stop words of every work are the
English ones of
[`tidytext::stop_words`](https://juliasilge.github.io/tidytext/reference/stop_words.html),
plus the Snowball list of the stopwords package for the work's own
language in `works$language`, given as a name such as `"German"`, an ISO
639-1 code such as `"de"` or an ISO 639-2 code such as `"ger"`. Works
without a language get the English list only, and the lists of other
languages are never pooled, so German stop words such as "war" or "die"
stay in English text. Without the stopwords package, or for a language
it has no list for, only the English list is used, with a message.

Singular and plural count as one term: a final "ies" becomes "y", and a
final "s" is dropped after a letter other than s, i, u, o, a and y, so
"fractures" counts with "fracture" and "ticks" with "tick", while
"diagnosis", "virus", "class" and "days" stay as they are. A possessive
"'s" is dropped as well, and words such as "species", "series",
"diabetes", "measles" or "aids" are kept as written, as are names of
fields such as "logistics", "genetics", "genomics" or "pediatrics",
which would otherwise count with the adjectives "logistic", "genetic",
"genomic" or "pediatric". A label shows each term in the spelling the
cluster's works use most often.

**Keyword method**: The same scoring on the author keywords and the
indexer keywords (such as Keywords Plus or MeSH) in `corpus$concepts`,
the families `"author_keyword"` and `"indexer_keyword"` of
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md).
Keywords are compared ignoring case, with hyphens read as spaces and
plurals folded as above, and containment is checked on whole words;
keywords that overlap form no phrase. A work counts once for each
keyword, however many of its vocabularies give it. A keyword is shown as
an author keyword spells it, or else in lower case. A cluster without a
keyword in at least 2 of its works gets the TF-IDF terms of its titles
instead; when the clustered works have no such keywords at all, every
cluster does, with a message.

**YAKE method**: Uses a simplified YAKE-like scoring based on term
frequency, position, and spread across works within each cluster, with
the stop words of the TF-IDF method.

**LLM method**: Sends titles and abstracts of each cluster to an LLM
with a prompt asking for a concise topical label. Requires the ellmer
package and a configured provider.

## See also

Other clustering:
[`sm_cluster_evolution()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_evolution.md),
[`sm_cluster_hdbscan()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_hdbscan.md),
[`sm_cluster_kmeans()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_kmeans.md),
[`sm_cluster_leiden()`](https://cttir.github.io/scimapR/dev/reference/sm_cluster_leiden.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus(with_embeddings = TRUE)
corpus <- sm_cluster_kmeans(corpus, k = 5)
#> ✔ K-means clustering complete.
#> ℹ 5 clusters, sizes range from 27 to 49.
corpus <- sm_cluster_label(corpus, method = "tfidf", n_terms = 3L)
#> ✔ 5 clusters labelled using "tfidf" method.
unique(corpus$works[, c("cluster_id", "cluster_label",
                        "cluster_label_basis")])
#> # A tibble: 5 × 3
#>   cluster_id cluster_label                                   cluster_label_basis
#>        <int> <chr>                                           <chr>              
#> 1          5 drug resistance; clinical outcomes; cross sect… tfidf              
#> 2          1 cohort study; investigates drug; machine learn… tfidf              
#> 3          3 meta analysis; spatial transcriptomics; prospe… tfidf              
#> 4          4 meta analysis; investigates spatial transcript… tfidf              
#> 5          2 trial approaches; cross sectional study; immun… tfidf              

# keyword labels: the real-use example corpus grouped by journal category
fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
fix$works$cluster_id <- match(fix$works$field, unique(fix$works$field))
fix <- sm_cluster_label(fix, method = "keywords", n_terms = 3L)
#> ✔ 8 clusters labelled using "keywords" method.
unique(fix$works[, c("field", "cluster_label", "cluster_label_basis")])
#> # A tibble: 8 × 3
#>   field                                       cluster_label  cluster_label_basis
#>   <chr>                                       <chr>          <chr>              
#> 1 Microbiology                                transmission;… keywords           
#> 2 Medicine, General & Internal                injury; hemor… keywords           
#> 3 Public, Environmental & Occupational Health zoonotic surv… keywords           
#> 4 Infectious Diseases                         antibodies; o… keywords           
#> 5 Toxicology                                  workforce; ed… keywords           
#> 6 Physiology                                  recruits; exe… keywords           
#> 7 Surgery                                     hemorrhage co… keywords           
#> 8 Emergency Medicine                          damage contro… keywords           
# }
```

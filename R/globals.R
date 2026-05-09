# Global variables used in NSE contexts (dplyr, ggplot2, etc.)
# Declared here to avoid R CMD check NOTEs about "no visible binding"
utils::globalVariables(c(

  # works table
  "work_id", "doi", "title", "abstract", "year", "type", "source_id",
  "cited_by_count", "oa_status", "language", "pmid", "arxiv_id",
  "openalex_id", "is_retracted", "retraction_date", "last_refreshed",


  # authors table
  "author_id", "orcid", "display_name", "display_name_alternatives",
  "inferred_gender", "gender_confidence", "gender_method",

  # authorships table
  "position", "is_corresponding", "institution_id", "raw_affiliation",
  "country_code",

  # institutions table
  "ror", "region", "income_tier",

  # sources table
  "issn_l", "issn", "is_oa", "publisher", "publisher_country",

  # references table
  "ref_index", "cited_work_id", "cited_doi", "cited_raw",

  # concepts table
  "concept_id", "concept_name", "level", "score", "vocabulary",

  # provenance table
  "source", "source_id_external", "fetch_date", "query", "engine",
  "scimapR_version", "prompt_hash",

  # screening table
  "stage", "decision", "reason", "confidence", "decided_at",

  # network / metric columns
  "weight", "name", "label", "from", "to", "n", "value", "metric",
  "cluster_id", "x", "y",

  # trajectory
  "period", "year_range", "n_works", "dominant_topics", "pivot_score",
  "from_topic", "to_topic", "jaccard_to_prev", "n_new", "n_kept",

  "n_lost", "h_index", "mean_novelty", "mean_citations",
  "delta_vs_field", "first_year",

  # audit
  "country", "count", "pct", "citations",
  "group", "funder_name", "funder_doi", "n_works_funded",
  "position_type",

  # network building
  "cited_work_id_2", "work_id_2", "entity", "entity_2", "term_2",
  "ref_source", "ref_source_2", "a", "b",

  # embeddings / clustering
  "text", "word", "spread",

  # metrics
  "expected_rate", "rcr", "field", "field_mean", "fnci",
  "cd_index", "novelty", "z_score", "observed", "expected",
  "p1", "p2", "marginal", "marginal_2",
  "career_years", "m_index", "g_index",
  "n_authors", "n_countries", "n_institutions",
  "is_international", "is_multi_authored",
  "cluster_label", "window", "citer", "focal", "ref",

  # summary
  "n_oa", "pct_oa", "n_with_orcid", "pct_orcid",
  "mean_authors_per_work",

  # general
  ".", "V1", "V2", "desc", "term", "freq", "tf_idf",
  "total", "proportion"
))

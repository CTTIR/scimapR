# Enrich corpus with SPECTER embeddings

Fetch pre-computed SPECTER v2 embeddings from the [Semantic
Scholar](https://www.semanticscholar.org/) API for works in the corpus
and attach them as the `embeddings` matrix.

SPECTER embeddings are 768-dimensional vectors useful for computing
document similarity, clustering, and visualisation. No Python
installation is required – this function retrieves pre-computed vectors
from the API.

This enricher is idempotent: works that already have embeddings from the
same source are skipped, so a second call fills only the gaps.

## Usage

``` r
sm_enrich_specter(
  corpus,
  api_key = Sys.getenv("SEMANTIC_SCHOLAR_API_KEY"),
  replace = FALSE,
  mix_models = FALSE,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- api_key:

  Semantic Scholar API key. Read from `SEMANTIC_SCHOLAR_API_KEY` env var
  by default.

- replace:

  Logical; replace existing embeddings of another model (or of an
  unrecorded one) by SPECTER v2 vectors? Defaults to `FALSE`. See
  Details.

- mix_models:

  Logical; keep existing embeddings of another model (or of an
  unrecorded one) and add SPECTER v2 vectors for the other works?
  Defaults to `FALSE`. See Details.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object with an `embeddings` matrix, its record in
`metadata$embedding`, plus new provenance rows of the kind
`"enrichment"`, which
[`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
does not replay.

## Details

The function asks Semantic Scholar for its SPECTER v2 vectors (the API
field `embedding.specter_v2`; the API's default is SPECTER v1) and
records them in `corpus$metadata$embedding` (see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md))
with the model id `"embedding.specter_v2"` and, as `revision`, the model
version that Semantic Scholar reports. Semantic Scholar does not say
which revision of the model or which text it used, so these vectors
count as a model of their own, also next to embeddings from
`sm_embed_works(model = "specter2")`.

A corpus that already has embeddings of another model, or of a model
that is not recorded (such as embeddings made by earlier versions of
scimapR), would get a matrix whose rows come from two models, and
similarities between such rows mean nothing. The function therefore
stops (class `scimapR_embedding_model_mismatch`) unless you choose:
`replace = TRUE` discards the existing embeddings, with a message, and
fetches SPECTER v2 vectors for every work with a DOI;
`mix_models = TRUE` keeps them and adds SPECTER v2 vectors for the works
without an embedding, and the record then names the model `"mixed"`. A
mix needs embeddings of the same width.

Requests go out in batches of 100 DOIs. A batch that Semantic Scholar
answers with HTTP 429 (too many requests) is tried once more after a
short wait; a batch that still fails is skipped, and one warning (class
`scimapR_specter_failed`) gives the number of failed batches.

## See also

Other enrichers:
[`sm_enrich_altmetric()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_altmetric.md),
[`sm_enrich_concepts()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_concepts.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md),
[`sm_enrich_opencitations()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_opencitations.md),
[`sm_enrich_orcid()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_orcid.md),
[`sm_enrich_retraction()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_retraction.md),
[`sm_enrich_ror()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_ror.md),
[`sm_enrich_unpaywall()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_unpaywall.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus(with_embeddings = FALSE)
corpus <- sm_enrich_specter(corpus)
corpus$metadata$embedding$model_id

# a corpus with embeddings of another model
corpus <- sm_embed_works(corpus, model = "mpnet")
corpus <- sm_enrich_specter(corpus, replace = TRUE)
} # }
```

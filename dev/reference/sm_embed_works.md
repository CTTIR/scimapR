# Compute work embeddings using transformer models

Generates dense vector embeddings for works in an `sm_corpus` using
pretrained transformer models in Python. The default model, `specter2`,
loads the SPECTER2 adapter with the Python package `adapters`; the other
models load with `sentence-transformers`. Requires reticulate and a
Python installation with the packages the chosen model needs.

## Usage

``` r
sm_embed_works(
  corpus,
  model = c("specter2", "scincl", "scibert", "minilm-l6", "mpnet", "multilingual-mpnet",
    "multilingual-e5"),
  text = c("title_abstract", "title", "abstract"),
  batch_size = 32L,
  cache_dir = tools::R_user_dir("scimapR", "cache"),
  python = NULL,
  install_deps = FALSE,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object.

- model:

  Character; the embedding model to use. One of `"specter2"` (default,
  optimised for scientific text), `"scincl"`, `"scibert"`, `"minilm-l6"`
  and `"mpnet"`, which are trained on English text, or
  `"multilingual-mpnet"` and `"multilingual-e5"`, which place works of
  many languages in one space. See Details.

- text:

  Character; which text field(s) to embed. One of `"title_abstract"`
  (default, title and abstract together), `"title"`, or `"abstract"`.

- batch_size:

  Integer; batch size for the transformer model. Defaults to `32L`.

- cache_dir:

  Character; directory to cache downloaded models. Defaults to the
  scimapR user cache directory.

- python:

  Character or `NULL`; path to the Python executable. If `NULL`, uses
  reticulate's default Python.

- install_deps:

  Logical; if `TRUE`, install the Python packages the chosen model needs
  with pip first: `torch` and `adapters` (which brings `transformers`)
  for `"specter2"`, `sentence-transformers` for the other models.
  Defaults to `FALSE`.

- verbose:

  Logical; if `TRUE`, print progress messages.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with `corpus$embeddings` replaced by a numeric matrix
with one row per embedded work and one column per dimension, and with
`corpus$metadata$embedding` recording the model. Row names are the
`work_id`s of the embedded works: every work that has text to embed (see
Details).

## Details

Models and their Hugging Face models:

- `"specter2"`: `allenai/specter2`, an adapter on
  `allenai/specter2_base`;

- `"scincl"`: `malteos/scincl`;

- `"scibert"`: `allenai/scibert_scivocab_uncased`;

- `"minilm-l6"`: `sentence-transformers/all-MiniLM-L6-v2`;

- `"mpnet"`: `sentence-transformers/all-mpnet-base-v2`;

- `"multilingual-mpnet"`:
  `sentence-transformers/paraphrase-multilingual-mpnet-base-v2`, trained
  on more than 50 languages;

- `"multilingual-e5"`: `intfloat/multilingual-e5-base`, trained on about
  100 languages.

The first five are trained on English text. `"specter2"` loads with the
Python package `adapters`, the others with `sentence-transformers`.

`"specter2"` follows its model card: the base model with the proximity
adapter, title and abstract joined by the separator token `[SEP]`
without spaces, at most 512 tokens, and the first token of the last
layer as the embedding. It needs the Python packages `torch`,
`transformers` and `adapters`; the other models need
`sentence-transformers`. A missing package stops the function with an
error naming it, and so does a model that does not load; it never falls
back to another model.

The other models join title and abstract with a space. For
`"multilingual-e5"` every text starts with `"query: "`, the prefix its
model card gives for clustering and for using the embeddings as
features; its embeddings have unit length. `"multilingual-mpnet"` reads
at most 128 tokens, so it sees the title and the start of a long
abstract only. `"scibert"` has no sentence-transformers configuration,
so sentence-transformers averages its token vectors, with a warning.

When more than 10% of the works with a known language (`works$language`:
names such as `"German"`, ISO 639-1 codes such as `"de"` or ISO 639-2
codes such as `"ger"`) are not in English and an English-only model is
chosen, a message (class `scimapR_embed_multilingual`) suggests a
multilingual model; it changes nothing else.

Works without text to embed (with `"title_abstract"` neither a title nor
an abstract, with `"title"` or `"abstract"` no such field; blank text
counts as none) would all get the same vector and become each other's
nearest neighbours. They are left out, with one warning (class
`scimapR_embed_no_text`) giving their number: they get no row in
`corpus$embeddings`, so the clustering functions give them no cluster
(`NA`), and
[`sm_network_semantic()`](https://cttir.github.io/scimapR/dev/reference/sm_network_semantic.md)
and
[`sm_plot_landscape()`](https://cttir.github.io/scimapR/dev/reference/sm_plot_landscape.md)
leave them out, as they do for works missing from a cache loaded with
[`sm_embed_load()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_load.md).

`corpus$metadata$embedding` records what produced the embeddings: the
model, its Hugging Face id and, when the local model snapshot in
`cache_dir` shows it, its revision, the text used, the input prefix and
the versions of the Python packages (see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)).
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
reports it in `embedding_info`.

Python and its packages are soft dependencies (reticulate is in
Suggests). If they are unavailable, the function aborts with an
informative message.

## See also

Other embedding:
[`sm_embed_load()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_load.md),
[`sm_embed_save()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_save.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus(with_embeddings = FALSE)
corpus <- sm_embed_works(corpus, model = "minilm-l6")
dim(corpus$embeddings)
corpus$metadata$embedding$model_id

# a corpus with works in several languages
corpus <- sm_embed_works(corpus, model = "multilingual-mpnet")
} # }
```

# Compute work embeddings using transformer models

Generates dense vector embeddings for works in an `sm_corpus` using
pretrained transformer models via Python's `sentence-transformers`
library. Requires reticulate and a working Python installation with
`sentence-transformers` installed.

## Usage

``` r
sm_embed_works(
  corpus,
  model = c("specter2", "scincl", "scibert", "minilm-l6", "mpnet"),
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
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object.

- model:

  Character; the embedding model to use. One of `"specter2"` (default,
  optimised for scientific text), `"scincl"`, `"scibert"`,
  `"minilm-l6"`, or `"mpnet"`.

- text:

  Character; which text field(s) to embed. One of `"title_abstract"`
  (default, concatenates title and abstract), `"title"`, or
  `"abstract"`.

- batch_size:

  Integer; batch size for the transformer model. Defaults to `32L`.

- cache_dir:

  Character; directory to cache downloaded models. Defaults to the
  scimapR user cache directory.

- python:

  Character or `NULL`; path to the Python executable. If `NULL`, uses
  reticulate's default Python.

- install_deps:

  Logical; if `TRUE`, attempt to install `sentence-transformers` into
  the Python environment. Defaults to `FALSE`.

- verbose:

  Logical; if `TRUE`, print progress messages.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with `corpus$embeddings` replaced by a numeric matrix
of shape `(n_works, embedding_dim)`. Row names are set to `work_id`.

## Details

Model name mapping:

- `"specter2"` -\> `"allenai/specter2"`

- `"scincl"` -\> `"malteos/scincl"`

- `"scibert"` -\> `"allenai/scibert_scivocab_uncased"`

- `"minilm-l6"` -\> `"sentence-transformers/all-MiniLM-L6-v2"`

- `"mpnet"` -\> `"sentence-transformers/all-mpnet-base-v2"`

Python and `sentence-transformers` are soft dependencies (in Suggests).
If unavailable, the function aborts with an informative message.

## See also

Other embedding:
[`sm_embed_load()`](https://r-heller.github.io/scimapR/reference/sm_embed_load.md),
[`sm_embed_save()`](https://r-heller.github.io/scimapR/reference/sm_embed_save.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus(with_embeddings = FALSE)
corpus <- sm_embed_works(corpus, model = "minilm-l6")
dim(corpus$embeddings)
} # }
```

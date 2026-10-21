# Load embeddings from disk

Loads a previously saved embeddings matrix from an RDS file and attaches
it to the corpus. Only embeddings for works present in the corpus are
loaded; mismatches are reported.

The loaded embeddings replace any the corpus had, and so does the record
of their model (`corpus$metadata$embedding`, see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)):
the cache's record when it describes the cached matrix, else none, so
the model of embeddings from an older cache or a bare matrix counts as
not recorded (`"unknown"` in
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)).

## Usage

``` r
sm_embed_load(corpus, path, call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
  object.

- path:

  Character; file path to read embeddings from (an `.rds` file created
  by
  [`sm_embed_save()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_save.md)).

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with `corpus$embeddings` and
`corpus$metadata$embedding` updated. Works without a cached row get no
row, so the clustering functions give them no cluster (`NA`).

## See also

Other embedding:
[`sm_embed_save()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_save.md),
[`sm_embed_works()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_works.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus(with_embeddings = FALSE)
corpus <- sm_embed_load(corpus, "my_embeddings.rds")
dim(corpus$embeddings)
} # }
```

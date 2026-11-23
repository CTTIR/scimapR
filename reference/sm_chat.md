# Retrieval-grounded corpus chat

Ask a question of a corpus using retrieval-augmented generation (RAG).
The function retrieves the most relevant works from the corpus using
embeddings, TF-IDF, or a hybrid method, then sends them as context to a
chat provider along with the user's question. The response includes
inline citations keyed to work IDs. Citations are checked against the
retrieved works: a cited ID that was not sent as context is not
reported, so every reported citation is a real work of the corpus. Work
IDs of any form are recognised (for example OpenAlex `W123` or Web of
Science `WOS:000123`), also IDs that contain commas or semicolons; a
token may list several IDs separated by commas or semicolons
(`[cite:W1; W2]`). Only text in a `[cite:...]` token counts as a
citation, and an ID cannot contain `]`.

## Usage

``` r
sm_chat(
  corpus,
  question,
  provider = NULL,
  retrieve_n = 30L,
  retrieve_method = c("embedding", "tfidf", "hybrid"),
  cite = TRUE,
  max_tokens = lifecycle::deprecated(),
  temperature = lifecycle::deprecated(),
  call = rlang::caller_env()
)

# S3 method for class 'sm_chat_response'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- question:

  Character. The user's question in natural language.

- provider:

  An ellmer chat provider object (e.g., from
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html)).
  If `NULL`, errors informatively. Each request runs in a fresh copy:
  the object passed is unchanged, and its earlier turns and system
  prompt are not used.

- retrieve_n:

  Integer. Number of works to retrieve as context. Default `30`.

- retrieve_method:

  Character. Retrieval method:

  - `"embedding"`: cosine similarity on `corpus$embeddings`.

  - `"tfidf"`: TF-IDF on titles and abstracts.

  - `"hybrid"`: weighted average of both methods.

- cite:

  Logical. If `TRUE`, the prompt asks the chat provider for inline
  citations using work IDs.

- max_tokens, temperature:

  Deprecated; these arguments never affected requests. Set response
  parameters on the chat object instead.

- call:

  Caller environment for error reporting.

- x:

  An `sm_chat_response` object.

- ...:

  Ignored.

## Value

An `sm_chat_response` S3 object with fields:

- answer:

  Character. The chat provider's response.

- citations:

  Tibble of cited work IDs and their details.

- retrieved_works:

  Tibble of the works sent as context.

- prompt_hash:

  SHA-256 hash of the full prompt for reproducibility.

- model:

  Character. The model used.

- timestamp:

  POSIXct. When the response was generated.

- question:

  The original question.

- retrieve_method:

  The retrieval method used.

## See also

Other chat:
[`sm_chat_render()`](https://cttir.github.io/scimapR/reference/sm_chat_render.md)

## Examples

``` r
# \donttest{
# Sends retrieved titles and abstracts to a chat provider; runs only with
# the 'ellmer' package and an OpenAI API key in OPENAI_API_KEY.
if (requireNamespace("ellmer", quietly = TRUE) &&
    nzchar(Sys.getenv("OPENAI_API_KEY")) &&
    requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- sm_example_corpus()
  response <- try(sm_chat(corpus, "What methods dominate?",
                          provider = ellmer::chat_openai()))
  response
}
# }
```

# Retrieval-grounded corpus chat

Ask a question of a corpus using retrieval-augmented generation (RAG).
The function retrieves the most relevant works from the corpus using
embeddings, TF-IDF, or a hybrid method, then sends them as context to an
LLM along with the user's question. The response includes inline
citations keyed to work IDs. No hallucinated references are possible
because citations are constrained to retrieved works.

## Usage

``` r
sm_chat(
  corpus,
  question,
  provider = NULL,
  retrieve_n = 30L,
  retrieve_method = c("embedding", "tfidf", "hybrid"),
  cite = TRUE,
  max_tokens = 2000L,
  temperature = 0.2,
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
  If `NULL`, errors informatively.

- retrieve_n:

  Integer. Number of works to retrieve as context. Default `30`.

- retrieve_method:

  Character. Retrieval method:

  - `"embedding"`: cosine similarity on `corpus$embeddings`.

  - `"tfidf"`: TF-IDF on titles and abstracts.

  - `"hybrid"`: weighted average of both methods.

- cite:

  Logical. If `TRUE`, the prompt instructs the LLM to include inline
  citations using work IDs.

- max_tokens:

  Integer. Maximum tokens for the LLM response.

- temperature:

  Numeric. LLM temperature (0 = deterministic).

- call:

  Caller environment for error reporting.

- x:

  An `sm_chat_response` object.

- ...:

  Ignored.

## Value

An `sm_chat_response` S3 object with fields:

- answer:

  Character. The LLM's response.

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
if (FALSE) { # \dontrun{
# Requires ellmer package and LLM API access:
# response <- sm_chat(corpus, "What methods dominate?",
#                     provider = ellmer::chat_openai())
} # }
```

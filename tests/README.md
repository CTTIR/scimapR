# Tests

The tests run offline. Code that calls web services is tested with saved
answers (httptest2 fixtures or mocked httr2 functions), and code that runs
Python is tested with mocked reticulate functions or with mocks of the
package's own Python steps, so no Python is needed.

## Live Python smoke tests

`tests/testthat/test-embed-works.R` ends with two smoke tests that load
real embedding models in Python: `specter2`, which needs the Python
packages `torch`, `transformers` and `adapters`, and `multilingual-mpnet`,
which needs `sentence-transformers`. They download the models from Hugging
Face, so they run only when the environment variable
`SCIMAPR_LIVE_PYTHON_TESTS` is `true`:

```sh
SCIMAPR_LIVE_PYTHON_TESTS=true Rscript -e 'devtools::test(filter = "embed-works")'
```

Point reticulate at the Python that has these packages with
`RETICULATE_PYTHON`. The tests are also skipped on CRAN, offline, without
reticulate and when the Python package of the model is missing.

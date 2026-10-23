# Tests for R/chat-render.R (sm_chat_render) -- pure string formatting.

# Build a minimal sm_chat_response without invoking any LLM.
make_response <- function(with_citations = TRUE) {
  citations <- if (with_citations) {
    tibble::tibble(
      cite_token = c("[cite:W000000001]", "[cite:W000000002]"),
      work_id = c("W000000001", "W000000002"),
      snippet = c("First cited title", "Second cited title")
    )
  } else {
    tibble::tibble(cite_token = character(), work_id = character(),
                   snippet = character())
  }
  structure(
    list(
      answer = paste0("The dominant method is X [cite:W000000001]\n",
                      "and Y [cite:W000000002]."),
      citations = citations,
      retrieved_works = tibble::tibble(work_id = paste0("W", 1:5)),
      question = "What methods dominate?",
      model = "test-model",
      prompt_hash = "abcdef0123456789",
      timestamp = as.POSIXct("2024-01-02 03:04:05", tz = "UTC"),
      retrieve_method = "tfidf"
    ),
    class = "sm_chat_response"
  )
}

quiet_render <- function(...) {
  withr::with_options(
    list(cli.default_handler = function(msg) invisible(NULL)),
    sm_chat_render(...)
  )
}

test_that("sm_chat_render rejects non-response objects", {
  expect_error(sm_chat_render(list()), "sm_chat_response")
})

test_that("sm_chat_render validates the format argument", {
  resp <- make_response()
  expect_error(quiet_render(resp, format = "pdf"), class = "error")
})

test_that("markdown render replaces cite tokens and lists references", {
  resp <- make_response(with_citations = TRUE)
  out <- quiet_render(resp, format = "markdown")
  expect_type(out, "character")
  expect_match(out, "## Corpus Chat", fixed = TRUE)
  expect_match(out, "### Answer", fixed = TRUE)
  expect_match(out, "### References", fixed = TRUE)
  # Cite tokens replaced with bold work-id references; raw token gone.
  expect_false(grepl("[cite:W000000001]", out, fixed = TRUE))
  expect_match(out, "**[W000000001]**", fixed = TRUE)
  expect_match(out, "First cited title", fixed = TRUE)
  expect_match(out, "What methods dominate?", fixed = TRUE)
  expect_match(out, substr(resp$prompt_hash, 1, 12), fixed = TRUE)
})

test_that("markdown render omits references when there are none", {
  resp <- make_response(with_citations = FALSE)
  out <- quiet_render(resp, format = "markdown")
  expect_false(grepl("### References", out, fixed = TRUE))
  # Tokens remain literal since there are no citations to substitute.
  expect_match(out, "## Corpus Chat", fixed = TRUE)
})

test_that("html render produces a chat div with tooltip sups", {
  resp <- make_response(with_citations = TRUE)
  out <- quiet_render(resp, format = "html")
  expect_match(out, '<div class="sm-chat-response">', fixed = TRUE)
  expect_match(out, "<h3>References</h3>", fixed = TRUE)
  expect_match(out, "<sup", fixed = TRUE)
  expect_false(grepl("[cite:W000000001]", out, fixed = TRUE))
  expect_match(out, "<br>", fixed = TRUE)
})

test_that("html render escapes double quotes in snippets", {
  resp <- make_response(with_citations = TRUE)
  resp$citations$snippet[1] <- 'A "quoted" title'
  out <- quiet_render(resp, format = "html")
  expect_match(out, "&quot;quoted&quot;", fixed = TRUE)
})

test_that("quarto render: the .render_chat_quarto string builder is correct", {
  resp <- make_response(with_citations = TRUE)
  out <- scimapR:::.render_chat_quarto(resp$answer, resp$citations, resp)
  expect_match(out, 'title: "Corpus Chat Response"', fixed = TRUE)
  expect_match(out, "::: {.callout-note}", fixed = TRUE)
  expect_match(out, "## References", fixed = TRUE)
  expect_match(out, "Reproducibility", fixed = TRUE)
  expect_false(grepl("[cite:W000000002]", out, fixed = TRUE))
})

test_that("quarto output prints literal callout markup", {
  resp <- make_response(with_citations = TRUE)
  printed <- cli::cli_fmt(out <- sm_chat_render(resp, format = "quarto"))
  expect_match(out, "::: {.callout-note}", fixed = TRUE)
  expect_true(any(grepl("::: {.callout-note}", printed, fixed = TRUE)))
})

test_that("sm_chat_render returns its string invisibly", {
  resp <- make_response()
  out <- withr::with_options(
    list(cli.default_handler = function(msg) invisible(NULL)),
    expect_invisible(sm_chat_render(resp, format = "markdown"))
  )
  expect_type(out, "character")
})


test_that("markdown output preserves literal braces", {
  resp <- make_response()
  resp$answer <- "{T}he effect {stop('evaluated')}"
  resp$citations$snippet[1] <- "The {CRISPR} screen"
  printed <- paste(cli::cli_fmt(sm_chat_render(resp)), collapse = "\n")
  expect_match(printed, resp$answer, fixed = TRUE)
  expect_match(printed, resp$citations$snippet[1], fixed = TRUE)
})

test_that("HTML escapes every data field while retaining generated markup", {
  resp <- make_response()
  resp$answer <- "<img src=x onerror=alert(1)>\n[cite:W000000001]"
  resp$citations$snippet[1] <- "E. coli & CO<sub>2</sub>"
  resp$question <- "<question> & 'quoted'"
  resp$model <- '<model "x">'
  resp$citations$work_id[1] <- '<work "x">'
  out <- quiet_render(resp, format = "html")
  for (literal in c("&lt;img", "&amp;", "&lt;sub&gt;", "&#39;",
                    "&lt;model &quot;x&quot;&gt;", "&lt;work &quot;x&quot;&gt;",
                    "<br>", "<sup")) {
    expect_match(out, literal, fixed = TRUE)
  }
  expect_false(grepl("<img src=x", out, fixed = TRUE))
})

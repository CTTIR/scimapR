fake_chat <- function(respond, model = "fake-model", log = new.env()) {
  if (is.null(log$calls)) log$calls <- list()
  ch <- new.env(parent = emptyenv())
  ch$turns <- list()
  ch$system_prompt <- ""
  ch$log <- log
  ch$clone <- function() {
    copy <- fake_chat(respond, model, log)
    copy$turns <- ch$turns
    copy$system_prompt <- ch$system_prompt
    copy
  }
  ch$set_turns <- function(turns) ch$turns <- turns
  ch$get_turns <- function() ch$turns
  ch$set_system_prompt <- function(prompt) ch$system_prompt <- prompt
  ch$get_system_prompt <- function() ch$system_prompt
  ch$get_model <- function() model
  ch$chat <- function(..., echo = NULL) {
    args <- list(...)
    arg_names <- names(args) %||% rep("", length(args))
    text <- args[[which(arg_names == "")[1]]]
    log$calls[[length(log$calls) + 1L]] <- list(
      arg_names = arg_names, n_args = length(args),
      n_turns = length(ch$turns), system_prompt = ch$system_prompt,
      user_text = text, echo = echo
    )
    out <- respond(text)
    ch$turns <- c(ch$turns, list(text, out))
    out
  }
  ch
}

prompt_work_ids <- function(user_text) {
  json <- regmatches(user_text, regexpr("(?s)\\[.*\\]", user_text,
                                        perl = TRUE))
  items <- jsonlite::parse_json(json, simplifyVector = FALSE)
  vapply(items, function(item) item$work_id, character(1))
}

fake_provider <- function(model = "test-model") {
  fake_chat(function(x) "should-not-be-called", model = model)
}

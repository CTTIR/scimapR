# Internal chat-provider helpers.
.check_llm_available <- function(call = rlang::caller_env()) {
  rlang::check_installed("ellmer",
    reason = "for chat-provider screening, chat and cluster labelling",
    call = call
  )
}

.check_chat_provider <- function(provider, arg = rlang::caller_arg(provider),
                                 call = rlang::caller_env()) {
  methods <- c("clone", "set_turns", "set_system_prompt", "chat")
  valid <- vapply(methods, function(name) {
    tryCatch(is.function(provider[[name]]), error = function(e) FALSE)
  }, logical(1))
  if (!all(valid)) {
    cli::cli_abort(
      paste0("{.arg {arg}} must be a chat object such as ",
             "{.code ellmer::chat_openai()}."),
      class = "scimapR_chat_provider_invalid", call = call
    )
  }
  invisible(provider)
}

.llm_fresh_chat <- function(provider, system_prompt,
                            call = rlang::caller_env()) {
  .check_chat_provider(provider, call = call)
  ch <- provider$clone()
  ch$set_turns(list())
  ch$set_system_prompt(system_prompt)
  ch
}

.llm_chat <- function(provider, system_prompt, user_prompt,
                      call = rlang::caller_env()) {
  .check_llm_available(call = call)
  ch <- .llm_fresh_chat(provider, system_prompt, call = call)
  out <- ch$chat(user_prompt, echo = "none")
  paste(as.character(unclass(out)), collapse = "\n")
}

.llm_model_name <- function(provider) {
  scalar <- function(x) is.character(x) && length(x) == 1L && !is.na(x)
  tryCatch({
    name <- tryCatch({
      if (is.function(provider$get_model)) provider$get_model()
    }, error = function(e) NULL)
    if (scalar(name)) return(name)
    if (scalar(provider$model)) provider$model else "unknown"
  }, error = function(e) "unknown")
}

.hash_prompt <- function(prompt) {
  digest::digest(prompt, algo = "sha256", serialize = FALSE)
}

.with_preserved_seed <- function(seed, code) {
  if (is.null(seed)) return(force(code))
  rng_env <- globalenv()
  old <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv())
  }
  on.exit({
    if (is.null(old)) {
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(list = ".Random.seed", envir = globalenv())
      }
    } else {
      rng_env[[".Random.seed"]] <- old
    }
  }, add = TRUE)
  set.seed(seed)
  force(code)
}

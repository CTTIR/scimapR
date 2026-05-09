# Internal LLM helpers (provider-agnostic wrapping via ellmer)

.check_llm_available <- function(call = rlang::caller_env()) {
  rlang::check_installed("ellmer",
    reason = "for LLM-powered features (screening, chat, cluster labelling)",
    call = call
  )
}

.llm_chat <- function(provider, system_prompt, user_prompt,
                      call = rlang::caller_env()) {
  .check_llm_available(call = call)
  chat <- provider$chat(user_prompt, system_prompt = system_prompt)
  chat
}

.hash_prompt <- function(prompt) {
  digest::digest(prompt, algo = "sha256", serialize = FALSE)
}

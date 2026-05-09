# Internal ID generation helpers

.generate_work_id <- function(n = 1L) {
  paste0("W", formatC(seq_len(n), width = 9, flag = "0"))
}

.generate_author_id <- function(n = 1L) {
  paste0("A", formatC(seq_len(n), width = 9, flag = "0"))
}

.generate_institution_id <- function(n = 1L) {
  paste0("I", formatC(seq_len(n), width = 9, flag = "0"))
}

.generate_source_id <- function(n = 1L) {
  paste0("S", formatC(seq_len(n), width = 9, flag = "0"))
}

.make_work_id <- function(prefix = "W", existing_ids = character()) {
  max_num <- 0L
  if (length(existing_ids) > 0) {
    nums <- suppressWarnings(
      as.integer(sub("^[A-Z]", "", existing_ids))
    )
    nums <- nums[!is.na(nums)]
    if (length(nums) > 0) max_num <- max(nums)
  }
  paste0(prefix, formatC(max_num + 1L, width = 9, flag = "0"))
}

.normalize_doi <- function(doi) {
  if (is.null(doi)) return(NA_character_)
  doi <- trimws(doi)
  doi <- sub("^https?://doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- sub("^https?://dx\\.doi\\.org/", "", doi, ignore.case = TRUE)
  doi <- sub("^doi:\\s*", "", doi, ignore.case = TRUE)
  ifelse(nzchar(doi), tolower(doi), NA_character_)
}

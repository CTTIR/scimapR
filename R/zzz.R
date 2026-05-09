.onLoad <- function(libname, pkgname) {
  op <- options()
  op_scimapr <- list(
    scimapR.mailto = Sys.getenv("SCIMAPR_MAILTO", ""),
    scimapR.verbose = TRUE,
    scimapR.cache_dir = tools::R_user_dir("scimapR", "cache"),
    scimapR.shiny_corpus = NULL
  )
  toset <- !(names(op_scimapr) %in% names(op))
  if (any(toset)) options(op_scimapr[toset])

  invisible()
}

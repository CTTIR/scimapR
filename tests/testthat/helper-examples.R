# Helper: the example code of an Rd topic, parsed the way R CMD check
# --as-cran runs it (\donttest code included, \dontrun code commented out).
# Reads man/ in a source checkout and the installed help otherwise.
rd_example_exprs <- function(topic) {
  rd_name <- paste0(topic, ".Rd")
  rd_file <- testthat::test_path("..", "..", "man", rd_name)
  rd <- if (file.exists(rd_file)) {
    tools::parse_Rd(rd_file)
  } else {
    tryCatch(tools::Rd_db("scimapR")[[rd_name]], error = function(e) NULL)
  }
  testthat::skip_if(is.null(rd), paste("No Rd source found for", topic))
  out <- tempfile(fileext = ".R")
  on.exit(unlink(out), add = TRUE)
  tools::Rd2ex(rd, out, commentDontrun = TRUE, commentDonttest = FALSE)
  parse(out, keep.source = FALSE)
}

# Helper: evaluate parsed example code quietly in a fresh environment.
# R CMD check runs examples non-interactively, so interactive() is FALSE
# for the example code here as well: @examplesIf interactive() blocks are
# skipped even when the tests run in an interactive session.
run_example_exprs <- function(exprs, parent = globalenv()) {
  env <- new.env(parent = parent)
  env$interactive <- function() FALSE
  suppressMessages(utils::capture.output(
    for (e in exprs) eval(e, envir = env)
  ))
  invisible(env)
}

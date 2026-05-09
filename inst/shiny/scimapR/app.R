# scimapR Shiny Application
# Launched via scimapR::sm_run_app()

# When run from an installed package, scimapR is already loadable.
# When run during development, pkgload::load_all() is used as fallback.
if (!requireNamespace("scimapR", quietly = TRUE)) {
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(
      path = system.file(package = "scimapR") |> dirname() |> dirname(),
      export_all = FALSE,
      helpers = FALSE,
      quiet = TRUE
    )
  }
}

source("global.R", local = TRUE)

ui <- source("ui.R", local = TRUE)$value
server <- source("server.R", local = TRUE)$value

shiny::shinyApp(ui = ui, server = server)

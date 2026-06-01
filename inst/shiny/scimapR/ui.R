# ui.R -- scimapR Shiny application UI
# Returns a bslib page_navbar with 16 tabs.

sm_theme <- bslib::bs_theme(
  version    = 5,
  bootswatch = "default",
  primary    = "#5E2C8E",
  "navbar-bg" = "#fafafa",
  base_font  = bslib::font_google("Inter", wght = "300..700"),
  code_font  = bslib::font_google("JetBrains Mono"),
  heading_font = bslib::font_google("Inter", wght = "300..700")
)

bslib::page_navbar(
  title = shiny::tags$span(
    shiny::tags$strong("scimapR"),
    style = "letter-spacing: 0.5px;"
  ),
  id        = "main_nav",
  theme     = sm_theme,
  fillable  = TRUE,
  header    = shiny::tags$head(
    shiny::tags$link(rel = "stylesheet", href = "custom.css")
  ),

  # -- 1. Overview -------------------------------------------------------------
  bslib::nav_panel(
    title = "Overview",
    icon  = fontawesome::fa_i("chart-line"),
    bslib::layout_columns(
      col_widths = c(3, 3, 3, 3),
      bslib::value_box(
        title    = "Works",
        value    = shiny::textOutput("vb_works", inline = TRUE),
        showcase = fontawesome::fa_i("file-lines"),
        theme    = "primary"
      ),
      bslib::value_box(
        title    = "Authors",
        value    = shiny::textOutput("vb_authors", inline = TRUE),
        showcase = fontawesome::fa_i("users"),
        theme    = "primary"
      ),
      bslib::value_box(
        title    = "Sources",
        value    = shiny::textOutput("vb_sources", inline = TRUE),
        showcase = fontawesome::fa_i("book"),
        theme    = "primary"
      ),
      bslib::value_box(
        title    = "Year Range",
        value    = shiny::textOutput("vb_years", inline = TRUE),
        showcase = fontawesome::fa_i("calendar"),
        theme    = "primary"
      )
    ),
    bslib::layout_columns(
      col_widths = c(8, 4),
      bslib::card(
        bslib::card_header("Annual Scientific Production"),
        bslib::card_body(
          shiny::plotOutput("overview_production", height = "400px")
        )
      ),
      bslib::card(
        bslib::card_header("Top 10 Sources"),
        bslib::card_body(
          shiny::plotOutput("overview_top_sources", height = "400px")
        )
      )
    )
  ),

  # -- 2. Works ----------------------------------------------------------------
  bslib::nav_panel(
    title = "Works",
    icon  = fontawesome::fa_i("file-lines"),
    bslib::card(
      bslib::card_header("Works Table"),
      bslib::card_body(
        fillable = TRUE,
        DT::DTOutput("works_table")
      )
    )
  ),

  # -- 3. Authors --------------------------------------------------------------
  bslib::nav_panel(
    title = "Authors",
    icon  = fontawesome::fa_i("users"),
    bslib::layout_columns(
      col_widths = c(8, 4),
      bslib::card(
        bslib::card_header("Authors & Metrics"),
        bslib::card_body(
          fillable = TRUE,
          DT::DTOutput("authors_table")
        )
      ),
      bslib::card(
        bslib::card_header("Lotka's Law"),
        bslib::card_body(
          shiny::plotOutput("authors_lotka", height = "400px")
        )
      )
    )
  ),

  # -- 4. Sources --------------------------------------------------------------
  bslib::nav_panel(
    title = "Sources",
    icon  = fontawesome::fa_i("book"),
    bslib::layout_columns(
      col_widths = c(8, 4),
      bslib::card(
        bslib::card_header("Sources Table"),
        bslib::card_body(
          fillable = TRUE,
          DT::DTOutput("sources_table")
        )
      ),
      bslib::card(
        bslib::card_header("Bradford's Law"),
        bslib::card_body(
          shiny::plotOutput("sources_bradford", height = "400px")
        )
      )
    )
  ),

  # -- 5. Networks -------------------------------------------------------------
  bslib::nav_panel(
    title = "Networks",
    icon  = fontawesome::fa_i("diagram-project"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 250,
        shiny::selectInput(
          "network_type", "Network Type",
          choices = c(
            "Citation"               = "citation",
            "Co-citation"            = "cocitation",
            "Bibliographic Coupling" = "coupling",
            "Collaboration"          = "collab",
            "Co-word"                = "coword"
          ),
          selected = "citation"
        ),
        shiny::numericInput(
          "network_top_n", "Max Nodes",
          value = 50, min = 10, max = 200, step = 10
        ),
        shiny::actionButton(
          "network_go", "Build Network",
          class = "btn-primary w-100"
        )
      ),
      bslib::card(
        bslib::card_header(shiny::textOutput("network_title")),
        bslib::card_body(
          shiny::plotOutput("network_plot", height = "600px")
        )
      )
    )
  ),

  # -- 6. Clusters -------------------------------------------------------------
  bslib::nav_panel(
    title = "Clusters",
    icon  = fontawesome::fa_i("object-group"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 250,
        shiny::selectInput(
          "cluster_reducer", "Dimensionality Reduction",
          choices  = c("UMAP" = "umap", "PCA" = "pca"),
          selected = "umap"
        ),
        shiny::numericInput(
          "cluster_min_size", "Min Cluster Size",
          value = 10, min = 3, max = 50, step = 1
        ),
        shiny::actionButton(
          "cluster_go", "Run Clustering",
          class = "btn-primary w-100"
        )
      ),
      bslib::card(
        bslib::card_header("Research Landscape"),
        bslib::card_body(
          shiny::plotOutput("cluster_landscape", height = "600px")
        )
      )
    )
  ),

  # -- 7. Metrics --------------------------------------------------------------
  bslib::nav_panel(
    title = "Metrics",
    icon  = fontawesome::fa_i("ranking-star"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 250,
        shiny::selectInput(
          "metric_type", "Metric",
          choices = c(
            "h-index"   = "h_index",
            "g-index"   = "g_index",
            "m-index"   = "m_index"
          ),
          selected = "h_index"
        ),
        shiny::selectInput(
          "metric_level", "Level",
          choices = c(
            "Author"      = "author",
            "Source"       = "source",
            "Country"     = "country"
          ),
          selected = "author"
        )
      ),
      bslib::card(
        bslib::card_header(shiny::textOutput("metric_title")),
        bslib::card_body(
          fillable = TRUE,
          DT::DTOutput("metric_table")
        )
      )
    )
  ),

  # -- 8. Trajectory -----------------------------------------------------------
  bslib::nav_panel(
    title = "Trajectory",
    icon  = fontawesome::fa_i("route"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 250,
        shiny::selectizeInput(
          "traj_author", "Select Author",
          choices  = NULL,
          options  = list(placeholder = "Type author name...")
        ),
        shiny::actionButton(
          "traj_go", "Build Trajectory",
          class = "btn-primary w-100"
        ),
        shiny::helpText(
          "Requires an author with publications across multiple years."
        )
      ),
      bslib::card(
        bslib::card_header("Author Trajectory"),
        bslib::card_body(
          shiny::uiOutput("traj_output")
        )
      )
    )
  ),

  # -- 9. Equity ---------------------------------------------------------------
  bslib::nav_panel(
    title = "Equity",
    icon  = fontawesome::fa_i("scale-balanced"),
    bslib::card(
      bslib::card_header("Equity & Representation Dashboard"),
      bslib::card_body(
        shiny::plotOutput("equity_dashboard", height = "700px")
      )
    )
  ),

  # -- 10. Screening -----------------------------------------------------------
  bslib::nav_panel(
    title = "Screening",
    icon  = fontawesome::fa_i("filter"),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("Screening Summary"),
        bslib::card_body(
          shiny::uiOutput("screening_summary")
        )
      ),
      bslib::card(
        bslib::card_header("PRISMA Flow"),
        bslib::card_body(
          shiny::plotOutput("screening_prisma", height = "400px")
        )
      )
    )
  ),

  # -- 11. Chat ----------------------------------------------------------------
  bslib::nav_panel(
    title = "Chat",
    icon  = fontawesome::fa_i("comments"),
    bslib::card(
      bslib::card_header("Corpus Explorer (Placeholder)"),
      bslib::card_body(
        shiny::helpText(
          "Conversational corpus exploration requires an LLM API key.",
          "Configure via SCIMAPR_LLM_API_KEY environment variable."
        ),
        shiny::textAreaInput(
          "chat_input", "Ask a question about the corpus:",
          placeholder = "e.g., What are the main research topics?",
          width = "100%", rows = 3
        ),
        shiny::actionButton(
          "chat_send", "Send",
          class = "btn-primary"
        ),
        shiny::tags$hr(),
        shiny::tags$div(
          id = "chat_response_area",
          style = "min-height: 200px; padding: 1rem; background: var(--bs-tertiary-bg, #f8f9fa); border-radius: 0.375rem;",
          shiny::textOutput("chat_response")
        )
      )
    )
  ),

  # -- 12. Reproducibility -----------------------------------------------------
  bslib::nav_panel(
    title = "Reproducibility",
    icon  = fontawesome::fa_i("certificate"),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(
        bslib::card_header("Provenance"),
        bslib::card_body(
          fillable = TRUE,
          DT::DTOutput("repro_provenance")
        )
      ),
      bslib::card(
        bslib::card_header("Corpus Certificate"),
        bslib::card_body(
          shiny::verbatimTextOutput("repro_certificate"),
          shiny::downloadButton(
            "repro_download_cert", "Download Certificate (YAML)",
            class = "btn-outline-primary mt-2"
          )
        )
      )
    )
  ),

  # -- 13. Export ---------------------------------------------------------------
  bslib::nav_panel(
    title = "Export",
    icon  = fontawesome::fa_i("download"),
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      bslib::card(
        bslib::card_header("Data Export"),
        bslib::card_body(
          shiny::downloadButton(
            "export_rds", "Corpus (.rds)",
            class = "btn-outline-primary w-100 mb-2"
          ),
          shiny::downloadButton(
            "export_csv", "Tables (.csv)",
            class = "btn-outline-primary w-100 mb-2"
          ),
          shiny::downloadButton(
            "export_bib", "Bibliography (.bib)",
            class = "btn-outline-primary w-100 mb-2"
          )
        )
      ),
      bslib::card(
        bslib::card_header("Figure Export"),
        bslib::card_body(
          shiny::selectInput(
            "export_fig_format", "Format",
            choices = c("PNG" = "png", "PDF" = "pdf", "SVG" = "svg"),
            selected = "png"
          ),
          shiny::downloadButton(
            "export_production_fig", "Production Plot",
            class = "btn-outline-primary w-100 mb-2"
          ),
          shiny::downloadButton(
            "export_equity_fig", "Equity Dashboard",
            class = "btn-outline-primary w-100 mb-2"
          )
        )
      ),
      bslib::card(
        bslib::card_header("Bundle Export"),
        bslib::card_body(
          shiny::helpText(
            "Export a self-contained ZIP with corpus data, certificate,",
            "and tables for sharing with collaborators."
          ),
          shiny::downloadButton(
            "export_zip", "Download Bundle (.zip)",
            class = "btn-primary w-100"
          )
        )
      )
    )
  ),

  # -- 14. Coverage ------------------------------------------------------------
  bslib::nav_panel(
    title = "Coverage",
    icon  = fontawesome::fa_i("clipboard-check"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 280,
        shiny::helpText(
          "Simulate a ground-truth reference by holding out a fraction of",
          "the corpus, then audit recall and precision against it."
        ),
        shiny::sliderInput(
          "coverage_holdout", "Reference holdout fraction",
          min = 0.1, max = 0.9, value = 0.25, step = 0.05
        ),
        shiny::actionButton(
          "coverage_go", "Run Coverage Audit",
          class = "btn-primary w-100"
        )
      ),
      bslib::layout_columns(
        col_widths = c(12, 12),
        bslib::value_box(
          title = "Recall / Precision / F1",
          value = shiny::textOutput("coverage_headline", inline = TRUE),
          showcase = fontawesome::fa_i("bullseye"),
          theme = "primary"
        ),
        bslib::card(
          bslib::card_header("Coverage (recall) by year"),
          bslib::card_body(
            shiny::plotOutput("coverage_plot", height = "420px")
          )
        )
      )
    )
  ),

  # -- 15. Affiliations --------------------------------------------------------
  bslib::nav_panel(
    title = "Affiliations",
    icon  = fontawesome::fa_i("building-columns"),
    bslib::card(
      bslib::card_header("Institution matching review"),
      bslib::card_body(
        shiny::helpText(
          "Match author affiliations to institutions with the default",
          "dictionary, then review the matches and method breakdown."
        ),
        shiny::actionButton(
          "affil_go", "Run Affiliation Matching",
          class = "btn-primary mb-3"
        ),
        DT::DTOutput("affil_table")
      )
    )
  ),

  # -- 16. Evaluation ----------------------------------------------------------
  bslib::nav_panel(
    title = "Evaluation",
    icon  = fontawesome::fa_i("chart-line"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 280,
        shiny::selectInput(
          "its_outcome", "Outcome",
          choices = c("Output count" = "count",
                      "Mean CNCI" = "cnci",
                      "Leadership share" = "leadership"),
          selected = "count"
        ),
        shiny::numericInput(
          "its_year", "Intervention year",
          value = NA, min = 1900, max = 2100, step = 1
        ),
        shiny::actionButton(
          "its_go", "Fit Interrupted Time Series",
          class = "btn-primary w-100"
        ),
        shiny::helpText(
          "Segmented regression with a level shift and slope change,",
          "plus the projected counterfactual (dashed)."
        )
      ),
      bslib::layout_columns(
        col_widths = c(8, 4),
        bslib::card(
          bslib::card_header("Interrupted time series"),
          bslib::card_body(
            shiny::plotOutput("its_plot", height = "480px")
          )
        ),
        bslib::card(
          bslib::card_header("Segmented coefficients"),
          bslib::card_body(
            DT::DTOutput("its_coefs")
          )
        )
      )
    )
  ),

  # -- Navbar extras -----------------------------------------------------------
  bslib::nav_spacer(),
  bslib::nav_item(
    bslib::input_dark_mode(id = "theme_toggle", mode = "light")
  )
)

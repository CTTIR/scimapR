# server.R -- scimapR Shiny application server logic
# Uses `corpus_data` from global.R.

function(input, output, session) {

  # -- Reactive corpus (allows future upload/swap) -----------------------------
  corpus <- shiny::reactiveVal(corpus_data)

  # ============================================================================
  # 1. OVERVIEW
  # ============================================================================

  output$vb_works <- shiny::renderText({
    format(nrow(corpus()$works), big.mark = ",")
  })

  output$vb_authors <- shiny::renderText({
    format(nrow(corpus()$authors), big.mark = ",")
  })

  output$vb_sources <- shiny::renderText({
    format(nrow(corpus()$sources), big.mark = ",")
  })

  output$vb_years <- shiny::renderText({
    w <- corpus()$works
    if (nrow(w) == 0 || all(is.na(w$year))) return("N/A")
    rng <- range(w$year, na.rm = TRUE)
    paste(rng[1], "–", rng[2])
  })

  output$overview_production <- shiny::renderPlot({
    scimapR::sm_plot_production(corpus())
  })

  output$overview_top_sources <- shiny::renderPlot({
    scimapR::sm_plot_top(corpus(), level = "sources", n = 10)
  })

  # ============================================================================
  # 2. WORKS
  # ============================================================================

  output$works_table <- DT::renderDT({
    w <- corpus()$works
    display <- w[, intersect(
      c("work_id", "title", "year", "type", "cited_by_count",
        "oa_status", "doi"),
      names(w)
    )]
    DT::datatable(
      display,
      filter   = "top",
      rownames = FALSE,
      options  = list(
        pageLength = 25,
        scrollX    = TRUE,
        dom        = "lfrtip"
      )
    )
  })

  # ============================================================================
  # 3. AUTHORS
  # ============================================================================

  authors_with_metrics <- shiny::reactive({
    c <- corpus()
    auth <- c$authors

    # Count works per author
    counts <- c$authorships |>
      dplyr::distinct(.data$work_id, .data$author_id) |>
      dplyr::count(.data$author_id, name = "n_works")

    # Compute h-index
    h_idx <- tryCatch(
      scimapR::sm_metric_h_index(c, level = "author"),
      error = function(e) {
        tibble::tibble(author_id = character(), h_index = integer())
      }
    )

    result <- auth |>
      dplyr::left_join(counts, by = "author_id") |>
      dplyr::left_join(h_idx, by = "author_id") |>
      dplyr::mutate(
        n_works = dplyr::coalesce(.data$n_works, 0L),
        h_index = dplyr::coalesce(.data$h_index, 0L)
      ) |>
      dplyr::arrange(dplyr::desc(.data$n_works))

    result[, intersect(
      c("author_id", "display_name", "orcid", "n_works", "h_index"),
      names(result)
    )]
  })

  output$authors_table <- DT::renderDT({
    DT::datatable(
      authors_with_metrics(),
      filter   = "top",
      rownames = FALSE,
      options  = list(
        pageLength = 25,
        scrollX    = TRUE
      )
    )
  })

  output$authors_lotka <- shiny::renderPlot({
    scimapR::sm_plot_lotka(corpus())
  })

  # ============================================================================
  # 4. SOURCES
  # ============================================================================

  output$sources_table <- DT::renderDT({
    c <- corpus()
    src <- c$sources

    # Count works per source
    src_counts <- c$works |>
      dplyr::filter(!is.na(.data$source_id)) |>
      dplyr::count(.data$source_id, name = "n_works")

    display <- src |>
      dplyr::left_join(src_counts, by = "source_id") |>
      dplyr::mutate(n_works = dplyr::coalesce(.data$n_works, 0L)) |>
      dplyr::arrange(dplyr::desc(.data$n_works))

    display <- display[, intersect(
      c("source_id", "display_name", "type", "publisher", "is_oa", "n_works"),
      names(display)
    )]

    DT::datatable(
      display,
      filter   = "top",
      rownames = FALSE,
      options  = list(
        pageLength = 25,
        scrollX    = TRUE
      )
    )
  })

  output$sources_bradford <- shiny::renderPlot({
    scimapR::sm_plot_bradford(corpus())
  })

  # ============================================================================
  # 5. NETWORKS
  # ============================================================================

  network_graph <- shiny::reactiveVal(NULL)

  output$network_title <- shiny::renderText({
    sel <- input$network_type
    labels <- c(
      citation  = "Citation Network",
      cocitation = "Co-citation Network",
      coupling  = "Bibliographic Coupling Network",
      collab    = "Collaboration Network",
      coword    = "Co-word Network"
    )
    labels[sel] %||% "Network"
  })

  shiny::observeEvent(input$network_go, {
    c <- corpus()
    nt <- input$network_type
    top_n <- input$network_top_n

    shiny::withProgress(message = "Building network...", {
      g <- tryCatch({
        switch(nt,
          citation  = scimapR::sm_network_citation(c),
          cocitation = scimapR::sm_network_cocitation(c, min_weight = 1L),
          coupling  = scimapR::sm_network_coupling(c, min_shared = 1L),
          collab    = scimapR::sm_network_collab(c, level = "country"),
          coword    = scimapR::sm_network_coword(c, min_freq = 2L)
        )
      }, error = function(e) {
        shiny::showNotification(
          paste("Network error:", e$message),
          type = "error"
        )
        NULL
      })
      network_graph(g)
    })
  })

  output$network_plot <- shiny::renderPlot({
    g <- network_graph()
    if (is.null(g)) {
      plot.new()
      text(0.5, 0.5, "Click 'Build Network' to generate a network plot.",
           cex = 1.2, col = "#888888")
      return()
    }

    n_nodes <- igraph::vcount(g)
    if (n_nodes == 0) {
      plot.new()
      text(0.5, 0.5, "No edges found for this network type.",
           cex = 1.2, col = "#888888")
      return()
    }

    ggraph::ggraph(g, layout = "stress") +
      ggraph::geom_edge_link(alpha = 0.3,
                             colour = viridisLite::viridis(1, begin = 0.4)) +
      ggraph::geom_node_point(size = 3,
                              colour = viridisLite::viridis(1)) +
      scimapR::sm_theme() +
      ggplot2::labs(title = NULL) +
      ggraph::theme_graph(background = "white")
  })

  # ============================================================================
  # 6. CLUSTERS
  # ============================================================================

  clustered_corpus <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$cluster_go, {
    c <- corpus()

    if (is.null(c$embeddings) || nrow(c$embeddings) == 0) {
      shiny::showNotification(
        "No embeddings available. Clustering requires embeddings.",
        type = "warning"
      )
      return()
    }

    shiny::withProgress(message = "Running clustering...", {
      cc <- tryCatch(
        scimapR::sm_cluster_hdbscan(
          c,
          min_cluster_size = as.integer(input$cluster_min_size),
          reducer = input$cluster_reducer
        ),
        error = function(e) {
          shiny::showNotification(
            paste("Clustering error:", e$message),
            type = "error"
          )
          NULL
        }
      )
      clustered_corpus(cc)
    })
  })

  output$cluster_landscape <- shiny::renderPlot({
    cc <- clustered_corpus()
    if (is.null(cc)) {
      # Show landscape from raw corpus if embeddings exist
      c <- corpus()
      if (!is.null(c$embeddings) && nrow(c$embeddings) > 0) {
        return(scimapR::sm_plot_landscape(c, reducer = "umap"))
      }
      plot.new()
      text(0.5, 0.5,
           "Click 'Run Clustering' to visualise the research landscape.",
           cex = 1.2, col = "#888888")
      return()
    }
    scimapR::sm_plot_landscape(cc, reducer = input$cluster_reducer)
  })

  # ============================================================================
  # 7. METRICS
  # ============================================================================

  output$metric_title <- shiny::renderText({
    mt <- input$metric_type
    ml <- input$metric_level
    labels <- c(h_index = "h-index", g_index = "g-index", m_index = "m-index")
    levels <- c(author = "Author", source = "Source", country = "Country")
    paste(labels[mt], "by", levels[ml])
  })

  output$metric_table <- DT::renderDT({
    c <- corpus()
    mt <- input$metric_type
    ml <- input$metric_level

    result <- tryCatch({
      switch(mt,
        h_index = scimapR::sm_metric_h_index(c, level = ml),
        g_index = scimapR::sm_metric_g_index(c, level = ml),
        m_index = scimapR::sm_metric_m_index(c, level = ml)
      )
    }, error = function(e) {
      tibble::tibble(entity = character(), value = numeric())
    })

    # Resolve author names if level is author
    if (ml == "author" && "author_id" %in% names(result) &&
        nrow(c$authors) > 0) {
      result <- result |>
        dplyr::left_join(
          dplyr::select(c$authors, "author_id", "display_name"),
          by = "author_id"
        ) |>
        dplyr::relocate("display_name", .after = "author_id")
    }

    DT::datatable(
      result,
      filter   = "top",
      rownames = FALSE,
      options  = list(
        pageLength = 25,
        scrollX    = TRUE,
        order      = list()
      )
    )
  })

  # ============================================================================
  # 8. TRAJECTORY
  # ============================================================================

  # Populate author selectize on session start
  shiny::observe({
    c <- corpus()
    if (nrow(c$authors) > 0) {
      choices <- stats::setNames(
        c$authors$display_name,
        c$authors$display_name
      )
      shiny::updateSelectizeInput(
        session, "traj_author",
        choices = choices,
        server  = TRUE
      )
    }
  })

  traj_result <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$traj_go, {
    author_name <- input$traj_author
    if (is.null(author_name) || author_name == "") {
      shiny::showNotification("Please select an author.", type = "warning")
      return()
    }

    c <- corpus()

    # Find author_id from display_name
    aid <- c$authors$author_id[c$authors$display_name == author_name]
    if (length(aid) == 0) {
      shiny::showNotification("Author not found.", type = "error")
      return()
    }
    aid <- aid[1]

    shiny::withProgress(message = "Building trajectory...", {
      traj <- tryCatch(
        scimapR::sm_author_trajectory(c, author_id = aid),
        error = function(e) {
          shiny::showNotification(
            paste("Trajectory error:", e$message),
            type = "error"
          )
          NULL
        }
      )
      traj_result(traj)
    })
  })

  output$traj_output <- shiny::renderUI({
    traj <- traj_result()
    if (is.null(traj)) {
      return(shiny::helpText(
        "Select an author and click 'Build Trajectory'",
        "to analyse their career progression."
      ))
    }

    shiny::tagList(
      shiny::plotOutput("traj_plot", height = "600px")
    )
  })

  output$traj_plot <- shiny::renderPlot({
    traj <- traj_result()
    shiny::req(traj)
    scimapR::sm_plot_trajectory(traj)
  })

  # ============================================================================
  # 9. EQUITY
  # ============================================================================

  output$equity_dashboard <- shiny::renderPlot({
    scimapR::sm_plot_equity_dashboard(corpus())
  })

  # ============================================================================
  # 10. SCREENING
  # ============================================================================

  output$screening_summary <- shiny::renderUI({
    c <- corpus()
    scr <- c$screening

    if (nrow(scr) == 0) {
      return(shiny::tagList(
        shiny::tags$p(
          class = "text-muted",
          "No screening decisions recorded in this corpus."
        ),
        shiny::tags$p(
          "Use ", shiny::tags$code("sm_screen_*()"),
          " functions to add screening decisions."
        )
      ))
    }

    n_decisions <- nrow(scr)
    stages <- unique(scr$stage)
    decisions <- table(scr$decision)

    shiny::tagList(
      shiny::tags$p(
        shiny::tags$strong(format(n_decisions, big.mark = ",")),
        " screening decisions across ",
        shiny::tags$strong(length(stages)), " stage(s)."
      ),
      shiny::tags$ul(
        lapply(names(decisions), function(d) {
          shiny::tags$li(paste0(d, ": ", decisions[d]))
        })
      )
    )
  })

  output$screening_prisma <- shiny::renderPlot({
    c <- corpus()
    if (nrow(c$screening) == 0) {
      plot.new()
      text(0.5, 0.5, "No screening data available.",
           cex = 1.2, col = "#888888")
      return()
    }

    prisma <- scimapR::sm_screen_prisma(c)
    prisma$plot
  })

  # ============================================================================
  # 11. CHAT (placeholder)
  # ============================================================================

  output$chat_response <- shiny::renderText({
    shiny::req(input$chat_send)
    shiny::isolate({
      q <- input$chat_input
      if (is.null(q) || nchar(trimws(q)) == 0) {
        return("Please type a question.")
      }
      paste0(
        "Chat is a placeholder. Your question: \"", q, "\"\n\n",
        "To enable conversational exploration, set the ",
        "SCIMAPR_LLM_API_KEY environment variable and install the ",
        "'ellmer' package."
      )
    })
  })

  # ============================================================================
  # 12. REPRODUCIBILITY
  # ============================================================================

  output$repro_provenance <- DT::renderDT({
    prov <- scimapR::sm_provenance(corpus())
    display <- prov[, intersect(
      c("work_id", "source", "query", "engine",
        "fetch_date", "scimapR_version"),
      names(prov)
    )]
    DT::datatable(
      display,
      filter   = "top",
      rownames = FALSE,
      options  = list(
        pageLength = 15,
        scrollX    = TRUE
      )
    )
  })

  cert_obj <- shiny::reactive({
    tryCatch(
      scimapR::sm_certificate(corpus()),
      error = function(e) NULL
    )
  })

  output$repro_certificate <- shiny::renderPrint({
    cert <- cert_obj()
    if (is.null(cert)) {
      cat("Certificate could not be generated.")
      return()
    }
    print(cert)
  })

  output$repro_download_cert <- shiny::downloadHandler(
    filename = function() {
      paste0("scimapR_certificate_", Sys.Date(), ".yaml")
    },
    content = function(file) {
      cert <- cert_obj()
      if (is.null(cert)) {
        writeLines("# Certificate generation failed.", file)
        return()
      }
      scimapR::sm_certificate(corpus(), path = file)
    }
  )

  # ============================================================================
  # 13. EXPORT
  # ============================================================================

  # -- RDS
  output$export_rds <- shiny::downloadHandler(
    filename = function() {
      paste0("scimapR_corpus_", Sys.Date(), ".rds")
    },
    content = function(file) {
      scimapR::sm_export_rds(corpus(), file)
    }
  )

  # -- CSV (zip of CSVs)
  output$export_csv <- shiny::downloadHandler(
    filename = function() {
      paste0("scimapR_tables_", Sys.Date(), ".zip")
    },
    content = function(file) {
      tmpdir <- tempdir()
      csv_dir <- file.path(tmpdir, "scimapR_csv")
      dir.create(csv_dir, showWarnings = FALSE, recursive = TRUE)
      scimapR::sm_export_csv(corpus(), csv_dir)
      csv_files <- list.files(csv_dir, full.names = TRUE)
      utils::zip(file, files = csv_files, extras = "-j")
    }
  )

  # -- BIB
  output$export_bib <- shiny::downloadHandler(
    filename = function() {
      paste0("scimapR_bibliography_", Sys.Date(), ".bib")
    },
    content = function(file) {
      c <- corpus()
      lines <- character()
      for (i in seq_len(nrow(c$works))) {
        w <- c$works[i, ]
        key <- gsub("[^a-zA-Z0-9]", "", w$work_id)
        lines <- c(lines,
          paste0("@article{", key, ","),
          paste0("  title = {", w$title %||% "", "},"),
          paste0("  year = {", w$year %||% "", "},"),
          paste0("  doi = {", w$doi %||% "", "},"),
          "}"
        )
      }
      writeLines(lines, file)
    }
  )

  # -- Production figure
  output$export_production_fig <- shiny::downloadHandler(
    filename = function() {
      paste0("production_plot.", input$export_fig_format)
    },
    content = function(file) {
      p <- scimapR::sm_plot_production(corpus())
      ggplot2::ggsave(file, plot = p, width = 10, height = 6, dpi = 300)
    }
  )

  # -- Equity figure
  output$export_equity_fig <- shiny::downloadHandler(
    filename = function() {
      paste0("equity_dashboard.", input$export_fig_format)
    },
    content = function(file) {
      p <- scimapR::sm_plot_equity_dashboard(corpus())
      ggplot2::ggsave(file, plot = p, width = 12, height = 8, dpi = 300)
    }
  )

  # -- Bundle ZIP
  output$export_zip <- shiny::downloadHandler(
    filename = function() {
      paste0("scimapR_bundle_", Sys.Date(), ".zip")
    },
    content = function(file) {
      tryCatch(
        scimapR::sm_export_zip(
          corpus(), file,
          include = c("rds", "certificate", "tables")
        ),
        error = function(e) {
          # Fallback: just export RDS
          scimapR::sm_export_rds(corpus(), file)
        }
      )
    }
  )
}

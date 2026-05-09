#' Build a collaboration network
#'
#' @description
#' Constructs an undirected collaboration (co-authorship) network. Nodes
#' represent entities at the chosen `level` (authors, institutions, or
#' countries) and an edge connects two entities if they co-authored at least
#' one work. Edge weight equals the number of co-authored works.
#'
#' @param corpus An [sm_corpus] object with a populated `authorships` table.
#' @param level Character; the entity level for network nodes. One of
#'   `"author"` (default), `"institution"`, or `"country"`.
#' @param call Caller environment for error reporting.
#'
#' @return A [tidygraph::tbl_graph] object (undirected). Nodes carry `name`
#'   (entity ID or label) and, for `"author"` level, columns from
#'   `corpus$authors`. Edges carry a `weight` column.
#'
#' @details
#' For `level = "author"`, the `author_id` column from `authorships` is used
#' and author metadata is joined from `corpus$authors`.
#'
#' For `level = "institution"`, the `institution_id` column is used and
#' institution metadata is joined from `corpus$institutions`.
#'
#' For `level = "country"`, the `country_code` column is used.
#'
#' Empty input returns an empty undirected `tbl_graph`.
#'
#' @family networks
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' g <- sm_network_collab(corpus, level = "author")
#' g
sm_network_collab <- function(corpus,
                              level = c("author", "institution", "country"),
                              call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  level <- rlang::arg_match(level, error_call = call)

  authorships <- corpus$authorships

  # --- empty input guard ---
  if (nrow(corpus$works) == 0L || nrow(authorships) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Select the entity column based on level
  entity_col <- switch(level,
    author      = "author_id",
    institution = "institution_id",
    country     = "country_code"
  )

  if (!entity_col %in% names(authorships)) {
    cli::cli_abort(
      "Column {.field {entity_col}} not found in {.field authorships} table.",
      call = call
    )
  }

  # Build work-entity pairs (remove NAs)
  work_entity <- authorships %>%
    dplyr::select("work_id", entity = dplyr::all_of(entity_col)) %>%
    dplyr::filter(!is.na(.data$entity)) %>%
    dplyr::distinct()

  if (nrow(work_entity) == 0L) {
    nodes <- tibble::tibble(name = character())
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Self-join to find co-authorship pairs
  pairs <- work_entity %>%
    dplyr::inner_join(
      work_entity %>% dplyr::rename(entity_2 = "entity"),
      by = "work_id",
      relationship = "many-to-many"
    ) %>%
    dplyr::filter(.data$entity < .data$entity_2) %>%
    dplyr::count(.data$entity, .data$entity_2, name = "weight")

  if (nrow(pairs) == 0L) {
    # Still return nodes (isolates)
    all_ids <- unique(work_entity$entity)
    nodes <- tibble::tibble(name = all_ids)
    nodes <- .join_entity_metadata(nodes, corpus, level)
    edges <- tibble::tibble(from = integer(), to = integer(), weight = integer())
    return(tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE))
  }

  # Build node table
  all_ids <- unique(c(pairs$entity, pairs$entity_2))
  nodes <- tibble::tibble(name = all_ids)
  nodes <- .join_entity_metadata(nodes, corpus, level)

  # Build edge list
  node_idx <- stats::setNames(seq_along(nodes$name), nodes$name)
  edges <- tibble::tibble(
    from   = unname(node_idx[pairs$entity]),
    to     = unname(node_idx[pairs$entity_2]),
    weight = pairs$weight
  )

  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE)
}


#' Join entity metadata to a node table
#' @noRd
.join_entity_metadata <- function(nodes, corpus, level) {
  switch(level,
    author = {
      meta <- corpus$authors
      if (nrow(meta) > 0L && "author_id" %in% names(meta)) {
        nodes <- dplyr::left_join(nodes, meta, by = c("name" = "author_id"))
      }
    },
    institution = {
      meta <- corpus$institutions
      if (nrow(meta) > 0L && "institution_id" %in% names(meta)) {
        nodes <- dplyr::left_join(nodes, meta,
                                  by = c("name" = "institution_id"))
      }
    },
    country = {
      # No additional metadata to join for countries
    }
  )
  nodes
}

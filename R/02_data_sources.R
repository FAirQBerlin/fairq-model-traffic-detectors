#' Data sources to query from clickhouse
#'
#' List data sources. This list defines which data source to transfer from dev to prod.
#'
#' @export
#' @rdname single_source
data_sources <- function() {
  out <- list(
    single_source("traffic_model_predictions_stations"),
    single_source("traffic_model_predictions_grid"),
    single_source("traffic_models_final"),
    single_source("traffic_model_scaling"),
    single_source("traffic_model_description",
                  source_schema = "fairq_output",
                  target_schema = "fairq_prod_output"
    )
  )

  names(out) <- unlist(lapply(out, function(x) x[["table"]]))
  out
}



#' Single source
#'
#' @param table (character) table on the database which data should be transferred.
#' has to exist in source and target schema.
#' @param source_schema (character) schema to get the data from
#' @param target_schema (character) schema to send the data to
single_source <- function(table,
                          source_schema = "fairq_features",
                          target_schema = "fairq_prod_features") {

  list(
    table = table,
    source_schema = source_schema,
    target_schema = target_schema
  )
}

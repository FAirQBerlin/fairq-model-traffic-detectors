#' Send data from dev schema to prod schema
#'
#' @param x (list) list obtained from single_source, containing the fields table (the table to transfer),
#' source_schema (the schema to get the data), target_schema  (the schema to insert the data)
#' optimizes dubplicates
copy_data_to_prod <- function(x) {
  on.exit(
    {
      logging(sprintf("Optimizing table: %s@%s", x$target_schema, x$table))
      optimize_table_final(x$table, x$target_schema)
    }
  )

  logging(sprintf("Sending table %s from %s to %s",  x$table, x$source_schema, x$target_schema))
  send_query(
    "table_to_prod",
    table = x$table,
    source_schema = x$source_schema,
    target_schema = x$target_schema
  )

  logging(sprintf("Done with table: %s", x$table))
}



#' transfer all tables to the prod schema
#'
#' @param tables (list) see result of \code{data_sources()}
#'
#' @export
transfer_tables_to_prod <- function(tables = data_sources()) {
  res <- lapply(tables, function(x) try(copy_data_to_prod(x)))
  invisible(
    if (any(unlist(lapply(res, inherits, what = "try-error")))) 1
    else 0
  )
}

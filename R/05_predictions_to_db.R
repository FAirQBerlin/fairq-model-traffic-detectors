#' Prepare data frame with predictions for DB
#'
#' Add model ID, date_time_forecast and select columns
#'
#' @param df data frame with predictions (columns date_time, x, y, value)
#' @param model_id model ID; may be NULL (then there won't be a column model_id)
#'
#' @return data.frame with columns model_id (if provided), date_time, x, y, value
#' in exactly this order
#' @export
prep_preds_for_db <-
  function(df, model_id) {
    df %>%
      mutate(model_id = model_id,
             value = round(.data$value, 0)) %>%
      select(any_of(c(
        "model_id", "date_time", "x", "y", "value"
      )))
  }


#' Prepare model description for DB
#' @param xgb_fit XGBoost model object (to extract hyper parameters)
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#' @param dat_train (data.frame) training data (to extract beginning and end of training period)
#' @param dat (data.frame) full data (to extract date when the model was developed)
#' @param model_name (string) A name for the model, e.g., "without_weather"
#' @return data.frame with columns model_id, date_time, model_name, depvar, and description
#' @export
model_description_for_db <-
  function(xgb_fit,
           target_variable,
           dat_train,
           dat,
           model_name) {
    description_for_db <-
      model_description_json(xgb_fit, target_variable, dat_train$date_time)
    model_descr <- data.frame(
      model_id = NA,
      date_time = max(dat$date_time),
      model_name = model_name,
      depvar = target_variable,
      description = description_for_db
    )
    add_model_id(model_descr)
  }


#' Prepare json string with model description
#'
#' @param xgb_fit XGBoost model object (to extract hyper parameters)
#' @param target_variable (character) "q_kfz" for counted traffic of all
#' vehicles volume/quantities, "v_kfz" for average traffic speed of all vehicles
#' @param train_date_time_column datetime vector of training data (to extract beginning and end of
#' training period)
#' @return json string
model_description_json <-
  function(xgb_fit,
           target_variable,
           train_date_time_column) {
    list(
      hyperparams = xgb_fit$bestTune,
      model_formula = as.character(model_formula(target_variable)),
      dates = list(train_start = format_date(min(
        train_date_time_column
      )),
      train_end = format_date(max(
        train_date_time_column
      )))
    ) %>% toJSON
  }


#' Add model ID
#'
#' @description If a model with the same date_time, model_name, and description already exists in
#' the database, its ID is used. If not, the smallest ID that's not in the database is added.
#'
#' @param model_descr data frame
#' @return same data frame where the new ID has been written into the model_id column
add_model_id <- function(model_descr) {
  model_id_db <- send_query(
    "get_model_id",
    database = Sys.getenv("DB_SCHEMA_TARGET"),
    date_time = model_descr$date_time,
    model_name = model_descr$model_name,
    json_description = model_descr$description
  )

  if (is.null(model_id_db[[1]])) {
    model_descr$model_id <-
      send_query("next_model_id", database = Sys.getenv("DB_SCHEMA_TARGET"),)$model_id
    logging("Model is new, so a new ID is created (ID %s)",
            model_descr$model_id)
  } else {
    logging("Model already exists, so we use its model ID from the DB (ID %s)",
            model_id_db$model_id)
    model_descr$model_id <- model_id_db$model_id
  }
  return(model_descr)
}


#' Retrieve data, make predictions, write them to DB
#'
#' @param query_features (string) name of the query to retrieve the features
#' @param xgb_fit A model object from XGBoost
#' @param model_id (int) Model ID of the model we use
#' @param table_name (string) Name of the table where the predictions are sent
#' @param database (string) name of database schema the data is sent to
#' @return Nothing
#' @export
preds_to_db <-
  function(query_features,
           xgb_fit,
           model_id,
           table_name,
           database = Sys.getenv("DB_SCHEMA_TARGET")) {
    logging("Retrieving data for %s", query_features)
    features <- send_query(query_features)
    gc()
    logging("Making predictions for %s observations.", nrow(features))
    features$value <- predict(xgb_fit, features)
    gc()
    features <- prep_preds_for_db(features, model_id = model_id)
    if (!as.logical(DEV)) {
      send_data(df = features,
                table = table_name,
                database = database,
                mode = "replace")
    }
    rm(features)
    gc()
  }


#' Retrieve data, make predictions on whole grid, write them to DB - chunkwise
#'
#' @description Processes the data chunkwise (by x coordinates) to save working memory.
#' Uses mode insert and optimizes table only once at the end to save time
#'
#' @param chunk_size (int) Size of the chunks, i.e., how many x coordinates are processed at once
#' @param query_features (string) name of the query to retrieve the features,
#' must be a query that takes the parameter x to filter the data on a specific x
#' coordinate. If the query is not parametrized by x, but retrieves all data at once,
#' use the function preds_to_db() instead of this one.
#' @param xgb_fit A model object from XGBoost
#' @param model_id (int) Model ID of the model we use
#' @param table_name (string) Name of the table where the predictions are sent
#' @return Nothing
#' @export
preds_chunkwise_to_db <-
  function(chunk_size,
           query_features,
           xgb_fit,
           model_id,
           table_name) {
    x_coords <- send_query("distinct_x_coords")$x
    chunks <- comma_separated_chunks(x_coords, chunk_size)
    logging("Divided data into %s chunks", length(chunks))
    chunk_number <- 1
    for (x in chunks) {
      logging(
        "Retrieving data for chunk %s of %s (coordinates %s)",
        chunk_number,
        length(chunks),
        x
      )
      dat_x <- send_query(query_features, x_coords = x)
      gc()

      logging("Making predictions for chunk %s of %s",
              chunk_number,
              length(chunks))
      dat_x$value <- predict(xgb_fit, dat_x)
      gc()

      dat_x <- prep_preds_for_db(dat_x, model_id = model_id)

      if (!as.logical(DEV)) {
        # Use mode insert now and optimize table only once at the end
        send_data(
          df = dat_x,
          table = table_name,
          database = Sys.getenv("DB_SCHEMA_SOURCE"),
          mode = "insert"
        )
      }
      chunk_number <- chunk_number + 1
    }

    rm(dat_x)
    gc()
    check_for_replacing_merge_tree(table = table_name,
                                   database = Sys.getenv("DB_SCHEMA_SOURCE"))
    logging("Optimizing table %s to remove duplicates", table_name)
    optimize_table_final(table = table_name,
                         database = Sys.getenv("DB_SCHEMA_SOURCE"))
    logging("Done <3")
  }


#' Divide a vector into chunks and format them as comma-separated strings
#'
#' @description The chunks can be used for example in SQL queries
#'
#' @param vec a vector, e.g., of x coordinates
#' @param chunk_length (integer) maximal chunk size; Inf to return exactly one chunk
#' @return list of strings like, e.g., "3, 4, 5"
comma_separated_chunks <- function(vec, chunk_length) {
  chunks <- split(vec, ceiling(seq_along(vec) / chunk_length))
  lapply(chunks, paste, collapse = ", ")
}

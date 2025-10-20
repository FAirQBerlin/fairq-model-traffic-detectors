#############################################################
# Script to make predictions with a pretrained model from db
#############################################################

library(fairqModelTrafficDetectors)
library(fairqDbtools)
sessionInfo()

args <- R.utils::commandArgs(
  trailingOnly = TRUE,
  asValues = TRUE,
  defaults = list(TARGET_VARIABLE="q_kfz") # or v_kfz
)
target_variable <- args$TARGET_VARIABLE
model_id = get_latest_model_id(target_variable)

logging("Start making predictions with model_id=%s and target_variable=%s", model_id, target_variable)

xgb_fit_final <- retrieve_model_from_db(model_id)

# Make predictions
## a.) Predictions for the detectors - we need them to evaluate the model
preds_to_db(
  query = "features_at_detectors",
  xgb_fit = xgb_fit_final,
  target_variable = target_variable,
  model_id = model_id,
  table_name = "traffic_model_predictions_temporal_cv"
)

## b.) Predictions at measuring stations for whole time period - we need them to train the pollutant
## model
preds_to_db(
  query = "features_at_stations",
  xgb_fit = xgb_fit_final,
  target_variable = target_variable,
  model_id = model_id,
  table_name = "traffic_model_predictions_stations",
  database = Sys.getenv("DB_SCHEMA_SOURCE")
)

## c.) Predictions on whole grid for the next 16 weeks - we need them as input
## for the pollutant model to make predictions on the whole grid
start_time <- preds_chunkwise_to_db(
  chunk_size = 10,
  query = "features_on_grid_future",
  xgb_fit = xgb_fit_final,
  target_variable = target_variable,
  model_id = model_id,
  table_name = "traffic_model_predictions_grid"
)

# Check if the correct number of rows for this model ID arrived in DB
preds_model_id_in_db <- send_query("check_preds_in_db_for_model_id",
                                   model_id = model_id,
                                   start_time = start_time,
                                   database = Sys.getenv("DB_SCHEMA_SOURCE"))

actual_count <- preds_model_id_in_db$n_preds
if (actual_count != 24*36*360765 && # normal
    actual_count != 24*36*360765 + 360765 && # summer -> winter
    actual_count != 24*36*360765 - 360765) { # winter -> summer
  stop("It seems that not all grid predictions have arrived correctly in the DB.")
}

# Define model that will be used in pollutant model
model_id_df <- data.frame(depvar = target_variable,
                          model_id = model_id,
                          preds_finished = FALSE,
                          inserted_at = Sys.time())
send_data(
  df = model_id_df,
  table = "traffic_models_final",
  mode = "replace",
  database = Sys.getenv("DB_SCHEMA_SOURCE")
)

## d.) Predictions on whole grid for 2019 - we need them to compute the scaling factors based on the
## traffic volume
# Caution: Consumes a lot of working memory, better run it on VM or choose chunk_size 1
if (target_variable == "q_kfz") {
  send_query("truncate table traffic_model_predictions_2019;")
  preds_chunkwise_to_db(
    chunk_size = 3,
    query = "features_on_grid_2019",
    xgb_fit = xgb_fit_final,
    target_variable = target_variable,
    model_id = model_id,
    table_name = "traffic_model_predictions_2019"
  )

  # Update scaling factors based on the new predictions for 2019
  pred_2019_in_db <-
    send_query("check_2019_preds_arrived_in_db")
  if (!as.logical(pred_2019_in_db$all_preds_arrived)) {
    stop("It seems that not all 2019 predictions have arrived correctly in the DB.")
  } else {
    send_query("update_scaling_factors")
    optimize_table_final("traffic_model_scaling",
                         database = Sys.getenv("DB_SCHEMA_SOURCE"))
    send_query("truncate table traffic_model_predictions_2019;")
  }
}

model_id_df <- data.frame(depvar = target_variable,
                          model_id = model_id,
                          preds_finished = TRUE,
                          inserted_at = Sys.time())
send_data(
  df = model_id_df,
  table = "traffic_models_final",
  mode = "replace",
  database = Sys.getenv("DB_SCHEMA_SOURCE")
)

logging("Finished making predictions :-)")

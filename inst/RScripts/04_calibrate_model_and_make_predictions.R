# Estimate a model on the full data set and write predictions to the database
# We use the optimal hyper parameters we identified using temporal CV
# These predictions are used as input in the pollutant model;
# in addition, we can use them for OOS-validation of the traffic model as soon as the next data
# are available

rm(list = ls(all.names = TRUE))

# Make sure to have latest package version installed:
# devtools::document()
# devtools::install()

library(caret)
library(dplyr)
library(fairqModelTrafficDetectors)
library(fairqDbtools)
library(Metrics)
library(parallel)
library(xgboost)

set.seed(364)

# Set variables ----
# If DEV is TRUE, we work with a fraction of cases (= frac_if_dev)
model_name <- "nov_23"
DEV <- Sys.getenv("DEV")
frac_if_dev <- 0.1
# Which target variable should be modeled?
# --> "q_kfz" for counted traffic of all vehicles volume/quantities
# --> "v_kfz" for average traffic speed of all vehicles
target_variable <- "v_kfz"

# Get data ----
dat <- get_data(target_variable, DEV, frac_if_dev)
print(max(dat$date_time))

# Train model ----
xgb_fit <- train(
  form = model_formula(target_variable),
  data = dat,
  method = "xgbTree",
  tuneGrid = optimal_hyper_parameters(target_variable),
  reg_lambda = optimal_lambda(target_variable),
  # fit one model to the entire training set:
  trControl = trainControl("none", predictionBounds = c(0, NA)),
  verbose = TRUE,
  nthread = detectCores() - 1
)


# Save model results ----
# So we can load them in another file and look at variable importance or make
# predictions
file_prefix <- paste0(format(Sys.Date(), "%y%m%d"), "_", target_variable, "_")
file_suffix <- if (DEV) "_dev" else ""
model_results_filename <- paste0(file_prefix,
                                 "traffic_model_full_period",
                                 file_suffix,
                                 ".Rdata")
save(xgb_fit, file = model_results_filename)

# In-sample model performance
pred <- predict(xgb_fit, dat)
rmse(dat[[target_variable]], pred)
R2(pred, dat[[target_variable]], form = "traditional")
mae(dat[[target_variable]], pred)

# Write predictions to DB ----
# Model description
model_descr <- model_description_for_db(
  xgb_fit = xgb_fit,
  target_variable = target_variable,
  dat_train = dat,
  dat = dat,
  model_name = model_name
)
send_data(model_descr, "traffic_model_description", mode = "replace")
rm(dat)
gc()
model_descr_filename <-
  paste0(file_prefix, "model_descr", file_suffix, ".Rdata")
save(model_descr, file = model_descr_filename)

# Make predictions
## a.) Predictions for the detectors - we need them to evaluate the model
preds_to_db(
  query_features = "features_at_detectors",
  xgb_fit = xgb_fit,
  model_id = model_descr$model_id,
  table_name = "traffic_model_predictions_temporal_cv"
)

## b.) Predictions at measuring stations for whole time period - we need them to train the pollutant
## model
preds_to_db(
  query_features = "features_at_stations",
  xgb_fit = xgb_fit,
  model_id = model_descr$model_id,
  table_name = "traffic_model_predictions_stations",
  database = Sys.getenv("DB_SCHEMA_SOURCE")
)

## c.) Predictions on whole grid for the next 16 weeks - we need them as input
## for the pollutant model to make predictions on the whole grid
preds_chunkwise_to_db(
  chunk_size = 10,
  query_features = "features_on_grid_future",
  xgb_fit = xgb_fit,
  model_id = model_descr$model_id,
  table_name = "traffic_model_predictions_grid"
)

# Check if the correct number of rows for this model ID arrived in DB
preds_model_id_in_db <- send_query("check_preds_in_db_for_model_id",
                                   model_id = model_descr$model_id,
                                   database = Sys.getenv("DB_SCHEMA_SOURCE"))
if (!as.logical(preds_model_id_in_db$all_preds_arrived)) {
  stop("It seems that not all grid predictions have arrived correctly in the DB.")
}

# Define model that will be used in pollutant model
model_id_df <- data.frame(depvar = target_variable,
                          model_id = model_descr$model_id)
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
    chunk_size = 6,
    query_features = "features_on_grid_2019",
    xgb_fit = xgb_fit,
    model_id = model_descr$model_id,
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

# after some time: put the new predictions to production:
# script is in 06_move_data_dev_prod

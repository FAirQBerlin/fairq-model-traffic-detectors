# This script contains code to make predictions that are not made regularly.
# It needs a model and a model description saved on disc.
# These two objects must be created with script 04 beforehand.

library(fairqModelTrafficDetectors)

load("231108_v_kfz_traffic_model_full_period.Rdata")# model object
load("231108_v_kfz_model_descr.Rdata") # model description
DEV <- Sys.getenv("DEV")


# Predictions for traffic dashboard
# Adapt query to change time period
preds_to_db(
  query_features = "features_at_detectors",
  xgb_fit = xgb_fit,
  model_id = model_descr$model_id,
  table_name = "traffic_model_predictions_temporal_cv"
)


# Predictions on whole grid for Nov21-Oct22
# traffic quantity (q_kfz) and traffic velocity (v_kfz)
# No need to run this every time; is run just once to make the predictions for hotspots
# Caution: Consumes a lot of working memory, better run it on VM or choose chunk_size 1
preds_chunkwise_to_db(
  chunk_size = 7,
  query_features = "features_on_grid_nov21_oct22",
  xgb_fit = xgb_fit,
  model_id =  model_descr$model_id,
  table_name = "traffic_model_predictions_nov2021_oct2022"
)


# Predictions in grid cells with passive samplers for whole year 2022
preds_to_db(
  query_features = "features_at_passive_samplers",
  xgb_fit = xgb_fit,
  model_id = model_descr$model_id,
  table_name = "traffic_model_predictions_passive_samplers",
  database = Sys.getenv("DB_SCHEMA_SOURCE")
)
